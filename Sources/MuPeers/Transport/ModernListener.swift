// created by musesum on 7/25/26

import Foundation
import Network

/// modern counterpart of PeersListener: NetworkListener advertising peerId
/// over Bonjour; inbound connections wrap into ModernPeerLink
@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
final class ModernListener: @unchecked Sendable {

    /// identity token per setup — a stale run must not resurrect advertising
    private final class Epoch {}

    let peerId: PeerId
    let peersLog: PeersLog
    let peersConfig: PeersConfig
    let connections: PeersConnection
    var listenerTask: Task<Void, Never>?  // non-nil == advertising (test seam)
    private var epoch: Epoch?

    init(_ peerId: PeerId,
         _ peersLog: PeersLog,
         _ peersConfig: PeersConfig,
         _ connections: PeersConnection) {

        self.peerId = peerId
        self.peersLog = peersLog
        self.peersConfig = peersConfig
        self.connections = connections
    }

    var isActive: Bool { listenerTask != nil }

    func setupListener() {
        guard listenerTask == nil else { return }
        let thisEpoch = Epoch()
        epoch = thisEpoch

        listenerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let listener = try NetworkListener(
                    for: .bonjour(name: peerId, type: peersConfig.service),
                    using: ModernParameters.builder())
                peersLog.status("👂listening: modern")

                try await listener.run { [weak self] connection in
                    guard let self, self.epoch === thisEpoch else { return }
                    let link = ModernPeerLink(inbound: connection, self.peersLog)
                    self.connections.registerLink(link)
                    await link.serviced()  // hold the structured scope open until the link ends
                }
            } catch is CancellationError {
            } catch {
                if self.epoch === thisEpoch {  // stale instance (cancelPeers ran) must not resurrect
                    self.peersLog.log("Listener (modern) error: \(error), restarting")
                    self.listenerTask = nil
                    self.setupListener()
                }
            }
        }
    }

    func cancelListener() {
        epoch = nil  // a deliberately cancelled listener must not auto-restart
        listenerTask?.cancel()
        listenerTask = nil
    }
}
