//
//  PrivacyConfig.swift
//  privacy
//

import UIKit
import TUICore

// MARK: - PrivacyConfig

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
    
    var personalAuth: [String: Any]? {
        return plistInfo[Self.personalAuthKey] as? [String: Any]
    }
    
    var dataCollectionList: [[String: Any]] {
        return (plistInfo[Self.dataCollectionKey] as? [[String: Any]]) ?? []
    }
    
    var thirdShareList: [[String: Any]] {
        return (plistInfo[Self.thirdShareKey] as? [[String: Any]]) ?? []
    }
    
    var authList: [String] {
        return (personalAuth?["auth"] as? [String]) ?? []
    }
    
    var infoList: [String] {
        return (personalAuth?["info"] as? [String]) ?? []
    }
    
    // MARK: - Convenience Init with Current User
    
    static func makeWithCurrentUser() -> PrivacyConfig {
        let config = PrivacyConfig()
        config.userName = TUILogin.getNickName() ?? ""
        config.userID = TUILogin.getUserID() ?? ""
        config.userAvatar = TUILogin.getFaceUrl() ?? ""
        return config
    }
}
