// created by musesum on 5/16/25

import Foundation


struct PeerMessage: Codable, @unchecked Sendable {
    let peerId: String
    let name: String
    let text: String

    init(_ peerId: String,
         _ name: String,
         _ text: String) {
        self.peerId = peerId
        self.name = name
        self.text = text
    }
    var title: String { "\(name)(\(peerId))" }
}

