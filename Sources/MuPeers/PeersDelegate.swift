import Foundation

public enum DataFrom: String, Sendable {
    case remote
    case local
    case loop
}

public protocol PeersDelegate: AnyObject {
    func received(data: Data, from: DataFrom)
}

