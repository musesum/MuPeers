// created by musesum on 5/23/25

import SwiftUI
import Network

@Observable
class PeersLog: @unchecked Sendable {

    let peerId: String // my PeerId
    var status: [String] = ["🎬 Action!"]

    init(_ peerId: PeerId) {
        self.peerId = peerId
    }

    func status(_ message: String)  {
        while self.status.count > 10 {
            self.status.removeFirst()
        }
        self.status.append(message)
        log(message)
    }
    func log(_ message: String)  {
        #if DEBUG
        print("\(peerId): \(message)")
        #endif
    }
}
