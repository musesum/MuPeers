// created by musesum on 7/25/26

import XCTest
import Network

@testable import MuPeers

/// Wire-format freeze: the 8-byte PeerFramer header and FramerType raw values
/// are the on-wire contract with any peer version or platform port.
final class MuPeersWireTests: XCTestCase {

    func testWireHeaderLayoutFrozen() {
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

/// Two Peers instances on one host must discover, handshake, and exchange a
/// dataFrame. Real networking — gated by MUPEERS_NET_TESTS=1 (local-network
/// privacy can block CI/sandbox runs).
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

    func testPeerLoopback() async throws {
        guard ProcessInfo.processInfo.environment["MUPEERS_NET_TESTS"] == "1" else {
            throw XCTSkip("set MUPEERS_NET_TESTS=1 to run loopback interop")
        }
        guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) else {
            throw XCTSkip("peer networking requires OS 26")
        }

        let service = "_mupeers-x\(UInt32.random(in: 1000...9999))._tcp"
        let peersA = Peers(PeersConfig(service: service, secret: ""), logging: true)
        let peersB = Peers(PeersConfig(service: service, secret: ""), logging: true)

        let joinedA = expectation(description: "A joined")
        let joinedB = expectation(description: "B joined")
        let dataAtB = expectation(description: "B received dataFrame")

        let delegateA = JoinDelegate(
            onJoined: { _ in joinedA.fulfill() },
            onData: { _ in })
        let delegateB = JoinDelegate(
            onJoined: { _ in joinedB.fulfill() },
            onData: { data in
                if String(data: data, encoding: .utf8) == "ping" { dataAtB.fulfill() }
            })

        peersA.addDelegate(delegateA, for: .dataFrame)
        peersB.addDelegate(delegateB, for: .dataFrame)
        peersA.setupPeers(MockTape())
        peersB.setupPeers(MockTape())

        await fulfillment(of: [joinedA, joinedB], timeout: 20)

        await peersA.sendItem(.dataFrame) { "ping".data(using: .utf8) }
        await fulfillment(of: [dataAtB], timeout: 10)

        peersA.cancelPeers()
        peersB.cancelPeers()
        await peersA.peersTask?.value
        await peersB.peersTask?.value
    }
}
