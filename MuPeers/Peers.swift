// created by musesum on 5/10/25

import Network
import SwiftUI

class Peers {
    static let serviceType = "_mupeers._tcp"
    static let prefix = "☯︎"
    let peerBrowser: PeerBrowser
    let peerListener: PeerListener
    let peerConnection: PeerConnection
    let peerId = Peers.prefix + String(UUID().uuidString.prefix(8))
    let peerStatus: PeerStatus

    init() {

        peerStatus = PeerStatus(peerId)
        peerConnection = PeerConnection(peerStatus, peerId)
        peerListener = PeerListener(peerStatus, peerId, peerConnection)
        peerBrowser = PeerBrowser(peerStatus, peerId, peerConnection)
    }
}
