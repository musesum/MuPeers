// created by musesum on 11/20/25

import Foundation


public final class PlayItem: Codable, @unchecked Sendable {

    public let type: FramerType
    public let data: Data
    public let path: String
    public var time: TimeInterval

    public init(_ type: FramerType, _ data: Data, path: String = "") {
        self.type = type
        self.data = data
        self.path = path
        self.time = Date().timeIntervalSince1970
    }
    init() {
        self.type = .init(rawValue: 0)!
        self.data = Data()
        self.path = ""
        self.time = Date().timeIntervalSince1970
    }
    public func normalize(_ deltaTime: TimeInterval) {
        self.time -= deltaTime
    }

    enum CodingKeys: String, CodingKey { case type, data, path, time }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(FramerType.self, forKey: .type)
        self.data = try c.decode(Data.self, forKey: .data)
        self.path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        self.time = try c.decode(TimeInterval.self, forKey: .time)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(data, forKey: .data)
        try c.encode(path, forKey: .path)
        try c.encode(time, forKey: .time)
    }
}
