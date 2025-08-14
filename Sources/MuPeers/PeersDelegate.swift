import Foundation

public protocol PeersDelegate: AnyObject {
    func received(data: Data)
}

