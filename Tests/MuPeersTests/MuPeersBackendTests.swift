// created by musesum on 7/25/26

import XCTest
import Network

@testable import MuPeers

/// Backend runtime-switch tests: resolution rules, dormant legacy pair under
/// modern, setBackend swap serialization, and frozen wire-header layout.
/// No test asserts network readiness — instance and flag state only.
@MainActor
final class MuPeersBackendTests: XCTestCase {

    struct MockTape: TapeProto {
        func playItem(_ item: PlayItem) async { }
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: PeersBackend.defaultsKey)
    }
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: PeersBackend.defaultsKey)
        super.tearDown()
    }

    private func makePeers(_ backend: PeersBackend? = nil) -> Peers {
        Peers(PeersConfig(service: "_mupeers-test._tcp", secret: "", backend: backend),
              logging: false)
    }
    /// await the serialized transition chain so assertions see the settled state
    private func settle(_ peers: Peers) async {
        await peers.peersTask?.value
    }

    // MARK: resolution

    func testDefaultBackendIsLegacy() {
        let peers = makePeers()
        XCTAssertEqual(peers.backend, .legacy)
        XCTAssertNotNil(peers.listener.listener)
        XCTAssertNotNil(peers.browser.browser)
    }

    func testStoredDefaultResolvesWhenConfigNil() {
        UserDefaults.standard.set(PeersBackend.modern.rawValue, forKey: PeersBackend.defaultsKey)
        let peers = makePeers()
        if PeersBackend.modernAvailable {
            XCTAssertEqual(peers.backend, .modern)
        } else {
            XCTAssertEqual(peers.backend, .legacy)
        }
    }

    func testConfigBackendOverridesStoredDefault() {
        UserDefaults.standard.set(PeersBackend.modern.rawValue, forKey: PeersBackend.defaultsKey)
        let peers = makePeers(.legacy)
        XCTAssertEqual(peers.backend, .legacy)
    }

    func testModernWithSecretResolvesLegacy() {
        let peers = Peers(PeersConfig(service: "_mupeers-test._tcp",
                                      secret: "hush",
                                      backend: .modern),
                          logging: false)
        XCTAssertEqual(peers.backend, .legacy)
    }

    // MARK: modern lifecycle (OS 26 gated)

    func testModernInitStartsModernPairNotLegacy() throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.modern)
        XCTAssertEqual(peers.backend, .modern)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertTrue(peers.modernListener?.isActive ?? false)
            XCTAssertTrue(peers.modernBrowser?.isActive ?? false)
        }
        XCTAssertNil(peers.listener.listener)
        XCTAssertNil(peers.browser.browser)
    }

    func testModernCancelNilsTasksAndClearsFlags() async throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.modern)
        peers.cancelPeers()
        await settle(peers)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertFalse(peers.modernListener?.isActive ?? false)
            XCTAssertFalse(peers.modernBrowser?.isActive ?? false)
        }
        let status = await peers.peerState.status
        XCTAssertFalse(status.hasAny([.send, .receive]))
    }

    func testModernCancelThenSetupRestores() async throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.modern)
        peers.cancelPeers()
        peers.setupPeers(MockTape())
        await settle(peers)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertTrue(peers.modernListener?.isActive ?? false)
            XCTAssertTrue(peers.modernBrowser?.isActive ?? false)
        }
        let status = await peers.peerState.status
        XCTAssertTrue(status.has([.send, .receive]))
    }

    // MARK: setBackend

    func testSetBackendModernToLegacySwapsPairs() async throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.modern)
        peers.setupPeers(MockTape())
        peers.setBackend(.legacy)
        await settle(peers)
        XCTAssertEqual(peers.backend, .legacy)
        XCTAssertNotNil(peers.listener.listener)
        XCTAssertNotNil(peers.browser.browser)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertFalse(peers.modernListener?.isActive ?? false)
            XCTAssertFalse(peers.modernBrowser?.isActive ?? false)
        }
        // switching transports must not drop send/receive
        let status = await peers.peerState.status
        XCTAssertTrue(status.has([.send, .receive]))
    }

    func testSetBackendLegacyToModernSwapsPairs() async throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.legacy)
        peers.setupPeers(MockTape())
        peers.setBackend(.modern)
        await settle(peers)
        XCTAssertEqual(peers.backend, .modern)
        XCTAssertNil(peers.listener.listener)
        XCTAssertNil(peers.browser.browser)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertTrue(peers.modernListener?.isActive ?? false)
            XCTAssertTrue(peers.modernBrowser?.isActive ?? false)
        }
    }

    func testSetBackendLastCallWins() async throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.legacy)
        peers.setupPeers(MockTape())
        // modern → legacy issued back-to-back: end state must be legacy
        peers.setBackend(.modern)
        peers.setBackend(.legacy)
        await settle(peers)
        XCTAssertEqual(peers.backend, .legacy)
        XCTAssertNotNil(peers.listener.listener)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertFalse(peers.modernListener?.isActive ?? false)
        }
    }

    func testSetBackendWhileCancelledStaysDormant() async throws {
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }
        let peers = makePeers(.legacy)
        peers.cancelPeers()
        peers.setBackend(.modern)
        await settle(peers)
        XCTAssertEqual(peers.backend, .modern)
        // no transport may start while send/receive are off
        XCTAssertNil(peers.listener.listener)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            XCTAssertFalse(peers.modernListener?.isActive ?? false)
            XCTAssertFalse(peers.modernBrowser?.isActive ?? false)
        }
    }

    // MARK: wire format

    func testWireHeaderLayoutFrozen() {
        // both backends share PeerFramer; the 8-byte header must never drift
        XCTAssertEqual(PeerFramerHeader.encodedSize, 8)
        let header = PeerFramerHeader(type: FramerType.handshake.rawValue, length: 0xABCD)
        let data = header.encodedData
        XCTAssertEqual(data.count, 8)
        let type = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let length = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        XCTAssertEqual(type, FramerType.handshake.rawValue)
        XCTAssertEqual(length, 0xABCD)
        // round-trip through the parse-side init
        var bytes = [UInt8](data)
        bytes.withUnsafeMutableBytes { raw in
            let parsed = PeerFramerHeader(raw)
            XCTAssertEqual(parsed.type, FramerType.handshake.rawValue)
            XCTAssertEqual(parsed.length, 0xABCD)
        }
    }

    func testFramerTypeRawValuesFrozen() {
        // wire compatibility: raw values are the on-wire type field
        XCTAssertEqual(FramerType.invalid.rawValue, 0)
        XCTAssertEqual(FramerType.handshake.rawValue, 1)
        XCTAssertEqual(FramerType.dataFrame.rawValue, 2)
        XCTAssertEqual(FramerType.midiItem.rawValue, 3)
        XCTAssertEqual(FramerType.touchCanvas.rawValue, 4)
        XCTAssertEqual(FramerType.menuItem.rawValue, 5)
        XCTAssertEqual(FramerType.handFrame.rawValue, 6)
        XCTAssertEqual(FramerType.tapeTrack.rawValue, 7)
        XCTAssertEqual(FramerType.playStatus.rawValue, 8)
        XCTAssertEqual(FramerType.archiveFrame.rawValue, 9)
        XCTAssertEqual(FramerType.gestureItem.rawValue, 10)
    }
}

/// Cross-backend loopback: a legacy Peers and a modern Peers on one host must
/// discover, handshake, and exchange a dataFrame. Real networking — gated by
/// MUPEERS_NET_TESTS=1 (local-network privacy can block CI/sandbox runs).
@MainActor
final class MuPeersInteropTests: XCTestCase {

    struct MockTape: TapeProto {
        func playItem(_ item: PlayItem) async { }
    }

    final class JoinDelegate: PeersDelegate, @unchecked Sendable {
        let onJoined: @Sendable @MainActor (String) -> Void
        let onData: @Sendable @MainActor (Data) -> Void
        init(onJoined: @escaping @Sendable @MainActor (String) -> Void,
             onData: @escaping @Sendable @MainActor (Data) -> Void) {
            self.onJoined = onJoined
            self.onData = onData
        }
        func received(data: Data, from: DataFrom) {
            let onData = self.onData
            Task { @MainActor in onData(data) }
        }
        func joined(from: DataFrom) {
            guard case .remote(let id) = from else { return }
            let onJoined = self.onJoined
            Task { @MainActor in onJoined(id) }
        }
        func shareItem(_ item: Any) {}
        func resetItem(_ item: PlayItem) {}
        func playItem(_ item: PlayItem, from: DataFrom) {}
        func dropped(from: DataFrom) {}
    }

    func testLegacyAndModernInterop() async throws {
        guard ProcessInfo.processInfo.environment["MUPEERS_NET_TESTS"] == "1" else {
            throw XCTSkip("set MUPEERS_NET_TESTS=1 to run loopback interop")
        }
        guard PeersBackend.modernAvailable else { throw XCTSkip("requires OS 26") }

        let service = "_mupeers-x\(UInt32.random(in: 1000...9999))._tcp"
        let legacyPeers = Peers(PeersConfig(service: service, secret: "", backend: .legacy), logging: true)
        let modernPeers = Peers(PeersConfig(service: service, secret: "", backend: .modern), logging: true)

        let joinedLegacy = expectation(description: "legacy joined")
        let joinedModern = expectation(description: "modern joined")
        let dataAtModern = expectation(description: "modern received dataFrame")

        let legacyDelegate = JoinDelegate(
            onJoined: { _ in joinedLegacy.fulfill() },
            onData: { _ in })
        let modernDelegate = JoinDelegate(
            onJoined: { _ in joinedModern.fulfill() },
            onData: { data in
                if String(data: data, encoding: .utf8) == "ping" { dataAtModern.fulfill() }
            })

        legacyPeers.addDelegate(legacyDelegate, for: .dataFrame)
        modernPeers.addDelegate(modernDelegate, for: .dataFrame)
        legacyPeers.setupPeers(MockTape())
        modernPeers.setupPeers(MockTape())

        await fulfillment(of: [joinedLegacy, joinedModern], timeout: 20)

        await legacyPeers.sendItem(.dataFrame) { "ping".data(using: .utf8) }
        await fulfillment(of: [dataAtModern], timeout: 10)

        legacyPeers.cancelPeers()
        modernPeers.cancelPeers()
        await legacyPeers.peersTask?.value
        await modernPeers.peersTask?.value
    }
}
