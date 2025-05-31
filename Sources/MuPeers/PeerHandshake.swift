// created by musesum on 5/22/25

import Foundation

public enum HandshakeStatus: Int, Codable, @unchecked Sendable {
    case inviting
    case awaitng
    case accepting
    case verified

    var description: String {
        switch self {
        case .inviting  : return "inviting"
        case .awaitng   : return "awaiting"
        case .accepting : return "accepting"
        case .verified  : return "verified"
        }
    }
}

struct PeerHandshake: @unchecked Sendable {

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

struct HandshakeMessage: Codable, @unchecked Sendable {
    let peerId: String
    let status: HandshakeStatus

    init(_ peerId: PeerId,
         _ status: HandshakeStatus) {
        self.peerId = peerId
        self.status = status
    }
}
