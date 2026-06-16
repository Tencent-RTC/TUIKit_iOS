//
//  HttpJsonModel.swift
//  login
//
//  从 BusinessService 复制，仅保留登录模块需要的部分
//  （去除了 Karaoke、Room、ShowLive 等不相关的解析逻辑）
//

import Foundation
import TUICore

/// HTTP 响应拦截模型
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

    // MARK: - 懒加载业务解析

    /// 全局调度 — captcha web appid
    public lazy var captchaWebAppid: NSInteger? = {
        guard let result = data as? [String: Any] else { return nil }
        return result["captcha_web_appid"] as? NSInteger
    }()

    /// 获取验证码 sessionId
    public lazy var sessionID: String? = {
        guard let result = data as? [String: Any] else { return nil }
        return result["sessionId"] as? String
    }()

    /// 获取登录返回的 sdkAppId
    public lazy var sdkAppId: Int32? = {
        guard let result = data as? [String: Any] else { return nil }
        return result["sdkAppId"] as? Int32
    }()

    /// 获取 UserModel
    public lazy var currentUserModel: BSUserModel? = {
        guard let result = data as? [String: Any] else { return nil }
        return getUserModel(result)
    }()

    /// 获取用户列表
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

    /// 获取搜索用户
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
