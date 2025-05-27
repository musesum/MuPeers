// created by musesum on 5/23/25


import Foundation
import Network
import UIKit

class PeerBrowser: @unchecked Sendable {

    let peerId: PeerId
    let peerLog: PeerLog
    let peerConnection: PeerConnection
    let peerConfig: PeerConfig

    init(_ peerId: PeerId,
         _ peerLog: PeerLog,
         _ peerConfig: PeerConfig,
         _ peerConnection: PeerConnection) {

        self.peerId = peerId
        self.peerLog = peerLog
        self.peerConnection = peerConnection
        self.peerConfig = peerConfig
        setupBrowser()
    }

    // Start browsing for peers
    func setupBrowser() {

        do {
            let parameters = NWParameters.make(secret: peerConfig.secret)
            let browser = NWBrowser(for: .bonjour(type: peerConfig.service, domain: nil), using: parameters)
            browser.stateUpdateHandler = { newState in
                self.browserStateUpdateHandler(browser, newState)
            }
            browser.browseResultsChangedHandler = { results, _ in
                self.peerConnection.refreshResults(results)
            }
            browser.start(queue: .main)
            peerLog.status("🔍 Browsing for peers")
        }
    }
    func browserStateUpdateHandler(_ browser: NWBrowser,
                                   _ newState: NWBrowser.State) {
        switch newState {
        case .failed(let error):
            // Restart the browser if it loses its connection.
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                peerLog.log("Browser failed with \(error), restarting")
                browser.cancel()
                self.setupBrowser()
            } else {
                peerLog.log("Browser failed with \(error)")
                browser.cancel()
            }
        case .ready:
            // Post initial results.
            peerConnection.refreshResults(browser.browseResults)
        case .cancelled:
            peerConnection.refreshResults(Set())
        default:
            break
        }
    }

}
