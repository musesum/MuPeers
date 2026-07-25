// created by musesum on 7/25/26

import Foundation
import Network

/// modern counterpart of PeersBrowser: NetworkBrowser over Bonjour;
/// discovered endpoints dial out through ModernPeerLink
@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
final class ModernBrowser: @unchecked Sendable {

    /// identity token per setup — a stale run must not resurrect browsing
    private final class Epoch {}

    let peerId: PeerId
    let peersLog: PeersLog
    let peersConfig: PeersConfig
    let connections: PeersConnection
    var browserTask: Task<Void, Never>?  // non-nil == browsing (test seam)
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

    var isActive: Bool { browserTask != nil }

    func setupBrowser() {
        guard browserTask == nil else { return }
        let thisEpoch = Epoch()
        epoch = thisEpoch

        browserTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let browser = NetworkBrowser(for: .bonjour(peersConfig.service),
                                             using: ModernParameters.builder().parameters)
                peersLog.status("🔍 Browsing for peers: modern")

                try await browser.run { [weak self] (endpoints: [Bonjour.Endpoint]) in
                    guard let self, self.epoch === thisEpoch else { return }
                    self.refresh(endpoints)
                }
            } catch is CancellationError {
            } catch {
                if self.epoch === thisEpoch {  // stale instance (cancelPeers ran) must not resurrect
                    self.peersLog.log("Browser (modern) failed with \(error), restarting")
                    self.browserTask = nil
                    self.setupBrowser()
                }
            }
        }
    }

    func cancelBrowser() {
        epoch = nil  // a deliberately cancelled browser must not auto-restart or sweep connections
        browserTask?.cancel()
        browserTask = nil
    }

    private func refresh(_ endpoints: [Bonjour.Endpoint]) {
        var discovered: [PeerId: NWEndpoint] = [:]
        for endpoint in endpoints {
            discovered[endpoint.name] = endpoint.nwEndpoint
        }
        connections.refreshPeers(discovered) { [peersLog] connectId, nwEndpoint in
            ModernPeerLink(outbound: nwEndpoint, name: connectId, peersLog)
        }
    }
}
