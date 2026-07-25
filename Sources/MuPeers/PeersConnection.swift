// created by musesum on 5/23/25

import Foundation
import Network

class PeersConnection: @unchecked Sendable {

    let peerId      : PeerId
    let peersLog    : PeersLog
    let peersConfig : PeersConfig
    var links       : [PeerId: PeerLink] = [:]
    var handshaking : [PeerId: PeerHandshake] = [:]
    var sendable    : Set<PeerId> = Set()
    var delegates   : [FramerType: [PeersDelegate]] = [:]
    var objPeerId   : [ObjectIdentifier: PeerId] = [:] // Track current key for each link
    var lastAction  : [PeerId: Date] = [:] // Track last action for each peer

    init(_ peerId: PeerId,
         _ peersLog: PeersLog,
         _ peersConfig: PeersConfig) {

        self.peerId = peerId
        self.peersLog = peersLog
        self.peersConfig = peersConfig
    }

    func sendHandshake(_ connectId: PeerId,
                       _ handshake: HandshakeStatus) {

        // Use the passed connectId, not the endpoint's peerId, as it may have been transferred
        guard let data = try? JSONEncoder().encode(HandshakeMessage(peerId, handshake)) else {
            return peersLog.status("⚠️ handshake encoding error")
        }
        // cannot filter for connectId.hasPrefix(PeersPrefix)
        // seems like invite starts from IPv6, which in turn
        // disconnects once the Bounjour service takes over?
        sendData(.handshake, connectId, data, handshake.description)
    }
    // Send a message to all connected peers
    func broadcastData(_ type: FramerType,
                       _ data: Data) async {

        for peerId in sendable {
            self.sendData(type, peerId, data)
        }
    }
    func sendData(_ framerType: FramerType,
                  _ connectId: PeerId,
                  _ data: Data,
                  _ text: String = "") {

        guard let link = self.links[connectId] else {
            peersLog.status("⚠️ send '\(text)' to \(connectId) Connection not found")
            sendable.remove(connectId)
            return
        }

        // Check connection state before sending
        guard link.isReady else {
            peersLog.status("⚠️ send '\(text)' to \(connectId) Connection not ready: \(link.stateDescription)")
            if link.isFailed {
                sendable.remove(connectId)
            }
            return
        }

        link.send(framerType, data, text) { [weak self] sendError in
            guard let self else { return }
            switch sendError {
            case .disconnected(let msg):
                self.peersLog.log("🚨 send '\(text)' to \(connectId) \(msg)")
                // Remove connection if socket is disconnected
                self.handleDisconnection(connectId)
            case .failed(let msg):
                self.peersLog.log("🚨 send '\(text)' to \(connectId) \(msg)")
            }
        }
    }

    func sendMessage(_ connectId: PeerId,
                     _ message: String,
                     _ messageType: FramerType) {

        guard links[connectId] != nil else {
            return peersLog.status("⚠️ Connection not found for \(connectId)")
        }
        let peerMessage = PeerMessage(peerId, message)
        guard let data = try? JSONEncoder().encode(peerMessage) else {
            return peersLog.status("⚠️ Encoding error")
        }
        sendData(messageType, connectId, data, peerMessage.text)
    }

    /// legacy entry kept for PeersListener/PeersBrowser callers
    func setupConnection(_ connection: NWConnection) {
        registerLink(NWPeerLink(connection, peersLog))
    }

    /// current key for a link — may differ from initialPeerId after transfer
    func currentKey(_ link: PeerLink) -> PeerId {
        objPeerId[ObjectIdentifier(link)] ?? link.initialPeerId
    }

    // Connection setup
    func registerLink(_ link: PeerLink) {

        let connectId = link.initialPeerId

        // If we already have a connection to this peer, check its state
        if let existingLink = links[connectId] {
            if existingLink.isViable {
                // Existing connection is still viable, skip this new one
                peersLog.status("⚠️ duplicate connection attempt to \(connectId), keeping existing")
                link.cancel()
                return
            } else {
                // Existing connection is dead, remove it first
                peersLog.status("🔄 replacing dead connection to \(connectId)")
                handleDisconnection(connectId)
            }
        }

        peersLog.status("🔗 connect:  \(connectId)")
        links[connectId] = link
        objPeerId[ObjectIdentifier(link)] = connectId
        lastAction[connectId] = Date()

        link.start(onState: { [weak self, weak link] state in
            guard let self, let link else { return }
            let connectId = self.currentKey(link)

            switch state {
            case .ready:
                self.peersLog.status("✅ ready: \(connectId)")
                self.sendInvite(link)

            case .waiting(let error):
                self.peersLog.log("⏳ waiting: \(connectId) \(error)")

            case .failed(let error):
                self.peersLog.log("🚨 failed: \(connectId) \(error)")
                self.handleDisconnection(connectId)

            case .cancelled:
                self.peersLog.status("❌ cancelled: \(connectId)")
                self.handleDisconnection(connectId)
            }
        }, onMessage: { [weak self, weak link] framerType, data in
            guard let self, let link else { return false }
            let objPeerId = self.currentKey(link)
            guard self.links[objPeerId] != nil else {
                print("<= 🚨 receive from unknown connection \(objPeerId) (original: \(link.initialPeerId)) ")
                return false
            }
            // Update activity tracking
            self.lastAction[objPeerId] = Date()

            switch framerType {
            case .handshake : self.updateHandshake(link, data)
            case .invalid   : print("<= invalid ")
            default         : self.updateData(framerType, link, data)
            }
            return true
        })
    }

    func updateData(_ framerType: FramerType,
                    _ link: PeerLink,
                    _ data: Data) {

        let objPeerId = currentKey(link)

        if let updateSet = delegates[framerType] {
            for update in updateSet {
                update.received(data: data, from: .remote(objPeerId))
            }
        }
    }
    func updateHandshake(_ link: PeerLink,
                         _ data: Data) {

        // Decode the message data
        guard let message = try? JSONDecoder().decode(HandshakeMessage.self, from: data) else {
            return peersLog.log("🚨 update Decoding error")
        }

        let announcedPeerId = message.peerId
        let currentKey = self.currentKey(link)

        // Consolidate IPv6 connection to peer ID if peer announces peer ID
        var connectId = currentKey
        if !currentKey.hasPrefix(PeersPrefix) && announcedPeerId.hasPrefix(PeersPrefix) {
            transferConnection(from: currentKey, to: announcedPeerId, link: link)
            connectId = announcedPeerId  // Use the new key for all subsequent operations
        } else {
            connectId = announcedPeerId
        }
        switch message.status {
        case .inviting:
            sendHandshake(connectId, .accepting)
        case .accepting:
            sendHandshake(connectId, .verified)
            handshaking[connectId] = PeerHandshake(.verified)  // Mark this peer as verified too
        case .verified:
            handshaking[connectId] = PeerHandshake(.verified)
        default: break
        }

        switch message.status {
        case .inviting, .accepting, .verified:
            let inserted = sendable.insert(connectId).inserted
            handshaking[connectId] = PeerHandshake(.verified)
            if inserted { notifyJoined(connectId) }
        default:
            handshaking[connectId] = PeerHandshake(message.status)
        }
    }

    /// peer became sendable — notify each delegate once (a launch-time
    /// sendItem burst precedes any verified peer, so joined is the reliable
    /// moment for consumers to re-send state)
    func notifyJoined(_ connectId: PeerId) {
        var seen = Set<ObjectIdentifier>()
        for updateSet in delegates.values {
            for update in updateSet where seen.insert(ObjectIdentifier(update)).inserted {
                update.joined(from: .remote(connectId))
            }
        }
    }

    /// backend-neutral discovery refresh: dial new peers, sweep absent ones;
    /// makeLink runs only for genuinely new peers
    func refreshPeers(_ discovered: [PeerId: NWEndpoint],
                      _ makeLink: (PeerId, NWEndpoint) -> PeerLink) {
        peersLog.log("🔁 refreshResults")

        var refreshedConnections: Set<PeerId> = []

        for (connectId, endpoint) in discovered where connectId != self.peerId {

            refreshedConnections.insert(connectId)

            if !links.keys.contains(connectId) {
                registerLink(makeLink(connectId, endpoint))
            }
        }
        let removeConnections = Set(links.keys).subtracting(refreshedConnections)
        for removeId in removeConnections {
            handleDisconnection(removeId)
        }
    }

    /// legacy adapter for NWBrowser results
    func refreshResults(_ results: Set<NWBrowser.Result>) {

        var discovered: [PeerId: NWEndpoint] = [:]

        for result in results {
            if case let NWEndpoint.service(name: connectId, type: _, domain: _, interface: _) = result.endpoint {
                discovered[connectId] = result.endpoint
            }
        }
        refreshPeers(discovered) { [peersConfig, peersLog] _, endpoint in
            let parameters = NWParameters.make(secret: peersConfig.secret)
            return NWPeerLink(NWConnection(to: endpoint, using: parameters), peersLog)
        }
    }

    func handleDisconnection(_ connectId: PeerId) {
        // already removed (e.g. cancel()'s .cancelled callback re-entering after
        // disconnectAll) — skip, or delegates get duplicate dropped() notifications
        guard links[connectId] != nil
                || handshaking[connectId] != nil
                || sendable.contains(connectId) else { return }
        peersLog.status("⛓️‍💥 disconnect: \(connectId)")
        if let link = links[connectId] {
            link.cancel()
            objPeerId.removeValue(forKey: ObjectIdentifier(link))
        }
        links.removeValue(forKey: connectId)
        handshaking.removeValue(forKey: connectId)
        sendable.remove(connectId)
        lastAction.removeValue(forKey: connectId)

        Task { @MainActor in
            var notified = Set<ObjectIdentifier>()
            for delegateList in self.delegates.values {
                for delegate in delegateList {
                    let id = ObjectIdentifier(delegate)
                    if !notified.contains(id) {
                        delegate.dropped(from: .remote(connectId))
                        notified.insert(id)
                    }
                }
            }
        }
    }

    /// drop every live connection — cancelPeers uses this so Bonjour-off also disconnects
    func disconnectAll() {
        for connectId in Array(links.keys) {
            handleDisconnection(connectId)
        }
    }

    func transferConnection(from oldKey: String, to newKey: String, link: PeerLink) {
        peersLog.status("🔄 transfer connection: \(oldKey) -> \(newKey)")

        // Transfer handshaking state
        if let handshake = handshaking[oldKey] {
            handshaking[newKey] = handshake
            handshaking.removeValue(forKey: oldKey)
        }

        // Transfer sendable status
        if sendable.contains(oldKey) {
            sendable.remove(oldKey)
            sendable.insert(newKey)
        }

        // Transfer connection reference
        links[newKey] = link
        links.removeValue(forKey: oldKey)

        // Update reverse mapping
        objPeerId[ObjectIdentifier(link)] = newKey

        // Transfer activity tracking
        if let activity = lastAction[oldKey] {
            lastAction[newKey] = activity
            lastAction.removeValue(forKey: oldKey)
        }
    }

    func cleanupStaleConnections(olderThan timeout: TimeInterval = 60) {
        let cutoffTime = Date().addingTimeInterval(-timeout)
        var staleConnections: [PeerId] = []

        for (peerId, lastSeen) in lastAction {
            // Only cleanup if both: older than timeout AND connection is not ready
            if lastSeen < cutoffTime {
                if let link = links[peerId] {
                    // Check if connection is actually dead
                    if link.isDead {
                        staleConnections.append(peerId)
                    } else if link.isViable {
                        // Connection is still alive, update activity to prevent cleanup
                        lastAction[peerId] = Date()
                    }
                    // For waiting state, give it more time
                } else {
                    // No connection found, safe to cleanup
                    staleConnections.append(peerId)
                }
            }
        }

        for staleId in staleConnections {
            peersLog.status("🧹 cleanup stale connection: \(staleId)")
            handleDisconnection(staleId)
        }
    }
}
extension PeersConnection {

    func sendInvite(_ link: PeerLink) {
        let connectId = currentKey(link)

        // send invitation to new Peer, which
        // has a lower peerId (connectId) than self
        // to resolve who invites and whom accepts
        // Compare the numeric values if both are valid peerIds
        let shouldInvite: Bool
        if let connectIdNum = connectId.peerIdNumber,
           let selfIdNum = self.peerId.peerIdNumber {
            shouldInvite = connectIdNum < selfIdNum
        } else {
            // Fallback to string comparison for non-peer endpoints
            shouldInvite = connectId < self.peerId
        }

        if shouldInvite {
            sendHandshake(connectId, .inviting)
            handshaking[connectId] = PeerHandshake(.inviting)

        } else {
            handshaking[connectId] = PeerHandshake(.awaitng)
            peersLog.status("🔗 awaiting: \(connectId)")
        }
    }
}
