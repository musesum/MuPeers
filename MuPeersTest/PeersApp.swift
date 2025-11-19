// created by musesum on 5/10/25

import SwiftUI
import UIKit

@main
struct PeersTestApp: App {
    // see info.plist for _mupeers._tcp
    // set secret to "" if you want to send in the clear,
    // which seems to avoid some ssl issues
    let config: PeersConfig
    let peers: Peers

    init() {
        self.config = PeersConfig(service: "_mupeers._tcp", secret: "") // "your-secret-here"
        self.peers = Peers(config, mirror: nil, logging: true)
        self.peers.setupPeers()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(peers: peers)
        }
    }
}

@MainActor
public class AppViewModel: ObservableObject {
    @Published var counter = 0
    @Published var peerCounters: [String: Int] = [:]
    private var timer: Timer?
    private var sendTimer: Timer?
    private var delegate: DataFrameDelegate?
    private let peers: Peers
    let peerId: String
    
    init(peers: Peers) {
        self.peers = peers
        self.peerId = peers.peerId
        setupDelegate()
        startTimer()
        startSendTimer()
    }
    
    private func setupDelegate() {
        let newDelegate = DataFrameDelegate { [weak self] message in
            self?.peerCounters[message.peerId] = message.counter
        }
        self.delegate = newDelegate
        peers.addDelegate(newDelegate, for: .dataFrame)
    }
    
    private func startTimer() {
        counter = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.counter += 1
            }
        }
    }
    
    private func startSendTimer() {
        // Send messages every second, but delay initial sending for 2 seconds to allow connections to establish
        sendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let currentCounter = self.counter
                let currentPeerId = self.peerId
                
                // Clean up peer counters and stale connections less frequently - only every 10 seconds
                let currentTime = currentCounter
                if currentTime % 10 == 0 {
                    self.peerCounters = self.peerCounters.filter { _, lastCounter in
                        // Keep peers that sent a message within the last 15 seconds
                        currentTime - lastCounter <= 15
                    }
                    // Also cleanup stale connections in PeersConnection
                    self.peers.cleanupStaleConnections()
                }
                
                // Only send after a few seconds to ensure connections are established
                if currentCounter > 2 {
                    await self.peers.sendItem(.dataFrame) { @Sendable in
                        let message = CounterMessage(peerId: currentPeerId, counter: currentCounter)
                        return try? JSONEncoder().encode(message)
                    }
                }
            }
        }
    }
    
    private func stopTimer() async {
        timer?.invalidate()
        timer = nil
    }
}

struct ContentView: View {
    let peers: Peers
    @State private var selection = 0
    @StateObject private var appViewModel: AppViewModel
    
    init(peers: Peers) {
        self.peers = peers
        self._appViewModel = StateObject(wrappedValue: AppViewModel(peers: peers))
    }
    
    var body: some View {
        TabView(selection: $selection) {
            PeersTestView(peers: peers, appViewModel: appViewModel)
                .tabItem {
                    Label("Peers", systemImage: "person.2")
                }
                .tag(0)
            
            DataFrameTestView(appViewModel: appViewModel)
                .tabItem {
                    Label("Data Test", systemImage: "timer")
                }
                .tag(1)
        }
    }
}

public struct PeersTestView: View {

    let peers: Peers
    @ObservedObject var appViewModel: AppViewModel
    
    public init(peers: Peers, appViewModel: AppViewModel) {
        self.peers = peers
        self.appViewModel = appViewModel
    }

    public var body: some View {
        VStack ( alignment: .leading){
            HStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("\(Idiom.name) (\(peers.peerId)) \(appViewModel.counter)s")
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

struct CounterMessage: Codable {
    let peerId: String
    let counter: Int
}

final class DataFrameDelegate: PeersDelegate {
    private let updateHandler: @Sendable @MainActor (CounterMessage) -> Void
    
    init(updateHandler: @escaping @Sendable @MainActor (CounterMessage) -> Void) {
        self.updateHandler = updateHandler
    }
    
    func received(data: Data) {
        if let message = try? JSONDecoder().decode(CounterMessage.self, from: data) {
            let handler = updateHandler
            Task { @MainActor in
                handler(message)
            }
        }
    }
}

struct DataFrameTestView: View {
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("\(Idiom.name) (\(appViewModel.peerId)) \(appViewModel.counter)s")
            }
            
            Divider()
                .padding(.vertical, 10)
            
            Text("Peers:")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(appViewModel.peerCounters.keys).sorted(), id: \.self) { peerId in
                        Text("\(peerId)  \(appViewModel.peerCounters[peerId] ?? 0)s")
                    }
                }
            }
            .padding(.top, 5)
            
            Spacer()
        }
        .padding()
    }
}
