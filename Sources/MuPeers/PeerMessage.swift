// created by musesum on 5/16/25

import Foundation

struct PeerMessage: Codable, @unchecked Sendable {
    let peerId: String
    let text: String

    init(_ peerId: PeerId,
         _ text: String) {
        self.peerId = peerId
        self.text = text
    }
}

