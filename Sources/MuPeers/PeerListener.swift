// created by musesum on 5/23/25

import Foundation
import Network
import UIKit

final class PeerListener: @unchecked Sendable {

    let peerId: PeerId
    let peerLog: PeerLog
    let peerConnection: PeerConnection
    let peerConfig: PeerConfig
    var listener: NWListener?

    init(_ peerId: PeerId,
         _ peerLog: PeerLog,
         _ peerConfig: PeerConfig,
         _ peerConnection: PeerConnection) {

        self.peerId = peerId
        self.peerLog = peerLog
        self.peerConnection = peerConnection
        self.peerConfig = peerConfig
        setupListener()
    }
    
    func setupListener() {
        do {
            let parameters = NWParameters.make(secret: peerConfig.secret)
            listener = try NWListener(using: parameters, on: .any)
            if let listener {
                listener.service = NWListener.Service(name: peerId, type: peerConfig.service)
                listener.newConnectionHandler = { [weak peerConnection = self.peerConnection] connection in
                    guard let peerConnection else { return }
                    peerConnection.setupConnection(connection)
                }
            }
            startListening()
        } catch {
            peerLog.log("Listener error: \(error)")
            abort()
        }
    }
    func startListening() {
        guard let listener else { return }
        let peerLog = self.peerLog
        listener.stateUpdateHandler = { [weak listener] state in
            guard let listener else { return }
            switch state {
            case .ready:
                let port = listener.port ?? 0
                peerLog.status("👂listening port: \(port)")
            case .failed(let error):
                if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                    peerLog.log("Listener failed with \(error), restarting")
                    listener.cancel()
                    self.setupListener()
                    
                } else {
                    peerLog.log("advertise error: \(error)")
                    listener.cancel()
                }
            case .cancelled:
                peerLog.log("Listener cancelled, stopping")
                listener.cancel()
            default:
                break
            }
        }
        listener.start(queue: .main)
    }
}
