//
//  TUIRoomKitLocalized.swift
//  TUIRoomKit
//
//  Created on 2025/11/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import Foundation

/// 本地化字符串管理类
@objc public class TUIRoomKitLocalized: NSObject {
    
    // MARK: - Localization Methods
    
    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化键值
    ///   - defaultValue: 默认值
    /// - Returns: 本地化后的字符串
    @objc public static func localizedString(_ key: String) -> String {
        return NSLocalizedString(key, tableName: "TUIRoomKitLocalized", bundle: ResourceLoader.bundle, comment: "")
    }
}

// MARK: - String Extension for Localization

extension String {
    
    /// 获取本地化字符串
    /// 使用方式: "key".localized
    var localized: String {
        return TUIRoomKitLocalized.localizedString(self)
    }
    
    /// 获取带参数替换的本地化字符串
    /// - Parameter replace: 需要替换 "xxx" 的字符串
    /// - Returns: 本地化并替换后的字符串
    /// 使用方式: "Transfer the host to xxx".localizedReplace("Alice")
    func localizedReplace(_ replace_xxx: String) -> String {
        return localized.replacingOccurrences(of: "xxx", with: replace_xxx)
    }

    /// 获取带参数替换的本地化字符串
    /// - Parameter replace: 需要替换 "xxx" , "yyy" 的字符串
    /// - Returns: 本地化并替换后的字符串
    /// 使用方式: "Transfer the host to xxx, yyy".localizedReplace("Alice", "Bob")
    func localizedReplace(_ replace_xxx: String, _ replace_yyy: String) -> String {
        return localizedReplace(replace_xxx).replacingOccurrences(of: "yyy", with: replace_yyy)
    }
}
