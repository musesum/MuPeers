// created by musesum on 7/25/26

import Foundation
import Network

/// transport-neutral connection handle so PeersConnection session logic
/// (handshake, transfer, cleanup, delegates) runs unchanged on either backend
protocol PeerLink: AnyObject, Sendable {

    /// endpoint-derived id at creation; may be IPv6 until handshake transfer
    var initialPeerId: PeerId { get }
    var isReady: Bool { get }
    /// ready | preparing | setup — a viable duplicate blocks a second dial
    var isViable: Bool { get }
    /// failed | cancelled
    var isDead: Bool { get }
    var isFailed: Bool { get }
    var stateDescription: String { get }

    /// callbacks run on main; onMessage returns false to stop receiving
    func start(onState: @escaping @Sendable (PeerLinkState) -> Void,
               onMessage: @escaping @Sendable (FramerType, Data) -> Bool)

    func send(_ type: FramerType,
              _ data: Data,
              _ text: String,
              onError: @escaping @Sendable (PeerLinkSendError) -> Void)

    func cancel()
}

enum PeerLinkState: Sendable {
    case ready
    case waiting(String)
    case failed(String)
    case cancelled
}

enum PeerLinkSendError: Sendable {
    case disconnected(String)  // socket gone — drop the peer
    case failed(String)

    /// shared drop-vs-transient rule for both backends
    static func classify(_ error: Error) -> PeerLinkSendError {
        if let nwError = error as? NWError,
           case .posix(let code) = nwError,
           code == .ENOTCONN || code == .ECONNRESET {
            return .disconnected("\(nwError)")
        }
        if error is CancellationError {
            return .disconnected("cancelled")
        }
        return .failed("\(error)")
    }
}
