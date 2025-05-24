// created by musesum on 5/23/25

import Foundation
import Network
import UIKit

final class PeerListener: @unchecked Sendable {
    
    var listener: NWListener?
    let peerConnection: PeerConnection
    let peerStatus: PeerStatus
    
    var peerId: String
    
    init(_ peerStatus: PeerStatus,
         _ peerId: PeerId,
         _ peerConnection: PeerConnection) {
        
        self.peerStatus = peerStatus
        self.peerId = peerId
        self.peerConnection = peerConnection
        setupListener()
    }
    
    func setupListener() {
        do {
            listener = try NWListener(using: NWParameters.makeParamerters(), on: .any)
            if let listener {
                listener.service = NWListener.Service(name: peerId, type: Peers.serviceType)
                listener.newConnectionHandler = { [weak peerConnection = self.peerConnection] connection in
                    guard let peerConnection else { return }
                    peerConnection.setupConnection(connection)
                }
            }
            startListening()
        } catch {
            peerStatus.log("Listener error: \(error)")
            abort()
        }
    }
    func startListening() {
        guard let listener else { return }
        let peerStatus = self.peerStatus
        listener.stateUpdateHandler = { [weak listener] state in
            guard let listener else { return }
            switch state {
            case .ready:
                let port = listener.port ?? 0
                peerStatus.message("👂listening port: \(port)")
            case .failed(let error):
                if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                    peerStatus.log("Listener failed with \(error), restarting")
                    listener.cancel()
                    self.setupListener()
                    
                } else {
                    peerStatus.log("advertise error: \(error)")
                    listener.cancel()
                }
            case .cancelled:
                peerStatus.log("Listener cancelled, stopping")
                listener.cancel()
            default:
                break
            }
        }
        listener.start(queue: .main)
    }
}
