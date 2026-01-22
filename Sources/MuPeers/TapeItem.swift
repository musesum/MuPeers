// created by musesum on 11/20/25

import Foundation

public struct TapeItem: Codable, Sendable {

    public let time: TimeInterval
    public let type: FramerType
    public let data: Data

    init(_ type: FramerType, _ data: Data) {
        self.time = Date().timeIntervalSince1970
        self.type = type
        self.data = data
    }
}

