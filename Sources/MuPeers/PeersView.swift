// created by musesum on 5/29/25

import SwiftUI

public struct PeersView: View {

    public init() {}
    
    public var body: some View {
        VStack (alignment: .leading) {
            Text(Peers.shared.listHandshake([.accepting,.verified]))
                .padding()
        }
    }
}
