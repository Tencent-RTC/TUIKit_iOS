//
//  LoginNetworkManager.swift
//  login
//

import UIKit
import TUICore

public class LoginNetworkManager: NSObject {

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
            failed?(-1, LoginLocalize("Demo.TRTC.Home.phoneoremailIsEmpty"))
        }
    }

    static func getUserModuleBlackList(_ userID: String, success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                       failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let baseUrl = appLoginBaseUrl + "auth_users/module_blacklist"
        if !userID.isEmpty {
            let params = ["userId": userID]
            NetworkManager.request(baseUrl: baseUrl, params: params, success: success, failed: failed)
        } else {
            failed?(-1, LoginLocalize("Demo.TRTC.Home.userIDIsEmpty"))
        }
    }

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
                failed?(-1, LoginLocalize("Demo.TRTC.http.syserror"))
            }
        }, failed: failed)
    }

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
                failed?(-1, LoginLocalize("Demo.TRTC.http.syserror"))
            }
        }, failed: failed)
    }

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
                failed?(-1, LoginLocalize("Demo.TRTC.http.syserror"))
            }
        }, failed: failed)
    }

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
                failed?(-1, LoginLocalize("Demo.TRTC.http.syserror"))
            }
        }, failed: failed)
    }

    static func loginByToken(userId: String,
                             token: String,
                             success: ((_ data: BSUserModel?) -> Void)?,
                             failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_login_token"
        let params = ["userId": userId,
                      "token": token,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { model in
            IMLogicRequest.imUserLogin(currentUserModel: model.currentUserModel, success: success, failed: failed)
        }, failed: failed)
    }

    static func getImageCaptcha(success: ((_ data: HttpJsonModel) -> Void)?,
                                failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "gslb"
        NetworkManager.request(baseUrl: baseUrl, params: nil, success: success, failed: failed)
    }

    static func keepAlive(success: ((_ data: HttpJsonModel) -> Void)?,
                          failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_keepalive"
        NetworkManager.request(baseUrl: baseUrl, params: [:], success: success, failed: failed)
    }

    static func logout(userId: String, token: String,
                       success: ((_ data: BSUserModel?) -> Void)?,
                       failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_logout"
        let params = ["userId": userId, "token": token]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { _ in
            IMLogicRequest.imUserLogout(currentUserModel: nil, success: success, failed: failed)
        }, failed: failed)
    }

    static func deleteUser(userId: String, token: String,
                           success: ((_ data: BSUserModel?) -> Void)?,
                           failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        let baseUrl = appLoginBaseUrl + "auth_users/user_delete"
        let params = ["userId": userId, "token": token]
        NetworkManager.request(baseUrl: baseUrl, params: params, success: { _ in
            IMLogicRequest.imUserDelete(currentUserModel: nil, success: success, failed: failed)
        }, failed: failed)
    }

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

    static func requestInvitationCode(_ email: String?,
                                      success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                      failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        let applyInviteCodeApi = "auth_users/apply_invite_code"
        let requeURL = appLoginBaseUrl + applyInviteCodeApi
        let params = ["email": email,
                      "apaasAppId": apaasAppId]
        NetworkManager.request(baseUrl: requeURL, params: params, success: success, failed: failed)
    }

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

    static func processLoginFailCode(code: Int32) {
        if (code == 203) || (code == 204) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }
}
