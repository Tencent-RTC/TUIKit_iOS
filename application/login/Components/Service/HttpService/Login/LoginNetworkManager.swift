//
//  LoginNetworkManager.swift
//  login
//
//  从 BusinessService 复制，仅保留登录模块需要的网络请求方法
//

import UIKit
import TUICore

public class LoginNetworkManager: NSObject {

    /// 验证码登录（发送验证码）
    static func getSms(appId: String,
                       ticket: String, phone: String = "", email: String = "",
                       randstr: String = "", success: ((_ data: HttpJsonModel) -> Void)? = nil,
                       failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_verify_by_picture"
        if !phone.isEmpty {
            let params = ["appId": appId,
                          "ticket": ticket,
                          "phone": phone,
                          "randstr": randstr,
                          "apaasAppId": apaasAppId]
            NetworkManager.request(baseUrl: baseUrl, params: params, success: success, failed: failed)
        } else if !email.isEmpty {
            let params = ["appId": appId,
                          "ticket": ticket,
                          "email": email,
                          "randstr": randstr,
                          "apaasAppId": apaasAppId]
            NetworkManager.request(baseUrl: baseUrl, params: params, success: success, failed: failed)
        } else {
            failed?(-1, LoginLocalize("login_home_phone_or_email_empty"))
        }
    }

    static func getUserModuleBlackList(_ userID: String, success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                       failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let baseUrl = appLoginBaseUrl + "auth_users/module_blacklist"
        if !userID.isEmpty {
            let params = ["userId": userID]
            NetworkManager.request(baseUrl: baseUrl, params: params, success: success, failed: failed)
        } else {
            failed?(-1, LoginLocalize("login_home_user_id_empty"))
        }
    }

    /// 无验证登录
    public static func noneAuthLogin(withInvitationCode invitationCode: String?,
                                     success: ((_ data: BSUserModel?) -> Void)? = nil,
                                     failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let baseUrl = appLoginBaseUrl + "auth_users/none_auth"
        let params = ["inviteCode": invitationCode,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { model in
            if let sdkAppId = model.sdkAppId {
                HttpLogicRequest.updateSdkAppId(sdkAppId: sdkAppId)
                IMLogicRequest.imUserLogin(currentUserModel: model.currentUserModel, success: success, failed: failed)
            } else {
                failed?(-1, LoginLocalize("login_home_sys_error"))
            }
        }, failed: failed)
    }

    /// 手机验证码登录
    static func login(phone: String, sessionId: String,
                      code: String,
                      success: ((_ data: BSUserModel?) -> Void)?,
                      failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_login_code"
        let params = ["phone": phone,
                      "code": code,
                      "sessionId": sessionId,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { model in
            if let sdkAppId = model.sdkAppId {
                HttpLogicRequest.updateSdkAppId(sdkAppId: sdkAppId)
                IMLogicRequest.imUserLogin(currentUserModel: model.currentUserModel, success: success, failed: failed)
            } else {
                failed?(-1, LoginLocalize("login_home_sys_error"))
            }
        }, failed: failed)
    }

    /// 邮箱验证码登录
    static func login(email: String,
                      sessionId: String,
                      code: String,
                      success: ((_ data: BSUserModel?) -> Void)?,
                      failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_login_code"
        let params = ["email": email,
                      "code": code,
                      "sessionId": sessionId,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { model in
            if let sdkAppId = model.sdkAppId {
                HttpLogicRequest.updateSdkAppId(sdkAppId: sdkAppId)
                IMLogicRequest.imUserLogin(currentUserModel: model.currentUserModel, success: success, failed: failed)
            } else {
                failed?(-1, LoginLocalize("login_home_sys_error"))
            }
        }, failed: failed)
    }

    /// MOA 票据登录
    public static func loginByMOA(ticket: String,
                                  success: ((_ data: BSUserModel?) -> Void)?,
                                  failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_login_moa"
        let params: [String: Any] = [
            "key": ticket,
            "apaasAppId": apaasAppId,
            "tag": "trtc"
        ]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { model in
            if let sdkAppId = model.sdkAppId {
                HttpLogicRequest.updateSdkAppId(sdkAppId: sdkAppId)
                IMLogicRequest.imUserLogin(currentUserModel: model.currentUserModel, success: success, failed: failed)
            } else {
                failed?(-1, LoginLocalize("login_home_sys_error"))
            }
        }, failed: failed)
    }

    /// Token 登录
    static func loginByToken(userId: String,
                             token: String,
                             success: ((_ data: BSUserModel?) -> Void)?,
                             failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_login_token"
        let params = ["userId": userId,
                      "token": token,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { model in
            if let sdkAppId = model.sdkAppId {
                HttpLogicRequest.updateSdkAppId(sdkAppId: sdkAppId)
            }
            IMLogicRequest.imUserLogin(currentUserModel: model.currentUserModel, success: success, failed: failed)
        }, failed: failed)
    }

    /// 全局调度（获取 captcha appid）
    static func getImageCaptcha(success: ((_ data: HttpJsonModel) -> Void)?,
                                failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "gslb"
        NetworkManager.request(baseUrl: baseUrl, params: nil, success: success, failed: failed)
    }

    /// 心跳保活
    static func keepAlive(success: ((_ data: HttpJsonModel) -> Void)?,
                          failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_keepalive"
        NetworkManager.request(baseUrl: baseUrl, params: [:], success: success, failed: failed)
    }

    /// 注销登录
    static func logout(userId: String, token: String,
                       success: ((_ data: BSUserModel?) -> Void)?,
                       failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_logout"
        let params = ["userId": userId, "token": token]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { _ in
            IMLogicRequest.imUserLogout(currentUserModel: nil, success: success, failed: failed)
        }, failed: failed)
    }

    /// 注销账户（删除用户）
    static func deleteUser(userId: String, token: String,
                           success: ((_ data: BSUserModel?) -> Void)?,
                           failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_delete"
        let params = ["userId": userId, "token": token]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { _ in
            IMLogicRequest.imUserDelete(currentUserModel: nil, success: success, failed: failed)
        }, failed: failed)
    }

    /// 修改用户信息
    static func updateUser(currentUserModel: BSUserModel,
                           name: String, success: ((_ data: BSUserModel?) -> Void)?,
                           failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_update"
        let params = ["userId": currentUserModel.userId, "token": currentUserModel.token, "name": name]
        NetworkManager.request(baseUrl: baseUrl,
                               params: params,
                               success: { _ in
            IMLogicRequest.synchronizUserInfo(currentUserModel: currentUserModel,
                                              name: name, success: success,
                                              failed: failed)
        }, failed: failed)
    }

    /// 获取用户信息
    public static func userQueryUserId(param: [AnyHashable : Any]?,
                                       resultCallback: @escaping TUICallServiceResultCallback) -> Bool {
        let searchUserId = param?["searchUserId"]
        LoginNetworkManager.userQuery(searchUserId: searchUserId as! String, success: { data in
            let successResultParams = ["jsonModel": data]
            resultCallback(Int(data.errorCode), data.errorMessage, successResultParams)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode,
                                      "errorMessage": errMsg,]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
        return true
    }
    
    static func userQuery(searchUserId: String,
                          success: ((_ data: HttpJsonModel) -> Void)?,
                          failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_query"
        let params = ["searchUserId": searchUserId,]
        NetworkManager.request(baseUrl: baseUrl,
                               params: params,
                               success: success,
                               failed: failed)
    }

    /// 申请邀请码
    static func requestInvitationCode(_ email: String?,
                                      success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                      failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let applyInviteCodeApi = "auth_users/apply_invite_code"
        let requeURL = appLoginBaseUrl + applyInviteCodeApi
        let params = ["email": email,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: requeURL, params: params, success: success, failed: failed)
    }

    /// 营销邮件订阅
    static func requestEdmSendEmail(_ email: String,
                                    _ marketingStatus: Bool,
                                    success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                    failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let edmEmailApi = "auth_users/create_leave_user_send_email"
        let requestURL = appLoginBaseUrl + edmEmailApi
        let params = ["email": email,
                      "source": "tencent_rtc_app",
                      "marketingStatus": marketingStatus,
                      "scene": "product-trtc"] as [String: Any]
        NetworkManager.request(baseUrl: requestURL, params: params, success: success, failed: failed)
    }

    /// 心跳保活 (TUICore 适配)
    static func keepUserLoginAlive(param: [AnyHashable: Any]?,
                                   resultCallback: @escaping TUICallServiceResultCallback) -> Bool {
        LoginNetworkManager.keepAlive { data in
            let successResultParams = ["jsonModel": data]
            resultCallback(Int(data.errorCode), data.errorMessage, successResultParams)
        } failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode,
                                      "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        }
        return true
    }

    /// 处理登录失败码
    static func processLoginFailCode(code: Int32) {
        if (code == 203) || (code == 204) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }
}
