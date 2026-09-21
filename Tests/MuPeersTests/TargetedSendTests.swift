import XCTest
@testable import MuPeers

private final class ArtworkTestLink: PeerLink, @unchecked Sendable {
    let initialPeerId: String
    var messages: [Data] = []
    var isReady = true
    var isViable: Bool { isReady }
    var isDead: Bool { !isReady }
    var isFailed: Bool { !isReady }
    var stateDescription: String { "test" }
    init(_ id: String) { initialPeerId = id }
    func start(onState: @escaping @Sendable (PeerLinkState) -> Void,
               onMessage: @escaping @Sendable (FramerType, Data) -> Bool) { }
    func send(_ type: FramerType, _ data: Data, _ text: String,
              onError: @escaping @Sendable (PeerLinkSendError) -> Void) { messages.append(data) }
    func cancel() { isReady = false }
}

@MainActor final class TargetedSendTests: XCTestCase {
    func testTargetedSendNeverBroadcastsAndRequiresVerifiedReadyPeer() async {
        let peers = Peers(PeersConfig(service: "_target-test._tcp", secret: ""), logging: false)
        peers.cancelPeers()
        await peers.peersTask?.value
        await peers.peerState.insert(.send)
        let selected = ArtworkTestLink("selected"), nearby = ArtworkTestLink("nearby")
        peers.connection.links = ["selected": selected, "nearby": nearby]
        peers.connection.sendable = ["selected", "nearby"]
        let payload = Data("private artwork".utf8)
        let sent = await peers.sendItem(.dataFrame, to: "selected") { payload }
        XCTAssertTrue(sent)
        XCTAssertEqual(selected.messages, [payload])
        XCTAssertTrue(nearby.messages.isEmpty)

        peers.connection.sendable.remove("selected")
        let unverified = await peers.sendItem(.dataFrame, to: "selected") { payload }
        XCTAssertFalse(unverified)
        peers.connection.sendable.insert("selected")
        selected.isReady = false
        let disconnected = await peers.sendItem(.dataFrame, to: "selected") { payload }
        XCTAssertFalse(disconnected)
        XCTAssertEqual(selected.messages.count, 1)
        peers.cancelPeers()
        await peers.peersTask?.value
    }
}
