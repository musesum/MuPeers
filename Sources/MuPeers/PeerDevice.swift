// created by musesum on 5/23/25

import Foundation
import UIKit

public enum Idiom: @unchecked Sendable {
    case iOS, iPadOS, macOS, tvOS, visionOS

    @MainActor static var idiom: Idiom {
#if os(visionOS)
        return .visionOS
#elseif os(macOS)
        return .macOS
#elseif os(iPadOS)
        return .iPadOS
#elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPadOS : .iOS
#elseif os(tvOS)
        return .tvOS
#else
        return .iOS
#endif
    }
    var name : String {
        switch self {
        case .iOS       : return "iOS"
        case .iPadOS    : return "iPadOS"
        case .macOS     : return "macOS"
        case .tvOS      : return "tvOS"
        case .visionOS  : return "visionOS"
        }
    }

}

