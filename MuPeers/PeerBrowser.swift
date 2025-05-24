// created by musesum on 5/23/25


import Foundation
import Network
import UIKit

class PeerBrowser: @unchecked Sendable {

    let invite = "invite"
    let accept = "accept"
    let peerId: PeerId
    let peerStatus: PeerStatus
    let peerConnection: PeerConnection

    init(_ peerStatus: PeerStatus,
         _ peerId: PeerId,
         _ peerConnection: PeerConnection) {

        self.peerStatus = peerStatus
        self.peerId = peerId
        self.peerConnection = peerConnection
        setupBrowser()
    }

    // Start browsing for peers
    func setupBrowser() {

        do {
            let parameters = NWParameters.makeParamerters()
            let browser = NWBrowser(for: .bonjour(type: Peers.serviceType, domain: nil), using: parameters)
            browser.stateUpdateHandler = { newState in
                self.browserStateUpdateHandler(browser, newState)
            }
            browser.browseResultsChangedHandler = { results, _ in
                self.peerConnection.refreshResults(results)
            }
            browser.start(queue: .main)
            peerStatus.message("🔍 Browsing for peers")
        }
    }
    func browserStateUpdateHandler(_ browser: NWBrowser,
                                   _ newState: NWBrowser.State) {
        switch newState {
        case .failed(let error):
            // Restart the browser if it loses its connection.
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                peerStatus.log("Browser failed with \(error), restarting")
                browser.cancel()
                self.setupBrowser()
            } else {
                peerStatus.log("Browser failed with \(error)")
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
