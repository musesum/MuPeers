import Foundation

public protocol PeersDelegate: AnyObject, Sendable {

    func received(data: Data)
}
