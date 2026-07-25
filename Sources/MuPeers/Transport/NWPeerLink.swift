// created by musesum on 7/25/26

import Foundation
import Network

/// legacy backend link: NWConnection with PeerFramer in its protocol stack
final class NWPeerLink: PeerLink, @unchecked Sendable {

    let nwConnection: NWConnection
    let peersLog: PeersLog
    let initialPeerId: PeerId

    init(_ nwConnection: NWConnection,
         _ peersLog: PeersLog) {

        self.nwConnection = nwConnection
        self.peersLog = peersLog
        self.initialPeerId = nwConnection.endpoint.peerId
    }

    var isReady: Bool { nwConnection.state == .ready }

    var isViable: Bool {
        switch nwConnection.state {
        case .ready, .preparing, .setup: return true
        default: return false
        }
    }
    var isDead: Bool {
        switch nwConnection.state {
        case .failed, .cancelled: return true
        default: return false
        }
    }
    var isFailed: Bool {
        if case .failed = nwConnection.state { return true }
        return false
    }
    var stateDescription: String { "\(nwConnection.state)" }

    func start(onState: @escaping @Sendable (PeerLinkState) -> Void,
               onMessage: @escaping @Sendable (FramerType, Data) -> Bool) {

        nwConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:              onState(.ready)
            case .waiting(let error): onState(.waiting("\(error)"))
            case .failed(let error):  onState(.failed("\(error)"))
            case .cancelled:          onState(.cancelled)
            default: break
            }
        }
        receive(onMessage)
        nwConnection.start(queue: .main)
    }

    /// re-arms itself while onMessage returns true
    private func receive(_ onMessage: @escaping @Sendable (FramerType, Data) -> Bool) {
        let endpoint = nwConnection.endpoint

        nwConnection.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self else { return }
            if let error {
                return self.err("error: \(error.debugDescription)")
            }
            guard let context else {
                return self.err("no context")
            }
            guard let data else {
                // when IPv6 is taken over by Bonjour service,
                // it sends a "Final Message" so ignore the err
                self.err("from: \(endpoint.peerId) no data: \(context.identifier)")
                return
            }
            if let message = context.protocolMetadata(definition: PeerFramer.definition) as? NWProtocolFramer.Message {
                if onMessage(message.framerType, data) {
                    self.receive(onMessage)
                }
            } else {
                return self.err("missing framer metadata")
            }
        }
    }
    private func err(_ msg: String) {
        peersLog.log("⚠️ receive " + msg)
    }

    func send(_ type: FramerType,
              _ data: Data,
              _ text: String,
              onError: @escaping @Sendable (PeerLinkSendError) -> Void) {

        let message = NWProtocolFramer.Message(framerType: type)
        let context = NWConnection.ContentContext(identifier: "PeerMessage", metadata: [message])

        nwConnection.send(content: data,
                          contentContext: context,
                          isComplete: true,
                          completion: .contentProcessed { error in
            guard let error else { return }
            // .disconnected drops the peer at PeersConnection
            onError(PeerLinkSendError.classify(error))
        })
    }

    func cancel() {
        nwConnection.cancel()
    }
}
