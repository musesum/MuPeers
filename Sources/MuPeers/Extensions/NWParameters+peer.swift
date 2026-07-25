
import Network

extension NWParameters {

	/// Apply the peer-to-peer + LAN-only routing constraints.
	///
	/// On watchOS (and any device with an active VPN), the kernel will pick
	/// up `ipsec1` as the only routable path for local Bonjour-resolved peers
	/// and NECP then denies the route ("Path was denied by NECP policy"),
	/// surfacing as `POSIXErrorCode 50: Network is down`.
	///
	/// To force Wi-Fi peer-to-peer (AWDL) instead:
	///   1. `includePeerToPeer = true` — enables AWDL transport.
	///   2. `prohibitedInterfaceTypes = [.other, .cellular]` — excludes VPN
	///      tunnels (which arrive as `.other`) and cellular fallback.
	///   3. Print the chosen interface at first call so a fresh build is
	///      visually distinguishable from a stale install.
	static func applyPeerToPeerConstraints(_ p: NWParameters) {
		p.includePeerToPeer = true
		p.prohibitedInterfaceTypes = [.other, .cellular]
		#if DEBUG
		Self.logPeerToPeerOnce()
		#endif
	}

	#if DEBUG
	nonisolated(unsafe) private static var didLogPeerToPeer = false
	private static func logPeerToPeerOnce() {
		guard !didLogPeerToPeer else { return }
		didLogPeerToPeer = true
		print("📡 MuPeers NWParameters: peerToPeer=true, prohibit=[.other,.cellular]")
	}
	#endif
}
