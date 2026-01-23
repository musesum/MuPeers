// created by musesum on 5/23/25

import Foundation
import Network

class PeersConnection: @unchecked Sendable {

    let peerId      : PeerId
    let peersLog    : PeersLog
    let peersConfig : PeersConfig
    var nwConnect   : [PeerId: NWConnection] = [:]
    var handshaking : [PeerId: PeerHandshake] = [:]
    var sendable    : Set<PeerId> = Set()
    var delegates   : [FramerType: [PeersDelegate]] = [:]
    var objPeerId   : [ObjectIdentifier: PeerId] = [:] // Track current key for each connection
    var lastAction  : [PeerId: Date] = [:] // Track last action for each peer

    init(_ peerId: PeerId,
         _ peersLog: PeersLog,
         _ peersConfig: PeersConfig) {

        self.peerId = peerId
        self.peersLog = peersLog
        self.peersConfig = peersConfig
    }

    func sendHandshake(_ connectId: PeerId,
                       _ nwConnect: NWConnection,
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

        guard let connection = self.nwConnect[connectId] else {
            peersLog.status("⚠️ send '\(text)' to \(connectId) Connection not found")
            sendable.remove(connectId)
            return
        }
        
        // Check connection state before sending
        guard connection.state == .ready else {
            peersLog.status("⚠️ send '\(text)' to \(connectId) Connection not ready: \(connection.state)")
            if case .failed(_) = connection.state {
                sendable.remove(connectId) //..... bad access
            }
            return
        }

        let message = NWProtocolFramer.Message(framerType: framerType)
        let context = NWConnection.ContentContext(identifier: "PeerMessage", metadata: [message])

        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in

            if let error {
                self.peersLog.log("🚨 send '\(text)' to \(connectId) \(error)")
                // Remove connection if socket is disconnected
                if case .posix(let code) = error, 
                   code == .ENOTCONN || code == .ECONNRESET {
                    self.handleDisconnection(connectId)
                }
            } else {
                #if DEBUG
                //self.peersLog.status("📤 send '\(text)' to \(connectId)")
                #endif
            }
        })
    }

    func sendMessage(_ connectId: PeerId,
                     _ connection: NWConnection?,
                     _ message: String,
                     _ messageType: FramerType) {

        guard let connection = self.nwConnect[connectId] ?? connection else {
            return peersLog.status("⚠️ Connection not found for \(connectId)")
        }
        let peerMessage = PeerMessage(peerId, message)
        guard let data = try? JSONEncoder().encode(peerMessage) else {
            return peersLog.status("⚠️ Encoding error")
        }

        let message = NWProtocolFramer.Message(framerType: messageType)
        let context = NWConnection.ContentContext(identifier: "PeerMessage", metadata: [message])

        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in
            if let error {
                self.peersLog.log("🚨 send \(connectId): \(error)")
            } else {
                #if DEBUG
                self.peersLog.status("📤 send \(connectId): '\(peerMessage.text)'")
                #endif
            }
        })
    }

    // Connection setup
    func setupConnection(_ connection: NWConnection) {

        let connectId = connection.endpoint.peerId
        
        // If we already have a connection to this peer, check its state
        if let existingConnection = nwConnect[connectId] {
            switch existingConnection.state {
            case .ready, .preparing, .setup:
                // Existing connection is still viable, skip this new one
                peersLog.status("⚠️ duplicate connection attempt to \(connectId), keeping existing")
                connection.cancel()
                return
            default:
                // Existing connection is dead, remove it first
                peersLog.status("🔄 replacing dead connection to \(connectId)")
                handleDisconnection(connectId)
            }
        }
        
        peersLog.status("🔗 connect:  \(connectId)")
        nwConnect[connectId] = connection
        objPeerId[ObjectIdentifier(connection)] = connectId
        lastAction[connectId] = Date()

        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.peersLog.status("✅ ready: \(connectId)")
                self.sendInvite(connection)

            case .waiting(let error):
                self.peersLog.log("⏳ waiting: \(connectId) \(error)")

            case .failed(let error):
                self.peersLog.log("🚨 failed: \(connectId) \(error)")
                self.handleDisconnection(connectId)

            case .cancelled:
                self.peersLog.status("❌ cancelled: \(connectId)")
                self.handleDisconnection(connectId)

            default:
                break
            }
        }
        receive(on: connection)
        connection.start(queue: .main)
    }

    func receive(on connection: NWConnection) {
        let endpoint = connection.endpoint

        connection.receiveMessage { data, context, isComplete, error in

            if let error {
                return err("error: \(error.debugDescription)")
            }
            guard let context else {
                return err("no context")
            }
            guard let data else {
                // when IPv6 is taken over by Bonjour service,
                // it sends a "Final Message" so ignore the err
                err("from: \(endpoint.peerId) no data: \(context.identifier)")
                return
            }

            if let message = context.protocolMetadata(definition: PeerFramer.definition) as? NWProtocolFramer.Message {
                // Find the current key for this connection (may have been transferred)
                let objPeerId = self.objPeerId[ObjectIdentifier(connection)] ?? endpoint.peerId
                guard self.nwConnect[objPeerId] != nil
                else { return log("🚨 receive from unknown connection \(objPeerId) (original: \(endpoint.peerId))") }

                let framerType = message.framerType
                
                // Update activity tracking
                self.lastAction[objPeerId] = Date()
                
                switch framerType {
                case .handshake : self.updateHandshake(connection, data)
                case .invalid   : log("invalid")
                default: self.updateData(framerType, connection, data)
                }
            } else {
                return err("missing framer metadata")
            }
            // Continue receiving messages
            self.receive(on: connection)
        }
        @Sendable func log(_ msg: String) {
            print("<= \(msg) ")
        }
        @Sendable func err(_ msg: String) {
            peersLog.log("⚠️ receive " + msg)
        }
    }

    func updateData(_ framerType: FramerType,
                    _ connection: NWConnection,
                    _ data: Data) {

        if let updateSet = delegates[framerType] {
            for update in updateSet {
                update.received(data: data, from: .remote)
            }
        }
    }
    func updateHandshake(_ connection: NWConnection,
                         _ data: Data) {

        // Decode the message data
        guard let message = try? JSONDecoder().decode(HandshakeMessage.self, from: data) else {
            return peersLog.log("🚨 update Decoding error")
        }
        
        let announcedPeerId = message.peerId
        let currentKey = connection.endpoint.peerId
        
        // Consolidate IPv6 connection to peer ID if peer announces peer ID
        var connectId = currentKey
        if !currentKey.hasPrefix(PeersPrefix) && announcedPeerId.hasPrefix(PeersPrefix) {
            transferConnection(from: currentKey, to: announcedPeerId, connection: connection)
            connectId = announcedPeerId  // Use the new key for all subsequent operations
        } else {
            connectId = announcedPeerId
        }
        switch message.status {
        case .inviting:  
            sendHandshake(connectId, connection, .accepting)
        case .accepting: 
            sendHandshake(connectId, connection, .verified)
            handshaking[connectId] = PeerHandshake(.verified)  // Mark this peer as verified too
        case .verified:  
            handshaking[connectId] = PeerHandshake(.verified)
        default: break
        }

        switch message.status {
        case .inviting, .accepting, .verified:
            sendable.insert(connectId)
            handshaking[connectId] = PeerHandshake(.verified)
        default:
            handshaking[connectId] = PeerHandshake(message.status)
        }

    }

    func refreshResults(_ results: Set<NWBrowser.Result>) {
        peersLog.log("🔁 refreshResults")

        var refreshedConnections: Set<PeerId> = []

        for result in results {
            if case let NWEndpoint.service(name: connectId, type:_,domain:_,interface:_) = result.endpoint,
               connectId != self.peerId {

                refreshedConnections.insert(connectId)

                if !nwConnect.keys.contains(connectId) {
                    let parameters = NWParameters.make(secret: peersConfig.secret)
                    let connection = NWConnection(to: result.endpoint, using: parameters)
                    setupConnection(connection)
                }
            }
        }
        let removeConnections = Set(nwConnect.keys).subtracting(refreshedConnections)
        for removeId in removeConnections {
            handleDisconnection(removeId)
        }
    }
    
    func handleDisconnection(_ connectId: PeerId) {
        peersLog.status("⛓️‍💥 disconnect: \(connectId)")
        if let connection = nwConnect[connectId] {
            connection.cancel()
            objPeerId.removeValue(forKey: ObjectIdentifier(connection))
        }
        nwConnect.removeValue(forKey: connectId)
        handshaking.removeValue(forKey: connectId)
        sendable.remove(connectId)
        lastAction.removeValue(forKey: connectId)
    }
    
    func transferConnection(from oldKey: String, to newKey: String, connection: NWConnection) {
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
        nwConnect[newKey] = connection
        nwConnect.removeValue(forKey: oldKey)
        
        // Update reverse mapping
        objPeerId[ObjectIdentifier(connection)] = newKey
        
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
                if let connection = nwConnect[peerId] {
                    // Check if connection is actually dead
                    switch connection.state {
                    case .failed, .cancelled:
                        staleConnections.append(peerId)
                    case .ready, .preparing, .setup:
                        // Connection is still alive, update activity to prevent cleanup
                        lastAction[peerId] = Date()
                    default:
                        // For waiting state, give it more time
                        break
                    }
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

    func sendInvite(_ connection: NWConnection) {
        let connectId = connection.endpoint.peerId

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
            sendHandshake(connectId, connection, .inviting)
            handshaking[connectId] = PeerHandshake(.inviting)

        } else {
            handshaking[connectId] = PeerHandshake(.awaitng)
            peersLog.status("🔗 awaiting: \(connectId)")
        }
    }

}
