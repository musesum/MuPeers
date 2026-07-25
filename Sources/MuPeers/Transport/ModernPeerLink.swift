// created by musesum on 7/25/26

import Foundation
import Network

/// PeerFramer over TCP for the modern structured-concurrency stack —
/// byte-identical on the wire with the legacy NWConnection stack
@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
extension PeerFramer: Network.FramerProtocol {}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
enum ModernParameters {

    /// parity with NWParameters.make(secret: "") — plain TCP, PeerFramer, p2p constraints
    /// (Network.Framer qualified: the module typealias Framer shadows it)
    static func builder() -> NWParametersBuilder<Network.Framer<PeerFramer>> {
        let builder = NWParametersBuilder.parameters {
            Network.Framer(using: PeerFramer.self) { TCP() }
        }
        NWParameters.applyPeerToPeerConstraints(builder.parameters)
        return builder
    }
}

/// modern backend link: NetworkConnection<Framer<PeerFramer>>.
/// teardown is structured — no cancel() on NetworkConnection; cancelling the
/// owning Task closes the withNetworkConnection / listener.run scope
@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
final class ModernPeerLink: PeerLink, @unchecked Sendable {

    typealias ModernConnection = NetworkConnection<Network.Framer<PeerFramer>>

    let peersLog: PeersLog
    let initialPeerId: PeerId

    private let outboundEndpoint: NWEndpoint?  // nil for inbound
    private var connection: ModernConnection?
    private var runnerTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private let sendStream: AsyncStream<SendRequest>
    private let sendNext: AsyncStream<SendRequest>.Continuation
    private var wasCancelled = false
    private var servicedDone = false
    private var servicedContinuation: CheckedContinuation<Void, Never>?

    private struct SendRequest: @unchecked Sendable {
        let type: FramerType
        let data: Data
        let text: String
        let onError: @Sendable (PeerLinkSendError) -> Void
    }

    init(outbound endpoint: NWEndpoint,
         name: PeerId,
         _ peersLog: PeersLog) {

        self.outboundEndpoint = endpoint
        self.initialPeerId = name
        self.peersLog = peersLog
        (self.sendStream, self.sendNext) = AsyncStream.makeStream(of: SendRequest.self)
    }

    init(inbound connection: ModernConnection,
         _ peersLog: PeersLog) {

        self.outboundEndpoint = nil
        self.connection = connection
        self.initialPeerId = connection.remoteEndpoint?.peerId ?? connection.id
        self.peersLog = peersLog
        (self.sendStream, self.sendNext) = AsyncStream.makeStream(of: SendRequest.self)
    }

    var isReady: Bool { connection?.state == .ready }

    var isViable: Bool {
        if wasCancelled { return false }
        switch connection?.state {
        case .ready, .preparing, .setup: return true
        case nil: return true  // outbound dial not yet connected
        default: return false
        }
    }
    var isDead: Bool {
        if wasCancelled { return true }
        switch connection?.state {
        case .failed, .cancelled: return true
        default: return false
        }
    }
    var isFailed: Bool {
        if case .failed = connection?.state { return true }
        return false
    }
    var stateDescription: String {
        connection.map { "\($0.state)" } ?? "unstarted"
    }

    func start(onState: @escaping @Sendable (PeerLinkState) -> Void,
               onMessage: @escaping @Sendable (FramerType, Data) -> Bool) {

        startSendPump()

        if let outboundEndpoint {
            runnerTask = Task { @MainActor [weak self] in
                do {
                    try await withNetworkConnection(to: outboundEndpoint,
                                                    using: ModernParameters.builder()) { connection in
                        guard let self else { return }
                        self.connection = connection
                        await self.service(connection, onState, onMessage)
                    }
                } catch {
                    // exit already reported through onState in service()
                }
                self?.finishServiced()
            }
        } else if let connection {
            runnerTask = Task { @MainActor [weak self] in
                await self?.service(connection, onState, onMessage)
                self?.finishServiced()
            }
        }
    }

    @MainActor
    private func service(_ connection: ModernConnection,
                         _ onState: @escaping @Sendable (PeerLinkState) -> Void,
                         _ onMessage: @escaping @Sendable (FramerType, Data) -> Bool) async {

        connection.onStateUpdate { _, state in
            switch state {
            case .ready:              onState(.ready)
            case .waiting(let error): onState(.waiting("\(error)"))
            case .failed(let error):  onState(.failed("\(error)"))
            case .cancelled:          onState(.cancelled)
            default: break
            }
        }
        do {
            while !Task.isCancelled {
                let (data, meta) = try await connection.receive()
                if !onMessage(meta.framer.framerType, data) { break }
            }
        } catch {
            // failed / cancelled reported through onStateUpdate; cancel() lands here
        }
    }

    /// the listener.run handler parks here so the structured scope owning an
    /// inbound connection stays open until the link ends
    @MainActor
    func serviced() async {
        if servicedDone { return }
        await withCheckedContinuation { servicedContinuation = $0 }
    }
    @MainActor
    private func finishServiced() {
        servicedDone = true
        servicedContinuation?.resume()
        servicedContinuation = nil
    }

    /// single pump preserves send FIFO across caller threads
    private func startSendPump() {
        sendTask = Task { [weak self] in
            guard let self else { return }
            for await request in self.sendStream {
                guard let connection = self.connection else {
                    await Self.reportOnMain(request.onError, .failed("send '\(request.text)' before connect"))
                    continue
                }
                do {
                    try await connection.send(request.data,
                                              metadata: NWProtocolFramer.Message(framerType: request.type))
                } catch {
                    await Self.reportOnMain(request.onError, PeerLinkSendError.classify(error))
                }
            }
        }
    }
    private static func reportOnMain(_ onError: @escaping @Sendable (PeerLinkSendError) -> Void,
                                     _ sendError: PeerLinkSendError) async {
        await MainActor.run { onError(sendError) }
    }

    func send(_ type: FramerType,
              _ data: Data,
              _ text: String,
              onError: @escaping @Sendable (PeerLinkSendError) -> Void) {

        sendNext.yield(SendRequest(type: type, data: data, text: text, onError: onError))
    }

    func cancel() {
        wasCancelled = true
        sendNext.finish()
        sendTask?.cancel()
        runnerTask?.cancel()
    }
}
