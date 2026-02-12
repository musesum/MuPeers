// created by musesum on 8/12/25

import Foundation

public struct PlayState: OptionSet, Sendable, Codable {

    public static let stop   = PlayState(rawValue: 1 << 0)
    public static let play   = PlayState(rawValue: 1 << 1)
    public static let record = PlayState(rawValue: 1 << 2)
    public static let loop   = PlayState(rawValue: 1 << 3)
    public static let learn  = PlayState(rawValue: 1 << 4)
    public static let beat   = PlayState(rawValue: 1 << 5)
    public static let ending = PlayState(rawValue: 1 << 6)
    public static let remove = PlayState(rawValue: 1 << 7)

    public var rawValue: UInt
    public init(rawValue: UInt = 0) { self.rawValue = rawValue }

    public static let debugDescriptions: [(Self, String)] = [
        (.stop   , "stop"   ),
        (.play   , "play"   ),
        (.record , "record" ),
        (.loop   , "loop"   ),
        (.learn  , "learn"  ),
        (.beat   , "beat"   ),
        (.ending , "ending" ),
        (.remove , "remove" ),
    ]

    public var description: String {
        let result: [String] = Self.debugDescriptions.filter { contains($0.0) }.map { $0.1 }
        let joined = result.joined(separator: ",")
        return "[\(joined)]"
    }

    public var stop   : Bool { contains(.stop  ) }
    public var play   : Bool { contains(.play  ) }
    public var record : Bool { contains(.record) }
    public var loop   : Bool { contains(.loop  ) }
    public var learn  : Bool { contains(.learn ) }
    public var beat   : Bool { contains(.beat  ) }
    public var ending : Bool { contains(.ending) }
    public var remove : Bool { contains(.remove) }

    public func hasAny(_ value: PlayState) -> Bool {
        self.intersection(value).isEmpty == false
    }
    public func has(_ value: PlayState) -> Bool {
        self.contains(value)
    }

    public mutating func updateState(_ state: PlayState, on: Bool) {
        if on {
            setOn(state)
        } else {
            setOff(state)
        }
    }
    public mutating func setOff(_ state: PlayState) {
        self = self.subtracting(state)
    }
    public mutating func setOn(_ state: PlayState) {
        switch state {
        case .stop   : set(on: .stop  , off: [.record, .play, .learn, .beat, .remove, .ending])
        case .play   : set(on: .play  , off: [.record, .stop, .learn, .beat, .remove, .ending])
        case .record : set(on: .record, off: [.play,   .stop, .learn, .beat, .remove, .ending])
        case .loop   : set(on: .loop  , off: [.remove, .ending])
        case .learn  : set(on: .learn , off: [.record, .stop, .play, .beat,  .remove, .ending])
        case .beat   : set(on: .beat  , off: [.record, .stop, .play, .learn, .remove, .ending])
        case .ending : set(on: .ending, off: [])
        case .remove : set(on: .remove, off: [])
        default:  self = state
        }
    }
    public mutating func set(on: PlayState, off: PlayState) {
        self.insert(on)
        self = self.subtracting(off)
    }
    public mutating func adjust(_ nextState: PlayState, _ on: Bool) {
        if on {
            self.insert(nextState)
        } else {
            self = self.subtracting(nextState)
        }
    }
}








