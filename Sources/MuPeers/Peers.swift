// created by musesum on 5/10/25

import Network
import SwiftUI


let PeersPrefix: String = "☯︎"

extension UInt64 {
    /// Convert UInt64 to base32 string using custom encoding for compactness
    var base32: String {
        let base32Alphabet = "abcdefghijklmnopqrstuvwxyz234567"
        var value = self
        var result = ""
        
        // Generate exactly 13 base32 characters (65 bits worth)
        // We only need 11 characters after the prefix for 12 total
        for _ in 0..<11 {
            let index = Int(value & 0x1F) // 5 bits
            result = String(base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)]) + result
            value >>= 5
        }
        
        return result
    }
    
    /// Convert base32 string back to UInt64
    init?(base32: String) {
        let base32Alphabet = "abcdefghijklmnopqrstuvwxyz234567"
        var value: UInt64 = 0
        
        for char in base32 {
            guard let index = base32Alphabet.firstIndex(of: char) else { return nil }
            value = (value << 5) | UInt64(base32Alphabet.distance(from: base32Alphabet.startIndex, to: index))
        }
        
        self = value
    }
}

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
