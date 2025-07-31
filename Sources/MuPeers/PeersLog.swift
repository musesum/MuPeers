// created by musesum on 5/23/25

import SwiftUI
import Network

@Observable
class PeersLog: @unchecked Sendable {

    let peerId: String // my PeerId
    let logging: Bool
    var status: [String] = ["🎬 Action!"]

    init(_ peerId: PeerId,
         _ logging: Bool) {
        self.peerId = peerId
        self.logging = logging
    }

    func status(_ message: String)  {
        guard logging else { return }
        while self.status.count > 10 {
            self.status.removeFirst()
        }
        self.status.append(message)
        log(message)
    }
    func log(_ message: String)  {
        #if DEBUG
        guard logging else { return } 
        print("\(peerId): \(message)")
        #endif
    }
}
