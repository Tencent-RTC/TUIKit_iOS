//
//  HttpLogicRequest.swift
//  login
//
//  从 BusinessService 复制，仅保留登录模块需要的部分
//  （sdkAppId 管理 + IMLogicRequest）
//

import Alamofire
import Foundation
import ImSDK_Plus
import TUICore

private let sdkAppIdKey = "sdk_app_id_key"
private let userAvatarDomain = "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/"
private let userAvatarCount = 26

public class HttpLogicRequest {

    // set get 方法
    private static var _sdkAppId: Int32 = 0
    public private(set) static var sdkAppId: Int32 {
        set {
            _sdkAppId = newValue
        }
        get {
            if _sdkAppId > 0 {
                return _sdkAppId
            }
            let config = LoginEntry.shared.config
            if config.isSetupService {
                if let appid = UserDefaults.standard.object(forKey: sdkAppIdKey) as? String {
                    _sdkAppId = Int32(appid) ?? 0
                }
                return _sdkAppId
            } else {
                // GenerateTestUserSig
                return Int32(config.sdkAppId)
            }
        }
    }

    static func updateSdkAppId(sdkAppId: Int32) {
        HttpLogicRequest.sdkAppId = sdkAppId
        UserDefaults.standard.setValue(String(sdkAppId), forKey: sdkAppIdKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 清除内存中缓存的 sdkAppId
    ///
    /// 在 LoginEntry 切换配置（sdkAppId 变化）时调用，
    /// 确保下次读取 `sdkAppId` 时重新从 `LoginConfig` 或 UserDefaults 获取。
    static func resetSdkAppIdCache() {
        _sdkAppId = 0
    }
}

// MARK: - IM 请求相关方法
public class IMLogicRequest {
    /// IM 登录
    public static func imUserLogin(currentUserModel: BSUserModel?,
                                   success: ((_ data: BSUserModel?) -> Void)?,
                                   failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        guard let userModel = currentUserModel else {
            failed?(-1, LoginLocalize("login_error_login_failed"))
            return
        }
        userModel.apaasAppId = apaasAppId
        TUILogin.login(HttpLogicRequest.sdkAppId, userID: userModel.userId, userSig: userModel.userSig) {
            V2TIMManager.sharedInstance()?.getUsersInfo([userModel.userId], succ: { infos in
                if let info = infos?.first {
                    userModel.avatar = info.faceURL ?? ""
                    if !userModel.isMoa() {
                        userModel.name = info.nickName ?? ""
                    }
                    if let userID = info.userID {
                        userModel.userId = userID
                    }
                    LoginManager.shared.syncUserModelLocalData(userModel)
                    success?(userModel)
                    UserOverdueLogicManager.sharedManager().userOverdueState = .alreadyLogged
                } else {
                    failed?(-1, LoginLocalize("login_error_login_failed"))
                }
            }, fail: { code, errorDes in
                failed?(code, errorDes)
            })
        } fail: { code, errorDes in
            failed?(code, errorDes)
        }
    }

    /// IM 退出登录
    public static func imUserLogout(currentUserModel: BSUserModel?,
                                    success: ((_ data: BSUserModel?) -> Void)?,
                                    failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        TUILogin.logout {
            success?(currentUserModel)
        } fail: { code, errorDes in
            failed?(code, errorDes)
        }
    }

    /// IM 注销账户（清空 IM 资料后登出）
    public static func imUserDelete(currentUserModel: BSUserModel?,
                                    success: ((_ data: BSUserModel?) -> Void)?,
                                    failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let userInfo = V2TIMUserFullInfo()
        userInfo.nickName = ""
        userInfo.faceURL = ""
        V2TIMManager.sharedInstance()?.setSelfInfo(info: userInfo, succ: {
            debugPrint("set profile success")
            TUILogin.logout {
                success?(currentUserModel)
            } fail: { code, errorDes in
                failed?(code, errorDes)
            }
        }, fail: { code, errorDes in
            failed?(code, errorDes)
        })
    }

    /// IM 更新昵称
    public static func synchronizUserInfo(currentUserModel: BSUserModel,
                                          name: String, success: ((_ data: BSUserModel?) -> Void)?,
                                          failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let userInfo = V2TIMUserFullInfo()
        userInfo.nickName = name
        let randomAvatarIndex = Int.random(in: 1...userAvatarCount)
        var avatarURL = userAvatarDomain + "avatar_\(randomAvatarIndex).png"
        if currentUserModel.avatar.hasPrefix("http") {
            avatarURL = currentUserModel.avatar
        }
        userInfo.faceURL = avatarURL
        debugPrint("IMLogicRequest-synchronizUserInfo-\(avatarURL)")
        V2TIMManager.sharedInstance()?.setSelfInfo(info: userInfo, succ: {
            currentUserModel.name = name
            currentUserModel.avatar = avatarURL
            LoginManager.shared.syncUserModelLocalData(currentUserModel)
            success?(currentUserModel)
            debugPrint("set profile success")
        }, fail: { code, errorDes in
            failed?(code, errorDes)
        })
    }

    /// IM 更新头像
    public static func synchronizUserInfo(currentUserModel: BSUserModel,
                                          avatar: String,
                                          success: ((_ data: BSUserModel?) -> Void)?,
                                          failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let userInfo = V2TIMUserFullInfo()
        userInfo.nickName = currentUserModel.name
        userInfo.faceURL = avatar
        V2TIMManager.sharedInstance()?.setSelfInfo(info: userInfo, succ: {
            currentUserModel.avatar = avatar
            success?(currentUserModel)
            debugPrint("set profile success")
        }, fail: { code, errorDes in
            failed?(code, errorDes)
        })
    }
}
