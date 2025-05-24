// created by musesum on 5/23/25

import Foundation

extension Peers { // list

    func list(_ title: String, for status: HandshakeStatus) -> String {
        var ret: String = ""
        let time = Date().timeIntervalSince1970

        for (id, handshake) in peerConnection.handshake {
            if handshake.status != status { continue }
            let delta = time - handshake.time
            ret += "\(id): \(delta.digits(1)) sec\n"
        }
        if ret.count > 0 {
            ret = "–– \(title) ––\n" + ret
        }
        return ret
    }

    func connectedList(_ title: String) -> String {
        var ret = ""
        for peerId in peerConnection.connections.keys {
            ret += "\(peerId)\n"
        }
        if ret.count > 0 {
            ret = "–– \(title) ––\n" + ret
        }
        return ret
    }

    func statusList(_ title: String) -> String {
        var ret = ""
        for status in peerStatus.status {
            ret += "\(status)\n"
        }
        if ret.count > 0 {
            ret = "–– \(title) ––\n" + ret
        }
        return ret
    }
}
