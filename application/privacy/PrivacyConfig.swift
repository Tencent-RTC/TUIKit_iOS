//
//  PrivacyConfig.swift
//  privacy
//
//  隐私配置 — 读取 Privacy.plist 全部字段
//  对标 v1 LiteAVPrivacyConfig
//

import UIKit
import TUICore

// MARK: - PrivacyConfig

/// 隐私模块配置
final class PrivacyConfig {
    
    // MARK: - Plist Keys
    
    static let privacySummaryURLKey  = "privacySummaryURL"
    static let privacyURLKey         = "privacyURL"
    static let serviceURLKey         = "serviceURL"
    static let userProtocolURLKey    = "userProtocolURL"
    static let dataCollectionURLKey  = "dataCollectionURL"
    static let thirdShareURLKey      = "thirdShareURL"
    static let versionKey            = "version"
    static let personalAuthKey       = "personalAuth"
    static let dataCollectionKey     = "dataCollection"
    static let thirdShareKey         = "thirdShare"
    
    // MARK: - User Info
    
    var userName: String = ""
    var userID: String = ""
    var userAvatar: String = ""
    var phone: String = ""
    var email: String = ""
    
    // MARK: - Plist Data
    
    private(set) lazy var plistInfo: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Privacy", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return [:]
        }
        return dict
    }()
    
    // MARK: - URL Accessors
    
    var privacySummaryURL: String {
        return (plistInfo[Self.privacySummaryURLKey] as? String) ?? ""
    }
    
    var privacyURL: String {
        return (plistInfo[Self.privacyURLKey] as? String) ?? ""
    }
    
    var serviceURL: String {
        return (plistInfo[Self.serviceURLKey] as? String) ?? ""
    }
    
    var agreementURL: String {
        return (plistInfo[Self.userProtocolURLKey] as? String) ?? ""
    }
    
    var dataCollectionURL: String {
        return (plistInfo[Self.dataCollectionURLKey] as? String) ?? ""
    }
    
    var thirdShareURL: String {
        return (plistInfo[Self.thirdShareURLKey] as? String) ?? ""
    }
    
    // MARK: - Structured Data
    
    /// 个人信息与权限配置
    var personalAuth: [String: Any]? {
        return plistInfo[Self.personalAuthKey] as? [String: Any]
    }
    
    /// 个人信息收集清单
    var dataCollectionList: [[String: Any]] {
        return (plistInfo[Self.dataCollectionKey] as? [[String: Any]]) ?? []
    }
    
    /// 第三方信息共享清单
    var thirdShareList: [[String: Any]] {
        return (plistInfo[Self.thirdShareKey] as? [[String: Any]]) ?? []
    }
    
    /// 系统权限列表 (camera, microphone, photos, apns, beauty)
    var authList: [String] {
        return (personalAuth?["auth"] as? [String]) ?? []
    }
    
    /// 个人信息列表 (avatar, name, id, phone, email)
    var infoList: [String] {
        return (personalAuth?["info"] as? [String]) ?? []
    }
    
    // MARK: - Convenience Init with Current User
    
    /// 使用当前登录用户信息初始化
    static func makeWithCurrentUser() -> PrivacyConfig {
        let config = PrivacyConfig()
        config.userName = TUILogin.getNickName() ?? ""
        config.userID = TUILogin.getUserID() ?? ""
        config.userAvatar = TUILogin.getFaceUrl() ?? ""
        return config
    }
}
