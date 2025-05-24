// created by musesum on 5/16/25

import Foundation
import Network

public extension Formatter {
    static let number = NumberFormatter()
}
public extension FloatingPoint {

    func digits(_ range: Int) -> String {

        if range == 0 {
            Formatter.number.maximumFractionDigits = 0
            Formatter.number.numberStyle = .decimal
            Formatter.number.roundingMode = .down  // Ensure truncation
            Formatter.number.usesGroupingSeparator = false
            let str = Formatter.number.string(for: self) ?? ""
            return str
        }
        let lower: Int
        let minus: Bool
        if range < 0 {
            lower = -range
            minus = true
        } else {
            lower = range
            minus = false
        }
        Formatter.number.roundingMode = NumberFormatter.RoundingMode.halfEven
        Formatter.number.minimumFractionDigits = lower
        Formatter.number.maximumFractionDigits = lower
        Formatter.number.usesGroupingSeparator = false
        let str = Formatter.number.string(for:  self) ?? ""
        return minus && self < 0 ? str : " " + str
    }
}
extension String {
    var endpointType: EndpointType {
        if self.prefix(1) == Peers.prefix {
            return .isPeerId
        } else if self.contains(":") {
            return .isIPv6
        } else if self.hasPrefix("192.") || self.hasPrefix("10.") || self.hasPrefix("172.") {
            return .isLocal
        } else {
            return .isPeerId
        }
    }
}
extension NWEndpoint {
    var endpointType: EndpointType {
        return self.debugDescription.endpointType
    }
    var isPeerId: Bool {
        return self.endpointType == .isPeerId
    }
    var isIPv6: Bool {
        return self.endpointType == .isIPv6
    }
    var peerId: String {
        switch self.endpointType {
        case .isIPv6: self.debugDescription.components(separatedBy:"%").first!
        case .isLocal: self.debugDescription
        case .isPeerId: String(self.debugDescription.prefix(9))
        default: self.debugDescription
        }
    }
}

// Simple Codable message
enum NetworkError: Error {
    case encodingError
    case decodingError
}

enum EndpointType {
    case isIPv6, isLocal, isPeerId, unknown
}

typealias PeerId = String
