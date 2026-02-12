import Foundation

public enum DataFrom: String, Sendable, Codable {
    case remote
    case local
    case loop

    public var icon: String {
        switch self {
        case .remote: return "📡 remote"
        case .local: return "🏠 local"
        case .loop: return "➰ loop"
        }
    }
}

public protocol PeersDelegate: AnyObject {
    func received(data: Data, from: DataFrom)
    func shareItem(_ : Any)
    func resetItem(_ : PlayItem)
    func playItem(_ : PlayItem, from: DataFrom)
}

