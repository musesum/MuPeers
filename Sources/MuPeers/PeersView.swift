// created by musesum on 5/29/25

import SwiftUI

public struct PeersView: View {

    let peers: Peers
    public init(_ peers: Peers) {
        self.peers = peers
    }

    public var body: some View {
        VStack ( alignment: .leading) {
            Text(peers.listHandshake([.accepting,.verified]))
                .padding()
        }
    }
}
