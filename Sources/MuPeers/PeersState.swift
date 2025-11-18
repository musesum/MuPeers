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


public struct PeersOpt: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    static let send    = PeersOpt(rawValue: 1 << 0)
    static let receive = PeersOpt(rawValue: 1 << 1)
    static let mirror  = PeersOpt(rawValue: 1 << 2)

    var send    : Bool { contains(.send   ) }
    var receive : Bool { contains(.receive) }
    var mirror  : Bool { contains(.mirror ) }

    func hasAny(_ value: PeersOpt) -> Bool {
        !self.intersection(value).isEmpty
    }
    func has(_ value: PeersOpt) -> Bool {
        self.contains(value)
    }
}
