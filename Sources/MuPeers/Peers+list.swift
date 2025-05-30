// created by musesum on 5/23/25

import Foundation

extension Peers { // list

    func listHandshake(_ status: [HandshakeStatus]) -> String {
        var ret: String = ""
        for (id, handshake) in connections.handshaking {
            if status.contains(handshake.status) {
                ret += "\(id): \(handshake.status.description)\n"
            }
        }
        return ret
    }

    func listConnected() -> String {
        var ret = ""
        for peerId in connections.nwConnect.keys {
            ret += "\(peerId)\n"
        }
        if ret.count > 0 {
            ret = "–– connected ––\n" + ret
        }
        return ret
    }

    func listPeerStatus() -> String {
        var ret = ""
        for status in peersLog.status {
            ret += "\(status)\n"
        }
        if ret.count > 0 {
            ret = "–– status ––\n" + ret
        }
        return ret
    }
}
extension Formatter {
    static let number = NumberFormatter()
}
extension FloatingPoint {

    func digits(_ range: Int) -> String {

        if range == 0 {
            Formatter.number.maximumFractionDigits = 0
            Formatter.number.numberStyle = .decimal
            Formatter.number.roundingMode = .down  // Ensure truncation
            Formatter.number.usesGroupingSeparator = false
            let str = Formatter.number.string(for: self) ?? ""
            return str
        }
        let lower: Int
        let minus: Bool
        if range < 0 {
            lower = -range
            minus = true
        } else {
            lower = range
            minus = false
        }
        Formatter.number.roundingMode = NumberFormatter.RoundingMode.halfEven
        Formatter.number.minimumFractionDigits = lower
        Formatter.number.maximumFractionDigits = lower
        Formatter.number.usesGroupingSeparator = false
        let str = Formatter.number.string(for:  self) ?? ""
        return minus && self < 0 ? str : " " + str
    }
}
