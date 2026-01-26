// created by musesum on 11/20/25

import Foundation


public final class TypeItem: Codable, @unchecked Sendable {

    public let type: FramerType
    public let data: Data
    public var time: TimeInterval

    init(_ type: FramerType, _ data: Data) {
        self.type = type
        self.data = data
        self.time = Date().timeIntervalSince1970
    }
    public func normalize(_ deltaTime: TimeInterval) {
        self.time -= deltaTime
    }
}

