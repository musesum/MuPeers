// created by musesum on 5/23/25


import Foundation
import Network

class PeersBrowser: @unchecked Sendable {

    let peerId: PeerId
    let peersLog: PeersLog
    let connections: PeersConnection
    let peersConfig: PeersConfig

    var browser: NWBrowser?

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
            setupBrowser()
        }
    }

    // Start browsing for peers
    func setupBrowser() {
        do {
            let parameters = NWParameters.make(secret: peersConfig.secret)
            self.browser = NWBrowser(for: .bonjour(type: peersConfig.service, domain: nil), using: parameters)
            guard let browser else { return } //.. err?
            browser.stateUpdateHandler = { newState in
                self.browserStateUpdateHandler(browser, newState)
            }
            browser.browseResultsChangedHandler = { results, _ in
                guard browser === self.browser else { return }   // stale instance after cancelPeers
                self.connections.refreshResults(results)
            }
            browser.start(queue: .main)
            peersLog.status("🔍 Browsing for peers")
        }
    }
    func cancelBrowser() {
        browser?.cancel()
        browser = nil   // a deliberately cancelled browser must not auto-restart or sweep connections
    }
    func browserStateUpdateHandler(_ browser: NWBrowser,
                                   _ newState: NWBrowser.State) {
        switch newState {
        case .failed(let error):
            // Restart the browser if it loses its connection.
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                peersLog.log("Browser failed with \(error), restarting")
                browser.cancel()
                if browser === self.browser {   // stale instance (cancelPeers ran) must not resurrect browsing
                    self.setupBrowser()
                }
            } else {
                peersLog.log("Browser failed with \(error)")
                browser.cancel()
            }
        case .ready:
            // Post initial results.
            connections.refreshResults(browser.browseResults)
        case .cancelled:
            // Only the CURRENT browser may sweep; a stale .cancelled landing after a fast
            // off→on re-setup would disconnect the peers the new browser just found.
            if browser === self.browser {
                connections.refreshResults(Set())
            }
        default:
            break
        }
    }

}
