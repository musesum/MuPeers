// created by musesum on 5/23/25

import Foundation
import Network

class PeerConnection: @unchecked Sendable {

    let peerId: PeerId
    let peerStatus: PeerStatus
    var connections: [PeerId: NWConnection] = [:]
    var handshake: [PeerId: HandShake] = [:]
    
    let secret: String = "secret"
    let invite: String = "invite"
    let accept: String = "accept"
    let verified: String = "verified"

    init(_ peerStatus: PeerStatus,
         _ peerId: PeerId) {
        self.peerStatus = peerStatus
        self.peerId = peerId
    }

    // Send a message to all connected peers
    func broadcastMessage(_ message: String) async {
        for (connectionId, connection) in connections {
            if connectionId == self.peerId {
                peerStatus.message("🙊 broadcast to self skipped")
            } else {
                self.sendMessage(connectionId, connection, message, .data)
            }
        }
    }
    func sendMessage(_ connectionId: PeerId,
                     _ connection: NWConnection?,
                     _ message: String,
                     _ messageType: PeerFramerType) {


        //let connectionId = connection.endpoint.peerId
        if connectionId == self.peerId {
            peerStatus.message("🙊 send to self skipped")
            return
        }
        guard let connection = self.connections[connectionId] ?? connection else {
            peerStatus.message("⚠️ Connection not found for \(connectionId)")
            return
        }
        let peerMessage = PeerMessage(peerId, PeerDevice.name, message)
        guard let data = try? JSONEncoder().encode(peerMessage) else {
            peerStatus.message("⚠️ Encoding error")
            return
        }

        // Create a NWProtocolFramer.Message with the appropriate type
        let framerMessage = NWProtocolFramer.Message(peerMessageType: messageType)

        // Create a content context with the framer message as metadata
        let context = NWConnection.ContentContext(identifier: "PeerMessage", metadata: [framerMessage])

        // Send the data with the content context
        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed { error in
            let title = peerMessage.title
            if let error {
                self.peerStatus.log("🚨 send error: \(title): \(error)")
            } else {
                self.peerStatus.message("📤 sending:  \(connectionId) '\(peerMessage.text)'")
            }
        })
    }

    // Connection setup
    func setupConnection(_ connection: NWConnection) {

        let connectionId = connection.endpoint.peerId
        if connections.keys.contains(connectionId) { return }
        peerStatus.message("🔗 connect:  \(connectionId)")
        connections[connectionId] = connection
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

            if let framerMessage = context.protocolMetadata(definition: PeerFramer.definition) as? NWProtocolFramer.Message {

                let messageType = framerMessage.peerMessageType

                // Decode the message data
                if let msg = try? JSONDecoder().decode(PeerMessage.self, from: data) {
                    self.received(msg, endpoint, messageType)
                } else {
                    return err("Decoding error")
                }
            } else {
                return err("missing framer metadata")
            }
            // Continue receiving messages
            self.receive(on: connection)
        }
        @Sendable func err(_ msg: String) {
            peerStatus.log("⚠️ receive " + msg)
        }
    }

    func received(_ message: PeerMessage,
                  _ endpoint: NWEndpoint,
                  _ messageType: PeerFramerType) {

        guard let connection = connections[endpoint.peerId]
        else { return log("🚨 receive from unknown connection \(endpoint.peerId)") }

        switch messageType {
        case .handshake: handshaking(connection, message)
        case .data:      log("<= data")
        case .alive:     log("<= alive")
        case .invalid:   log("<= invalid")
        }
        func log(_ msg: String) {
            print("<= \(message.peerId) type: \(messageType) ")
        }
    }
    func refreshResults(_ results: Set<NWBrowser.Result>) {
        peerStatus.log("🔁 refreshResults")

        var refreshedConnections: Set<PeerId> = []

        for result in results {
            if case let NWEndpoint.service(name: connectId, type: _, domain: _, interface: _) = result.endpoint,
               connectId != self.peerId {

                refreshedConnections.insert(connectId)

                if !connections.keys.contains(connectId) {
                    let connection = NWConnection(to: result.endpoint, using: NWParameters.makeParamerters())
                    setupConnection(connection)
                }
            }
        }
        let removeConnections = Set(connections.keys).subtracting(refreshedConnections)
        for removeId in removeConnections {
            peerStatus.message("⛓️‍💥 disconnect: \(removeId)")
            if let connection = connections[removeId] {
                connection.cancel()
            }
            connections[removeId] = nil
            handshake[removeId] = nil
        }
    }
}
extension PeerConnection {

    func sendInvite(_ connection: NWConnection) {
        let connectionId = connection.endpoint.peerId

        // send inviation to new Peer, which
        // has a lower peerId (connectionID) than self
        // to resolve who invites and whom accepts
        if connectionId < self.peerId {
            sendMessage(connectionId, connection, "invite", .handshake)
            changePeerStatus(connection, to: .inviting)

        } else {
            changePeerStatus(connection, to: .awaiting)
            peerStatus.message("🔗 awaiting: \(connectionId)")
        }
    }


    func handshaking(_ connection: NWConnection, _ message: PeerMessage) {
        switch message.text {
        case invite:
            
            sendMessage(message.peerId, connection, accept, .handshake)
            changePeerStatus(message.peerId, to: .accepting)
            
        case accept:
            
            sendMessage(message.peerId, connection, verified, .handshake)
            changePeerStatus(message.peerId, to: .verified)
            
        case verified:
            // already sent .accept, received back .verified
            changePeerStatus(message.peerId, to: .verified)
            
        default: break
        }
    }
    private func changePeerStatus(_ connectId: PeerId, to status: HandshakeStatus) {
        handshake[connectId] = HandShake(status)
    }
    private func changePeerStatus(_ connection: NWConnection, to status: HandshakeStatus) {
        let connectId = connection.endpoint.peerId
        handshake[connectId] = HandShake(status)
    }
}
