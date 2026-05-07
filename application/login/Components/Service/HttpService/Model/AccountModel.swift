//
//  AccountModel.swift
//  login
//

import UIKit

@objcMembers
public class ResignModel: NSObject, Codable {
    var codeStr: String? = ""
    var errorMessage: String = ""
    var errorCode: Int32 = -1
}

@objcMembers
public class LoginModel: NSObject, Codable {
    var errorCode: Int = -1
    var errorMessage: String = ""
    var data: BSUserModel? = nil
}

@objcMembers
public class BSUserModel: NSObject, Codable {
    public var token: String
    public var phone: String
    public var email: String
    public var name: String
    public var avatar: String
    public var userId: String
    public var appId: String
    public var userSig: String = ""
    public var apaasAppId: String = ""
    public var apaasUserId: String = ""
    public var sdkUserSig: String = ""
    public var isHighRiskUser: Bool = false
    public var isHighRiskIp: Bool = false
    public var bannedModules: [String: Bool] = [:]
    public var bannedFeatures: [String: Bool] = [:]
    public var loginType: String

    enum CodingKeys: String, CodingKey {
        case token
        case phone
        case email
        case name
        case avatar
        case userId
        case userSig
        case apaasAppId
        case apaasUserId
        case sdkUserSig
        case loginType
        case appId
    }

    public init(token: String, phone: String, email: String, name: String, avatar: String, userId: String,
                appId: String, userSig: String, apaasAppId: String, apaasUserId: String, sdkUserSig: String,
                isHighRiskUser: Bool = false, isHighRiskIp: Bool = false, loginType: String = "") {
        self.token = token
        self.phone = phone
        self.email = email
        self.name = name
        self.avatar = avatar
        self.userId = userId
        self.appId = appId
        self.userSig = userSig
        self.apaasAppId = apaasAppId
        self.apaasUserId = apaasUserId
        self.sdkUserSig = sdkUserSig
        self.isHighRiskUser = isHighRiskUser
        self.isHighRiskIp = isHighRiskIp
        self.loginType = loginType
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        phone = (try? container.decode(String.self, forKey: .phone)) ?? ""
        email = (try? container.decode(String.self, forKey: .email)) ?? ""
        token = (try? container.decode(String.self, forKey: .token)) ?? ""
        avatar = (try? container.decode(String.self, forKey: .avatar)) ?? ""
        userId = (try? container.decode(String.self, forKey: .userId)) ?? ""
        appId = (try? container.decode(String.self, forKey: .appId)) ?? ""
        userSig = (try? container.decode(String.self, forKey: .userSig)) ?? ""
        apaasAppId = (try? container.decode(String.self, forKey: .apaasAppId)) ?? ""
        apaasUserId = (try? container.decode(String.self, forKey: .apaasUserId)) ?? ""
        sdkUserSig = (try? container.decode(String.self, forKey: .sdkUserSig)) ?? ""
        loginType = (try? container.decode(String.self, forKey: .loginType)) ?? ""
    }

    public func isMoa() -> Bool {
        return loginType == "moa"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phone, forKey: .phone)
        try container.encode(email, forKey: .email)
        try container.encode(token, forKey: .token)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(userId, forKey: .userId)
        try container.encode(appId, forKey: .appId)
        try container.encode(userSig, forKey: .userSig)
        try container.encode(apaasAppId, forKey: .apaasAppId)
        try container.encode(apaasUserId, forKey: .apaasUserId)
        try container.encode(sdkUserSig, forKey: .sdkUserSig)
        try container.encode(loginType, forKey: .loginType)
    }
}
