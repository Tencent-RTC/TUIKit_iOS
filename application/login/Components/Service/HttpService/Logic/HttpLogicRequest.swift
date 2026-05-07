//
//  HttpLogicRequest.swift
//  login
//

import Alamofire
import Foundation
import ImSDK_Plus
import TUICore

private let sdkAppIdKey = "sdk_app_id_key"
private let userAvatarDomain = "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/"
private let userAvatarCount = 26

public class HttpLogicRequest {

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
    
    static func resetSdkAppIdCache() {
        _sdkAppId = 0
    }
}

public class IMLogicRequest {
    public static func imUserLogin(currentUserModel: BSUserModel?,
                                   success: ((_ data: BSUserModel?) -> Void)?,
                                   failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        guard let userModel = currentUserModel else {
            failed?(-1, LoginLocalize("LoginNetwork.ProfileManager.loginfailed"))
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
                    failed?(-1, LoginLocalize("LoginNetwork.ProfileManager.loginfailed"))
                }
            }, fail: { code, errorDes in
                failed?(code, errorDes)
            })
        } fail: { code, errorDes in
            failed?(code, errorDes)
        }
    }

    public static func imUserLogout(currentUserModel: BSUserModel?,
                                    success: ((_ data: BSUserModel?) -> Void)?,
                                    failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        TUILogin.logout {
            success?(currentUserModel)
        } fail: { code, errorDes in
            failed?(code, errorDes)
        }
    }

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
