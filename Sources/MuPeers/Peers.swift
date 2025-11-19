// created by musesum on 5/10/25

import Network
import SwiftUI

public protocol MirrorSink: Sendable {
    func reflect(_ framerType: FramerType,
                 _ data: Data) async
}

final public class Peers: Sendable {

    let browser: PeersBrowser
    let listener: PeersListener
    let connection: PeersConnection
    let peersLog: PeersLog
    let mirror: MirrorSink?

    public let peerId: String
    private let peerState = PeerState()

    public init(_ config: PeersConfig,
                mirror: MirrorSink?,
                logging: Bool) {

        self.peerId     = PeersPrefix + UInt64.random(in: 1...UInt64.max).base32
        self.peersLog   = PeersLog       (peerId, logging)
        self.connection = PeersConnection(peerId, peersLog, config)
        self.listener   = PeersListener  (peerId, peersLog, config, connection)
        self.browser    = PeersBrowser   (peerId, peersLog, config, connection)
        self.mirror     = mirror
    }
    public func setupPeers() {
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
    public func sendItem(_ framerType: FramerType,
                         _ getData: @Sendable ()->Data?) async {

        let status = await peerState.status
        guard !status.isEmpty,
              let data = getData() else { return }

        if let mirror, status.mirror {
            await mirror.reflect(framerType, data)
        }
        if status.has(.send),
           connection.sendable.count > 0 {
            await connection.broadcastData(framerType,data)
        }  
    }
    
    public func cleanupStaleConnections() {
        connection.cleanupStaleConnections()
    }

    public func setMirror(on: Bool) async {
        guard mirror != nil else { return }
        var status = await peerState.status
        if on {
            status.insert(.mirror)
        } else {
            status.subtract(.mirror)
        }
        await peerState.set(status)
    }
}
