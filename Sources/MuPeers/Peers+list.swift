// created by musesum on 5/23/25

import Foundation

extension Peers { // list

    func listHandshake(_ status: HandshakeStatus) -> String {
        var ret: String = ""
        let time = Date().timeIntervalSince1970

        for (id, handshake) in peerConnection.handshaking {
            if handshake.status != status { continue }
            let delta = time - handshake.time
            ret += "\(id): \(delta.digits(1)) sec\n"
        }
        if ret.count > 0 {
            ret = "–– \(status.description) ––\n" + ret
        }
        return ret
    }

    func listConnected() -> String {
        var ret = ""
        for peerId in peerConnection.connections.keys {
            ret += "\(peerId)\n"
        }
        if ret.count > 0 {
            ret = "–– connected ––\n" + ret
        }
        return ret
    }

    func listPeerStatus() -> String {
        var ret = ""
        for status in peerLog.status {
            ret += "\(status)\n"
        }
        if ret.count > 0 {
            ret = "–– status ––\n" + ret
        }
        return ret
    }
}
