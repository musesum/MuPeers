// created by musesum on 7/7/26

import XCTest
import Network

@testable import MuPeers

/// Lifecycle state-machine tests for setupPeers/cancelPeers: last-call-wins ordering,
/// instance teardown/recreation, atomic PeerState flags, tape independence. No test
/// asserts network readiness — only instance and flag state, so runs stay deterministic.
@MainActor
final class MuPeersLifecycleTests: XCTestCase {

    struct MockTape: TapeProto {
        func playItem(_ item: PlayItem) async { }
    }

    private func makePeers() -> Peers {
        Peers(PeersConfig(service: "_mupeers-test._tcp", secret: ""), logging: false)
    }

    /// await the serialized transition chain so assertions see the settled state
    private func settle(_ peers: Peers) async {
        await peers.peersTask?.value
    }

    func testInitStartsListenerAndBrowser() {
        let peers = makePeers()
        XCTAssertNotNil(peers.listener.listener)
        XCTAssertNotNil(peers.browser.browser)
    }

    func testCancelNilsListenerAndBrowserAndClearsFlags() async {
        let peers = makePeers()
        peers.cancelPeers()
        await settle(peers)
        XCTAssertNil(peers.listener.listener)
        XCTAssertNil(peers.browser.browser)
        let status = await peers.peerState.status
        XCTAssertFalse(status.hasAny([.send, .receive]))
    }

    func testCancelThenSetupRestoresListenerBrowserAndFlags() async {
        let peers = makePeers()
        peers.cancelPeers()
        peers.setupPeers(MockTape())
        await settle(peers)
        XCTAssertNotNil(peers.listener.listener)
        XCTAssertNotNil(peers.browser.browser)
        let status = await peers.peerState.status
        XCTAssertTrue(status.has([.send, .receive]))
    }

    func testLastCallWinsOnRapidToggle() async {
        let peers = makePeers()
        // off → on issued back-to-back: end state must be ON
        peers.cancelPeers()
        peers.setupPeers(MockTape())
        await settle(peers)
        XCTAssertNotNil(peers.listener.listener)
        let onStatus = await peers.peerState.status
        XCTAssertTrue(onStatus.has([.send, .receive]))

        // on → off issued back-to-back: end state must be OFF
        peers.setupPeers(MockTape())
        peers.cancelPeers()
        await settle(peers)
        XCTAssertNil(peers.listener.listener)
        let offStatus = await peers.peerState.status
        XCTAssertFalse(offStatus.hasAny([.send, .receive]))
    }

    func testSetTapePreservesSendReceive() async {
        let peers = makePeers()
        peers.setupPeers(MockTape())
        await settle(peers)
        await peers.setTape(on: true)
        var status = await peers.peerState.status
        XCTAssertTrue(status.has([.send, .receive, .taping]))
        await peers.setTape(on: false)
        status = await peers.peerState.status
        XCTAssertTrue(status.has([.send, .receive]))
        XCTAssertFalse(status.has(.taping))
    }

    func testTapeProtoSurvivesCancel() async {
        // Tape record must not depend on the Bonjour toggle: setTape works after cancelPeers.
        let peers = makePeers()
        peers.setupPeers(MockTape())
        peers.cancelPeers()
        await settle(peers)
        await peers.setTape(on: true)
        let status = await peers.peerState.status
        XCTAssertTrue(status.has(.taping))
        XCTAssertFalse(status.hasAny([.send, .receive]))
    }

    func testPeerStateAtomicInsertSubtract() async {
        // concurrent insert(.taping) and subtract([.send,.receive]) from [.send,.receive]
        // must always end [.taping] — a get-modify-set implementation loses one of them
        for _ in 0..<100 {
            let state = PeerState()
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await state.insert(.taping) }
                group.addTask { await state.subtract([.send, .receive]) }
            }
            let status = await state.status
            XCTAssertTrue(status.has(.taping))
            XCTAssertFalse(status.hasAny([.send, .receive]))
        }
    }
}
