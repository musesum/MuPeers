// created by musesum on 11/18/25

import Network
import SwiftUI

public actor PeerState {
    public var status = PeersOpt([.send, .receive])
    func hasAny(_ value: PeersOpt) -> Bool {
        return status.hasAny(value)
    }
    func has(_ value: PeersOpt) -> Bool {
        return status.has(value)
    }
    func set(_ value: PeersOpt) { status = value }

}


public struct PeersOpt: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {

    static let send    = PeersOpt(rawValue: 1 << 0)
    static let receive = PeersOpt(rawValue: 1 << 1)
    static let mirror  = PeersOpt(rawValue: 1 << 2)

    public var rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    var send    : Bool { contains(.send   ) }
    var receive : Bool { contains(.receive) }
    var mirror  : Bool { contains(.mirror ) }

    public var description: String {
        var script: [String] = []
        if contains(.send   ) { script.append("send") }
        if contains(.receive) { script.append("receive") }
        if contains(.mirror ) { script.append("mirror") }
        return "[" + script.joined(separator: ", ") + "]"
    }

    public var debugDescription: String { description }

    func hasAny(_ value: PeersOpt) -> Bool {
        !self.intersection(value).isEmpty
    }
    func has(_ value: PeersOpt) -> Bool {
        self.contains(value)
    }
   
}

