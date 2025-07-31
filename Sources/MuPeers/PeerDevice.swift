// created by musesum on 5/23/25

import Foundation
import UIKit

@MainActor
public enum Idiom: @unchecked Sendable {
    case _iOS, _iPadOS, _macOS, _tvOS, _visionOS

    public static var idiom: Idiom {
#if os(visionOS)
        return ._visionOS
#elseif os(macOS)
        return ._macOS
#elseif os(iPadOS)
        return ._iPadOS
#elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? ._iPadOS : ._iOS
#elseif os(tvOS)
        return ._tvOS
#else
        return ._iOS
#endif
    }
    public static var iOS      : Bool { idiom == ._iOS      }
    public static var iPadOS   : Bool { idiom == ._iPadOS   }
    public static var macOS    : Bool { idiom == ._macOS    }
    public static var tvOS     : Bool { idiom == ._tvOS     }
    public static var visionOS : Bool { idiom == ._visionOS }

    static var name : String {
        switch idiom {
        case ._iOS       : return "iOS"
        case ._iPadOS    : return "iPadOS"
        case ._macOS     : return "macOS"
        case ._tvOS      : return "tvOS"
        case ._visionOS  : return "visionOS"
        }
    }

}

