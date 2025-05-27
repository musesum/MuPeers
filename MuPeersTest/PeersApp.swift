// created by musesum on 5/10/25

import SwiftUI
import UIKit

@main
struct PeersApp: App {

    let peers = Peers(
        PeerConfig(service: "_mupeers._tcp", // see info.plist
                   secret: "")) // shared secret - change this!

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
            Text(peers.listPeerStatus())
            Text(peers.listConnected())
            Text(peers.listHandshake(.inviting))
            Text(peers.listHandshake(.accepting))
            Text(peers.listHandshake(.verified))
        }
        .padding()
    }
}
