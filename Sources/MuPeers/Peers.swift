// created by musesum on 5/10/25

import Network
import SwiftUI


let PeersPrefix: String = "☯︎"

public struct PeersConfig {
    let service: String
    let secret: String
    
    public init(service: String,
                secret: String) {
        
        self.service = service
        self.secret = secret
    }
}

public class Peers {

    let peersConfig: PeersConfig
    let peersBrowser: PeersBrowser
    let peersListener: PeersListener
    let peersConnection: PeersConnection
    let peerIdNumber: UInt64
    let peersLog: PeersLog

    public let peerId: String

    public init(_ config: PeersConfig) {

        peersConfig     = config
        peerIdNumber    = UInt64.random(in: 1...UInt64.max)
        peerId          = PeersPrefix + peerIdNumber.base32
        peersLog        = PeersLog       (peerId)
        peersConnection = PeersConnection(peerId, peersLog, peersConfig)
        peersListener   = PeersListener  (peerId, peersLog, peersConfig, peersConnection)
        peersBrowser    = PeersBrowser   (peerId, peersLog, peersConfig, peersConnection)
    }

    public func setDelegate(_ delegate: PeersDelegate, for peerId: String) {
        peersConnection.delegates[peerId] = delegate
    }
    public func removeDelegate(_ peerId: String) {
        peersConnection.delegates.removeValue(forKey: peerId)
    }
    public func sendItem(_ getData: ()->Data?) async {
        if !peersConnection.sendable.isEmpty,
           let data = getData() {
            await peersConnection.broadcastData(data)
        }

    }



}
