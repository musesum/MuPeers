// created by musesum on 5/23/25

import SwiftUI
import Network

@Observable
class PeerStatus: @unchecked Sendable {

    let peerId: String
    var status: [String] = ["🎬 Starting"]

    init(_ peerId: String) {
        self.peerId = peerId
    }

    func message(_ message: String)  {
        while self.status.count > 10 {
            self.status.removeFirst()
        }
        self.status.append(message)
        print("\(peerId): \(message)")
    }
    func log(_ message: String)  {
        print("\(peerId): \(message)")
    }
}
