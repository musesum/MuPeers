// created by musesum on 5/10/25

import Network
import SwiftUI


let PeersPrefix: String = "☯︎"

struct PeerConfig {
    let service: String
    let secret: String

    init(service: String,
         secret: String) {

        self.service = service
        self.secret = secret
    }
}

class Peers {

    let peerConfig: PeerConfig
    let peerBrowser: PeerBrowser
    let peerListener: PeerListener
    let peerConnection: PeerConnection
    let peerIdNumber: UInt64
    let peerId: String
    let peerLog: PeerLog
    var delegates: [String: PeersDelegate] = [:]

    init(_ config: PeerConfig) {

        peerConfig     = config
        peerIdNumber   = UInt64.random(in: 1...UInt64.max)
        peerId         = PeersPrefix + peerIdNumber.base32
        peerLog        = PeerLog       (peerId)
        peerConnection = PeerConnection(peerId, peerLog, peerConfig)
        peerListener   = PeerListener  (peerId, peerLog, peerConfig, peerConnection)
        peerBrowser    = PeerBrowser   (peerId, peerLog, peerConfig, peerConnection)
    }
}
