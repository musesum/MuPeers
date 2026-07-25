// created by musesum on 5/10/25

import Foundation
public protocol TapeProto: Sendable {
    func playItem(_ item: PlayItem) async
}

final public class Peers: @unchecked Sendable {
    
    public static let shared = Peers(
        PeersConfig(service: "_deepmuse-peer._tcp",secret: ""),
        logging: true)
    
    let browser    : PeersBrowser
    let listener   : PeersListener
    let connection : PeersConnection
    let peersLog   : PeersLog
    let peersConfig: PeersConfig
    var tapeProto  : TapeProto?

    public let peerId: String
    public private(set) var backend: PeersBackend
    let peerState = PeerState()   // internal for @testable flag assertions
    // serializes setup/cancel transitions so the LAST call wins — two unordered
    // Tasks (rapid toggle off→on) could otherwise end opposite the caller's intent
    var peersTask: Task<Void, Never>?   // internal so tests can await settlement

    // modern pair stored untyped — Peers floor is iOS 17, ModernListener is 26+
    private var modernListenerAny: Any?
    private var modernBrowserAny: Any?

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
    var modernListener: ModernListener? { modernListenerAny as? ModernListener }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *)
    var modernBrowser: ModernBrowser? { modernBrowserAny as? ModernBrowser }

    public init(_ config: PeersConfig,
                logging: Bool) {

        self.peerId     = PeersPrefix + UInt64.random(in: 1...UInt64.max).base32
        self.peersLog   = PeersLog       (peerId, logging)
        self.peersConfig = config
        self.backend    = Peers.resolveBackend(config.backend ?? PeersBackend.stored ?? .legacy, config, peersLog)
        self.connection = PeersConnection(peerId, peersLog, config)
        let startLegacy = backend == .legacy
        self.listener   = PeersListener  (peerId, peersLog, config, connection, startNow: startLegacy)
        self.browser    = PeersBrowser   (peerId, peersLog, config, connection, startNow: startLegacy)
        if backend == .modern {
            setupModernPair()
        }
        //must call setupPeers(tapeProto) to allow record, playback
    }

    /// requested → usable backend; modern needs OS 26 and an empty secret
    static func resolveBackend(_ requested: PeersBackend,
                               _ config: PeersConfig,
                               _ peersLog: PeersLog) -> PeersBackend {
        var resolved = requested.resolved
        if requested == .modern, resolved == .legacy {
            peersLog.log("⚠️ modern backend requires OS 26; using legacy")
        }
        if resolved == .modern, !config.secret.isEmpty {
            peersLog.log("⚠️ modern backend TLS secret not supported; using legacy")
            resolved = .legacy
        }
        return resolved
    }

    private func setupModernPair() {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            if modernListenerAny == nil {
                modernListenerAny = ModernListener(peerId, peersLog, peersConfig, connection)
                modernBrowserAny  = ModernBrowser (peerId, peersLog, peersConfig, connection)
            }
            modernListener?.setupListener()
            modernBrowser?.setupBrowser()
        }
    }
    private func setupTransport() {
        if backend == .modern {
            setupModernPair()
        } else {
            listener.setupListener()
            browser.setupBrowser()
        }
    }
    private func cancelTransport() {
        listener.cancelListener()
        browser.cancelBrowser()
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            modernListener?.cancelListener()
            modernBrowser?.cancelBrowser()
        }
    }

    /// runtime switch between transport backends; serialized like setup/cancel
    /// so a rapid toggle still ends on the last call
    @MainActor
    public func setBackend(_ requested: PeersBackend) {
        UserDefaults.standard.set(requested.rawValue, forKey: PeersBackend.defaultsKey)
        let previous = peersTask
        peersTask = Task {
            await previous?.value
            let resolved = Peers.resolveBackend(requested, peersConfig, peersLog)
            guard resolved != backend else { return }
            let active = await peerState.hasAny([.send, .receive])
            if active {
                cancelTransport()
                connection.disconnectAll()
            }
            backend = resolved
            if active {
                setupTransport()
            }
        }
    }
    // @MainActor: NW callbacks run on .main; off-main setup/cancel would race the
    // `=== self.listener/browser` staleness guards in those callbacks, and the
    // peersTask swap needs one executor for last-call-wins ordering. The inner
    // Tasks inherit MainActor isolation, so the lifecycle calls stay on .main.
    @MainActor
    public func setupPeers(_ tapeProto: TapeProto) {
        self.tapeProto = tapeProto

        let previous = peersTask
        peersTask = Task {
            await previous?.value
            if await !peerState.has([.send, .receive]) {
                // restore send/receive after a cancelPeers, else sendItem stays dead
                await peerState.insert([.send, .receive])
                setupTransport()
            }
        }
    }
    @MainActor
    public func cancelPeers() {
        let previous = peersTask
        peersTask = Task {
            await previous?.value
            if await peerState.hasAny([.send, .receive]) {
                await peerState.subtract([.send, .receive])
                cancelTransport()
                connection.disconnectAll()
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
                         path: String = "",
                         _ getData: @Sendable ()->Data?) async {

        let status = await peerState.status
        guard !status.isEmpty,
              let data = getData() else { return }

        // maybe record this item
        if let tapeProto, status.taping {
            let item = PlayItem(type, data, path: path)
            await tapeProto.playItem(item)
        }
        if status.has(.send),
           connection.sendable.count > 0 {
            await connection.broadcastData(type,data)
        }  
    }
    
    public func playItem(_ playState: PlayState,
                         _ item: PlayItem,
                         _ from: DataFrom) {
        
        if let updateSet = connection.delegates[item.type] {
            for update in updateSet {

                update.playItem(item, from: from)

                // Check if not remote
                var isRemote = false
                if case .remote = from { isRemote = true }

                if !isRemote, !playState.play {
                    Task { await connection.broadcastData(item.type, item.data) }
                }
            }
        } else {
            peersLog.log("⚠️ playItem dropped: no delegate for \(item.type.description)")
        }
    }
    public func resetPlayItems(_ playItems: [PlayItem]) {
        for playItem in playItems {
            if let updateSet = connection.delegates[playItem.type] {
                for update in updateSet {
                    update.resetItem(playItem)
                }
            }
        }
    }
    
    public func cleanupStaleConnections() {
        connection.cleanupStaleConnections()
    }
    
    public func setTape(on: Bool) async {
        guard tapeProto != nil else { return }
        if on {
            await peerState.insert(.taping)
        } else {
            await peerState.subtract(.taping)
        }
    }
}
