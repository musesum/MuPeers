// created by musesum on 5/10/25

import Foundation

public protocol TapeProto: Sendable {
    func tapeItem(_ item: TapeItem) async
}

final public class Peers: @unchecked Sendable {

    @MainActor public static let shared = Peers(
        PeersConfig(service: "_deepmuse-peer._tcp",secret: ""),
        logging: false)

    let browser    : PeersBrowser
    let listener   : PeersListener
    let connection : PeersConnection
    let peersLog   : PeersLog
    var tapeProto  : TapeProto?

    public let peerId: String
    private let peerState = PeerState()

    public init(_ config: PeersConfig,
                logging: Bool) {

        self.peerId     = PeersPrefix + UInt64.random(in: 1...UInt64.max).base32
        self.peersLog   = PeersLog       (peerId, logging)
        self.connection = PeersConnection(peerId, peersLog, config)
        self.listener   = PeersListener  (peerId, peersLog, config, connection)
        self.browser    = PeersBrowser   (peerId, peersLog, config, connection)
        //must call setupPeers(tapeProto) to allow record, playback
    }
    public func setupPeers(_ tapeProto: TapeProto) {
        self.tapeProto = tapeProto
        
        Task {
            if await !peerState.has([.send, .receive]) {
                listener.setupListener()
                browser.setupBrowser()
            }
        }
    }
    public func cancelPeers() {
        Task {
            if await peerState.hasAny([.send, .receive]) {
                await peerState.set([])
                listener.cancelListener()
                browser.cancelBrowser()
            }
        }
    }

    public func addDelegate(_ delegate: PeersDelegate,
                            for framerType: FramerType) {
        
        if connection.delegates[framerType] != nil {
            connection.delegates[framerType]?.append(delegate)
        } else {
            connection.delegates[framerType] = [delegate]
        }
    }
    
    public func removeDelegate(_ delegate: PeersDelegate) async {
        for (key, var delegates) in connection.delegates {
            delegates.removeAll { $0 === delegate }
            connection.delegates[key] = delegates
        }
    }

    /// make sure there is a connection before
    /// the expense of getData() encoding the message
    public func sendItem(_ type: FramerType,
                         _ time: TimeInterval? = nil,
                         _ getData: @Sendable ()->Data?) async {

        let status = await peerState.status
        guard !status.isEmpty,
              let data = getData() else { return }

        if let tapeProto, status.taping {
            let item = TapeItem(type, data)
            await tapeProto.tapeItem(item)
        }
        if status.has(.send),
           connection.sendable.count > 0 {
            await connection.broadcastData(type,data)
        }  
    }

    public func playback(_ type: FramerType,
                         _ data: Data) {

        if let updateSet = connection.delegates[type] {
            for update in updateSet {
                update.received(data: data, from: .local)
                if type == .touchFrame {
                    Task {
                        await connection.broadcastData(type, data) //.....
                    }
                }
            }
        }
    }

    public func cleanupStaleConnections() {
        connection.cleanupStaleConnections()
    }

    public func setTape(on: Bool) async {
        guard tapeProto != nil else { return }
        var status = await peerState.status
        if on {
            status.insert(.taping)
        } else {
            status.subtract(.taping)
        }
        await peerState.set(status)
    }
}

