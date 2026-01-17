//
//  ResourceLoader.swift
//  TUIRoomKit
//
//  Created on 2025/11/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import Foundation
import UIKit

@objc public class ResourceLoader: NSObject {
    
    // MARK: - Properties
    @objc public static let bundle: Bundle = {
        if let bundlePath = Bundle.main.path(forResource: "TUIRoomKitBundle", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath) {
            return bundle
        }
        
        let currentBundle = Bundle(for: ResourceLoader.self)
        if let bundlePath = currentBundle.path(forResource: "TUIRoomKitBundle", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath) {
            return bundle
        }
        
        if let resourcePath = currentBundle.resourcePath,
           let bundle = Bundle(path: resourcePath) {
            return bundle
        }

        return Bundle.main
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
