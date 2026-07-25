// created by musesum on 7/25/26

import Foundation

/// runtime-switchable transport backend
public enum PeersBackend: String, Codable, Sendable {
    case legacy  // NWListener / NWBrowser / NWConnection
    case modern  // NetworkListener / NetworkBrowser / NetworkConnection (OS 26+)

    /// UserDefaults override enables switching without recompile
    public static let defaultsKey = "MuPeersBackend"

    public static var modernAvailable: Bool {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            return true
        }
        return false
    }

    /// requested → usable backend; modern downgrades to legacy pre-26
    public var resolved: PeersBackend {
        self == .modern && !Self.modernAvailable ? .legacy : self
    }

    public static var stored: PeersBackend? {
        UserDefaults.standard.string(forKey: defaultsKey)
            .flatMap(PeersBackend.init(rawValue:))
    }
}
