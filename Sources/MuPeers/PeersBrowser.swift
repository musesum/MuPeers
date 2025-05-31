// created by musesum on 5/23/25


import Foundation
import Network
import UIKit

class PeersBrowser: @unchecked Sendable {

    let peerId: PeerId
    let peersLog: PeersLog
    let connections: PeersConnection
    let peersConfig: PeersConfig

    init(_ peerId: PeerId,
         _ peersLog: PeersLog,
         _ peersConfig: PeersConfig,
         _ connections: PeersConnection) {

        self.peerId = peerId
        self.peersLog = peersLog
        self.connections = connections
        self.peersConfig = peersConfig
        setupBrowser()
    }

    // Start browsing for peers
    func setupBrowser() {
        do {
            let parameters = NWParameters.make(secret: peersConfig.secret)
            let browser = NWBrowser(for: .bonjour(type: peersConfig.service, domain: nil), using: parameters)
            browser.stateUpdateHandler = { newState in
                self.browserStateUpdateHandler(browser, newState)
            }
            browser.browseResultsChangedHandler = { results, _ in
                self.connections.refreshResults(results)
            }
            browser.start(queue: .main)
            peersLog.status("🔍 Browsing for peers")
        }
    }
    func browserStateUpdateHandler(_ browser: NWBrowser,
                                   _ newState: NWBrowser.State) {
        switch newState {
        case .failed(let error):
            // Restart the browser if it loses its connection.
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                peersLog.log("Browser failed with \(error), restarting")
                browser.cancel()
                self.setupBrowser()
            } else {
                peersLog.log("Browser failed with \(error)")
                browser.cancel()
            }
        case .ready:
            // Post initial results.
            connections.refreshResults(browser.browseResults)
        case .cancelled:
            connections.refreshResults(Set())
        default:
            break
        }
    }

}
