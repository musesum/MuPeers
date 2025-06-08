// created by musesum on 5/10/25

import Network
import SwiftUI


let PeersPrefix: String = "☯︎"

public struct PeersConfig {
    let service: String
    let secret: String
    
    public init(service: String,
                secret: String) {
        
        self.service = service
        self.secret = secret
    }
}

final public class Peers: Sendable {

    let browser: PeersBrowser
    let listener: PeersListener
    let connections: PeersConnection
    let peersLog: PeersLog
    
    public let peerId: String
    
    public init(_ config: PeersConfig) {

        peerId      = PeersPrefix + UInt64.random(in: 1...UInt64.max).base32
        peersLog    = PeersLog       (peerId)
        connections = PeersConnection(peerId, peersLog, config)
        listener    = PeersListener  (peerId, peersLog, config, connections)
        browser     = PeersBrowser   (peerId, peersLog, config, connections)
    }
    
    public func setDelegate(_ delegate: PeersDelegate,
                            for framerType: FramerType) {
        
        if connections.delegates[framerType] != nil {
            connections.delegates[framerType]?.append(delegate)
        } else {
            connections.delegates[framerType] = [delegate]
        }
    }
    
    public func removeDelegate(_ delegate: PeersDelegate) {
        for (key, var delegates) in connections.delegates {
            delegates.removeAll { $0 === delegate }
            connections.delegates[key] = delegates
        }
    }

    // make sure there is a connection before the expense of encoding the message
    public func sendItem(_ framerType: FramerType,
                         _ getData: @Sendable ()->Data?) async {
        if connections.sendable.count > 0,
           let data = getData() {
            await connections.broadcastData(framerType,data)
        }
        
    }
    
    public func cleanupStaleConnections() {
        connections.cleanupStaleConnections()
    }
}
