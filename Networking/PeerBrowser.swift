// refactored TicTacToe
import Network

// Update the UI when you receive new browser results.
protocol PeerBrowserDelegate: AnyObject {
	func refreshResults(results: Set<NWBrowser.Result>)
	func displayBrowseError(_ error: NWError)
}

class PeerBrowser_ {

	weak var delegate: PeerBrowserDelegate?
	var browser: NWBrowser?
    let serviceType: PeerServiceType
    
    // Create a browsing object with a delegate.
    init(_ serviceType: PeerServiceType,
         _ delegate: PeerBrowserDelegate) {
        self.serviceType = serviceType
        self.delegate = delegate
        startBrowsing()
    }
    
    func startBrowsing() {

		let parameters = NWParameters()
		parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: NWParameters.makeParamerters())
		self.browser = browser

        browser.stateUpdateHandler = { newState in
            self.browserStateUpdateHandler(browser, newState)
        }
		browser.browseResultsChangedHandler = { results, changes in
			self.delegate?.refreshResults(results: results)
		}

		// Start browsing and ask for updates on the main queue.
        browser.start(queue: .main)
    }

    func browserStateUpdateHandler(_ browser: NWBrowser,
                                   _ newState: NWBrowser.State) {
        switch newState {
        case .failed(let error):
            // Restart the browser if it loses its connection.
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                print("Browser failed with \(error), restarting")
                browser.cancel()
                self.startBrowsing()
            } else {
                print("Browser failed with \(error), stopping")
                self.delegate?.displayBrowseError(error)
                browser.cancel()
            }
        case .ready:
            // Post initial results.
            self.delegate?.refreshResults(results: browser.browseResults)
        case .cancelled:
            self.delegate?.refreshResults(results: Set())
        default:
            break
        }
    }

}
