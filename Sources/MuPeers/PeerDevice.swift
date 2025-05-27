// created by musesum on 5/23/25

import Foundation
import UIKit

struct PeerDevice {

#if os(visionOS)
    static let name = "VisionOS"
#elseif os(macOS)
    static let name = "MacOS"
#elseif os(iPadOS)
    static let name = "iPadOS"
#elseif os(iOS)
    static let name = "iOS"
#elseif os(tvOS)
    static let name = "tvOS"
#else
    static let name = "unknown device"
#endif
}
