// created by musesum on 5/10/25

import SwiftUI
import UIKit

@main
struct PeersTestApp: App {

    let peers = Peers(
        // see info.plist for _mupeers._tcp
        // set secret to "" if you want to send in the clear,
        // which seems to avoid some ssl issues
        PeersConfig(service: "_mupeers._tcp",
                    secret: "your-secret-here"))

    var body: some Scene {
        WindowGroup {
            PeersTestView(peers)
        }
    }
}
public struct PeersTestView: View {

    let peers: Peers
    public init(_ peers: Peers) {
        self.peers = peers
    }

    public var body: some View {
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
            Text("–– handshake ––")
            Text(peers.listHandshake([.accepting,.verified]))
        }
        .padding()
    }
}
