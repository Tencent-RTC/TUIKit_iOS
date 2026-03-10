//
//  ResourceLoader.swift
//  TUIRoomKit
//
//  Created on 2025/11/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import Foundation
import AtomicX

private class RoomBundleToken {}

@objc public class ResourceLoader: NSObject {
    
    // MARK: - Properties
    @objc public static let bundle: Bundle = {        
        BundleLoader.moduleBundle(named: "TUIRoomKitBundle", moduleName: "TUIRoomKit", for: RoomBundleToken.self) ?? Bundle.main
    }()
    
    // MARK: - Image Loading
    @objc public static func loadImage(_ name: String) -> UIImage? {
        return UIImage(named: name, in: bundle, compatibleWith: nil)
    }
    
    @objc public static func loadAssetImage(_ name: String) -> UIImage? {
        if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
            return image
        }
        return UIImage(named: name)
    }
    
}
