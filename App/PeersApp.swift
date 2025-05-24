// created by musesum on 5/10/25

import SwiftUI
import UIKit

@main
struct PeersApp: App {
    let peers = Peers()
    var body: some Scene {
        WindowGroup {
            PeersView(peers)
        }
    }
}

struct PeersView: View {

    let peers: Peers
    init(_ peers: Peers) {
        self.peers = peers
    }

    var body: some View {
        VStack ( alignment: .leading){
            HStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("\(PeerDevice.name) (\(peers.peerId))")
            }
            Text("")
            Text(peers.statusList("status"))
            Text(peers.connectedList("connected"))
            Text(peers.list("inviting", for: .inviting))
            Text(peers.list("accepting", for: .accepting))
            Text(peers.list("verified", for: .verified))
        }
        .padding()
    }
}
