// created by musesum on 11/20/25

import Foundation


public final class PlayItem: Codable, @unchecked Sendable {

    public let type: FramerType
    public let data: Data
    public let path: String
    public var time: TimeInterval
    /// touch/controller phase — 0 began, 1 moved, 2 ended; nil instantaneous.
    /// Optional so old payloads decode and old peers skip the key.
    public let phase: Int?
    /// concurrent-touch slot 1… for multi-finger row clusters; nil single-source
    public let finger: Int?

    public init(_ type: FramerType, _ data: Data, path: String = "",
                phase: Int? = nil, finger: Int? = nil) {
        self.type = type
        self.data = data
        self.path = path
        self.time = Date().timeIntervalSince1970
        self.phase = phase
        self.finger = finger
    }
    init() {
        self.type = .init(rawValue: 0)!
        self.data = Data()
        self.path = ""
        self.time = Date().timeIntervalSince1970
        self.phase = nil
        self.finger = nil
    }
    public func normalize(_ deltaTime: TimeInterval) {
        self.time -= deltaTime
    }

    enum CodingKeys: String, CodingKey { case type, data, path, time, phase, finger }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(FramerType.self, forKey: .type)
        self.data = try c.decode(Data.self, forKey: .data)
        self.path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        self.time = try c.decode(TimeInterval.self, forKey: .time)
        self.phase = try c.decodeIfPresent(Int.self, forKey: .phase)
        self.finger = try c.decodeIfPresent(Int.self, forKey: .finger)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(data, forKey: .data)
        try c.encode(path, forKey: .path)
        try c.encode(time, forKey: .time)
        try c.encodeIfPresent(phase, forKey: .phase)
        try c.encodeIfPresent(finger, forKey: .finger)
    }
}
