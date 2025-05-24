// created by musesum on 5/22/25

import Foundation


struct HandShake: @unchecked Sendable {

    var status: HandshakeStatus
    var time: TimeInterval

    init(_ status: HandshakeStatus,
         _ time: TimeInterval = Date().timeIntervalSince1970) {

        self.status = status
        self.time = time
    }
    mutating func change(to status: HandshakeStatus) {
        self.status = status
        self.time = Date().timeIntervalSince1970
    }
}
