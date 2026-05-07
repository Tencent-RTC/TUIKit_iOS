//
//  HttpJsonModel.swift
//  login
//

import Foundation
import TUICore

public class HttpJsonModel: NSObject {
    public var errorCode: Int32 = -1
    public var errorMessage: String = ""
    public var data: Any?

    public static func json(_ json: [String: Any]) -> HttpJsonModel? {
        guard let errorCode = json["errorCode"] as? Int32 else {
            return nil
        }
        guard let errorMessage = json["errorMessage"] as? String else {
            return nil
        }

        let info = HttpJsonModel()
        info.errorCode = errorCode
        if errorCode == kAppLoginServiceStopCode, let notice = json["notice"] as? [String: String] {
            info.errorMessage = (TUIGlobalization.isChineseAppLocale() ? notice["zh"] : notice["en"]) ?? errorMessage
        } else {
            info.errorMessage = errorMessage
        }
        info.data = json["data"] as Any
        return info
    }

    public lazy var captchaWebAppid: NSInteger? = {
        guard let result = data as? [String: Any] else { return nil }
        return result["captcha_web_appid"] as? NSInteger
    }()

    public lazy var sessionID: String? = {
        guard let result = data as? [String: Any] else { return nil }
        return result["sessionId"] as? String
    }()

    public lazy var sdkAppId: Int32? = {
        guard let result = data as? [String: Any] else { return nil }
        return result["sdkAppId"] as? Int32
    }()

    public lazy var currentUserModel: BSUserModel? = {
        guard let result = data as? [String: Any] else { return nil }
        return getUserModel(result)
    }()

    public lazy var users: [BSUserModel] = {
        var usersResult: [BSUserModel] = []
        guard let result = data as? [[String: Any]] else { return usersResult }
        for dict in result {
            if let userModel = getUserModel(dict) {
                usersResult.append(userModel)
            }
        }
        return usersResult
    }()

    public lazy var searchUserModel: BSUserModel? = {
        guard let result = data as? [String: Any] else { return nil }
        return getSearchUserModel(result)
    }()

    // MARK: - Private

    private func getUserModel(_ result: [String: Any]) -> BSUserModel? {
        guard let userId = result["userId"] as? String else { return nil }
        guard let userSig = result["userSig"] as? String else { return nil }
        guard let token = result["token"] as? String else { return nil }

        let phone = (result["phone"] as? String) ?? ""
        let email = (result["email"] as? String) ?? ""
        let name = (result["name"] as? String) ?? ""
        let avatar = (result["avatar"] as? String) ?? defaultAvatar()
        let appId = (result["apaasAppId"] as? String) ?? ""
        let apaasUserId = (result["apaasUserId"] as? String) ?? ""
        let sdkUserSig = (result["sdkUserSig"] as? String) ?? ""
        let isHighRiskUser = (result["isHighRiskUser"] as? Bool) ?? false
        let isHighRiskIp = (result["isHighRiskIp"] as? Bool) ?? false
        let loginType = (result["loginType"] as? String) ?? ""
        return BSUserModel(token: token,
                           phone: phone,
                           email: email,
                           name: name,
                           avatar: avatar,
                           userId: userId,
                           appId: appId,
                           userSig: userSig,
                           apaasAppId: apaasAppId,
                           apaasUserId: apaasUserId,
                           sdkUserSig: sdkUserSig,
                           isHighRiskUser: isHighRiskUser,
                           isHighRiskIp: isHighRiskIp,
                           loginType: loginType)
    }

    private func getSearchUserModel(_ result: [String: Any]) -> BSUserModel? {
        guard let name = result["name"] as? String else { return nil }
        guard let avatar = result["avatar"] as? String else { return nil }
        guard let userId = result["userId"] as? String else { return nil }
        let phone = (result["phone"] as? String) ?? ""
        let email = (result["email"] as? String) ?? ""
        let appId = (result["appId"] as? String) ?? ""
        let userSig = (result["userSig"] as? String) ?? ""
        let token = (result["token"] as? String) ?? ""
        let apaasAppId = (result["apaasAppId"] as? String) ?? ""
        let apaasUserId = (result["apaasUserId"] as? String) ?? ""
        let sdkUserSig = (result["sdkUserSig"] as? String) ?? ""
        let isHighRiskUser = (result["isHighRiskUser"] as? Bool) ?? false
        let isHighRiskIp = (result["isHighRiskIp"] as? Bool) ?? false
        let loginType = (result["loginType"] as? String) ?? ""
        return BSUserModel(token: token, phone: phone, email: email, name: name, avatar: avatar, userId: userId, appId: appId,
                           userSig: userSig, apaasAppId: apaasAppId, apaasUserId: apaasUserId, sdkUserSig: sdkUserSig,
                           isHighRiskUser: isHighRiskUser, isHighRiskIp: isHighRiskIp, loginType: loginType)
    }

    private func defaultAvatar() -> String {
        return "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/voice_room/voice_room_cover1.png"
    }
}
