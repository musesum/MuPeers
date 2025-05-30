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

    init(_ peerId: PeerId,
         _ peersLog: PeersLog,
         _ peersConfig: PeersConfig) {

        self.peerId = peerId
        self.peersLog = peersLog
        self.peersConfig = peersConfig
    }

    func sendHandshake(_ connectId: PeerId,
                       _ nwConnect: NWConnection?,
                       _ handshake: HandshakeStatus,
                       _ framerType: FramerType = .handshake) {

        guard let connection = self.nwConnect[connectId] ?? nwConnect else {
            return peersLog.status("⚠️ handshake connection not found for \(connectId)")
        }

        guard let data = try? JSONEncoder().encode(HandshakeMessage(peerId, handshake)) else {
            return peersLog.status("⚠️ handshake encoding error")
        }
        let message = NWProtocolFramer.Message(framerType: .handshake)
        let context = NWConnection.ContentContext(identifier: framerType.description, metadata: [message])

        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in
            #if DEBUG
            if let error {
                self.peersLog.log("🚨 handshake \(connectId)  error: \(error)")
            } else {
                self.peersLog.status("📤 handshake \(connectId):  '\(handshake.description)'")
            }
            #endif
        })
        handshaking[connectId] = PeerHandshake(handshake)
    }
    // Send a message to all connected peers
    func broadcastData(_ framerType: FramerType,
                       _ data: Data) async {

        for peerId in sendable {
            self.sendData(framerType,peerId, data)
        }
    }
    func sendData(_ framerType: FramerType,
                  _ connectId: PeerId,
                  _ data: Data) {

        guard let connection = self.nwConnect[connectId] else {
            return peersLog.status("⚠️ Connection not found for \(connectId)")
        }

        let message = NWProtocolFramer.Message(framerType: framerType)
        let context = NWConnection.ContentContext(identifier: "PeerMessage", metadata: [message])

        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in

            if let error {
                self.peersLog.log("🚨 sendMessage \(connectId): \(error)")
            } else {
                #if DEBUG
                self.peersLog.status("📤 sendMessage \(connectId)")
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
                self.peersLog.log("🚨 sendMessage \(connectId): \(error)")
            } else {
                #if DEBUG
                self.peersLog.status("📤 sendMessage \(connectId): '\(peerMessage.text)'")
                #endif
            }
        })
    }

    // Connection setup
    func setupConnection(_ connection: NWConnection) {
        let connectId = connection.endpoint.peerId
        if nwConnect.keys.contains(connectId) { return }
        peersLog.status("🔗 connect:  \(connectId)")
        nwConnect[connectId] = connection
        receive(on: connection)
        connection.start(queue: .main)
        sendInvite(connection)
    }

    func receive(on connection: NWConnection) {
        let endpoint = connection.endpoint

        connection.receiveMessage { data, context, isComplete, error in

            if let error { return err("error: \(error.debugDescription)") }
            guard let context else { return err("no context") }
            guard let data else { return err("no data: \(context.identifier)") }

            if let message = context.protocolMetadata(definition: PeerFramer.definition) as? NWProtocolFramer.Message {
                guard let connection = self.nwConnect[endpoint.peerId]
                else { return log("🚨 receive from unknown connection \(endpoint.peerId)") }

                let framerType = message.framerType
                switch framerType {
                case .handshake : self.updateHandshake(connection, data)
                case .invalid   : log("<= invalid")
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
                update.received(data: data)
            }
        }
    }
    func updateHandshake(_ connection: NWConnection,
                         _ data: Data) {

        // Decode the message data
        guard let message = try? JSONDecoder().decode(HandshakeMessage.self, from: data) else {
            return //.... err("Decoding error")
        }
        let connectId = message.peerId
        switch message.status {
        case .inviting:  sendHandshake(connectId, connection, .accepting)
        case .accepting: sendHandshake(connectId, connection, .verified)
        case .verified:  handshaking[connectId] = PeerHandshake(.verified)
        default: break
        }

        switch message.status {
        case .inviting, .accepting, .verified: sendable.insert(connectId)
        default: break
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
            peersLog.status("⛓️‍💥 disconnect: \(removeId)")
            if let connection = nwConnect[removeId] {
                connection.cancel()
            }
            nwConnect[removeId] = nil
            handshaking[removeId] = nil
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
            handshaking[connectId] = PeerHandshake(.awaiting)
            peersLog.status("🔗 awaiting: \(connectId)")
        }
    }

}
