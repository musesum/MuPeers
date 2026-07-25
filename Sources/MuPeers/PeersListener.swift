// created by musesum on 5/23/25

import Foundation
import Network

final class PeersListener: @unchecked Sendable {

    let peerId: PeerId
    let peersLog: PeersLog
    let connections: PeersConnection
    let peersConfig: PeersConfig
    var listener: NWListener?

    init(_ peerId: PeerId,
         _ peersLog: PeersLog,
         _ peersConfig: PeersConfig,
         _ connections: PeersConnection,
         startNow: Bool = true) {  // false when another backend owns startup

        self.peerId = peerId
        self.peersLog = peersLog
        self.connections = connections
        self.peersConfig = peersConfig
        if startNow {
            setupListener()
        }
    }
    
    func setupListener() {
        do {
            let parameters = NWParameters.make(secret: peersConfig.secret)
            listener = try NWListener(using: parameters, on: .any)
            if let listener {
                listener.service = NWListener.Service(name: peerId, type: peersConfig.service)
                listener.newConnectionHandler = { [weak connections = self.connections] connection in
                    guard let connections else { return }
                    connections.setupConnection(connection)
                }
            }
            startListening()
        } catch {
            peersLog.log("Listener error: \(error)")
        }
    }
    func cancelListener() {
        listener?.cancel()
        listener = nil   // a deliberately cancelled listener must not auto-restart via the defunct-DNS path
    }

    func startListening() {
        guard let listener else { return }
        let peersLog = self.peersLog
        listener.stateUpdateHandler = { [weak listener] state in
            guard let listener else { return }
            switch state {
            case .ready:
                let port = listener.port ?? 0
                peersLog.status("👂listening port: \(port)")
            case .failed(let error):
                if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                    peersLog.log("Listener failed with \(error), restarting")
                    listener.cancel()
                    if listener === self.listener {   // stale instance (cancelPeers ran) must not resurrect advertising
                        self.setupListener()
                    }

                } else {
                    peersLog.log("advertise error: \(error)")
                    listener.cancel()
                }
            case .cancelled:
                peersLog.log("Listener cancelled, stopping")
                listener.cancel()
            default:
                break
            }
        }
        listener.start(queue: .main)
    }
}
