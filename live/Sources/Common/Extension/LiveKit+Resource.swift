//
//  LiveBundle.swift
//  TUILiveKit
//
//  Created by CY zhao on 2026/1/12.
//

import Foundation
import AtomicX

public extension UIImage {
    static func liveBundleImage(_ named: String, rtlFlipped: Bool = false ) -> UIImage? {
        let image = UIImage(named: named, in: Bundle.liveBundle, with: nil) ?? UIImage(named: named)
        if rtlFlipped {
            return image?.rtlFlipped()
        } else {
            return image
        }
    }

    static var placeholderImage: UIImage {
        UIColor.lightPurpleColor.trans2Image()
    }

    static var avatarPlaceholderImage: UIImage? {
        UIImage(named: "live_seat_placeholder_avatar", in: Bundle.liveBundle, compatibleWith: nil)
    }

    func rtlFlipped() -> UIImage {
        return imageFlippedForRightToLeftLayoutDirection()
    }
}

public extension String {
    static func liveLocalized(_ key: String) -> String {
        return BundleLoader.moduleLocalized(key: key, in: Bundle.liveBundle, tableName: "TUILiveKitLocalized")
    }

    static func liveLocalizedReplace(_ key: String, replaces: CVarArg...) -> String {
        return BundleLoader.moduleLocalized(key: key, in: Bundle.liveBundle, tableName: "TUILiveKitLocalized", arguments: replaces)
    }
    
    //TODO: 要废弃 chengyu
    static func localizedReplace(_ origin: String, replace: String) -> String {
        return origin.replacingOccurrences(of: "xxx", with: replace)
    }
}

private class LiveBundleToken {}

public extension Bundle {
    static var liveBundle: Bundle {
        return BundleLoader.moduleBundle(named: "TUILiveKitBundle",
                                         moduleName: "TUILiveKit",
                                         for: LiveBundleToken.self) ?? .main
    }
}
