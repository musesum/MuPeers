import Foundation

public enum DataFrom: Sendable, Codable, Equatable {
    case remote(String)
    case local
    case loop

    public var icon: String {
        switch self {
        case .remote: return "📡"
        case .local: return "🏠"
        case .loop: return "➰"
        }
    }
}

public protocol PeersDelegate: AnyObject {
    func received(data: Data, from: DataFrom)
    func shareItem(_ : Any)
    func resetItem(_ : PlayItem)
    func playItem(_ : PlayItem, from: DataFrom)
    func dropped(from: DataFrom)
}
