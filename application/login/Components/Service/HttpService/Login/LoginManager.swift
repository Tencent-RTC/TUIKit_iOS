//
//  LoginManager.swift
//  login
//

import Alamofire
import ImSDK_Plus
import UIKit
import TUICore

@objcMembers
public class LoginManager: NSObject {
    private var keepaliveTimer: DispatchSourceTimer?
    override private init() {}
    public static let shared: LoginManager = LoginManager()
    public internal(set) var currentUser: BSUserModel?

    public func getCurrentUser() -> BSUserModel? {
        if currentUser == nil {
            if let cacheData = UserDefaults.standard.object(forKey: PER_USER_MODEL_KEY) as? Data {
                do {
                    currentUser = try JSONDecoder().decode(BSUserModel.self, from: cacheData)
                } catch {
                    return nil
                }
            }
        }
        return currentUser
    }

    public func syncUserModelLocalData(_ userModel: BSUserModel) {
        do {
            let cacheData = try JSONEncoder().encode(userModel)
            UserDefaults.standard.set(cacheData, forKey: PER_USER_MODEL_KEY)
            UserDefaults.standard.synchronize()
        } catch {
            print("Save Failed")
        }
    }

    // Dispatch Timer
    public func keepAlive() {
        guard keepaliveTimer == nil else { return }
        keepaliveTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        keepaliveTimer?.schedule(deadline: .now(), repeating: .seconds(10))
        keepaliveTimer?.setEventHandler(handler: { [weak self] in
            guard let self = self else { return }
            if self.currentUser != nil {
                LoginNetworkManager.keepUserLoginAlive(param: [:]) { code, errMessage, resultParam in
                    debugPrint("TUICore_AppLoginService_userKeepalive code:\(code) errMessage:\(errMessage)")
                }
            }
        })
        keepaliveTimer?.resume()
    }
}

extension LoginManager {
    public func removeLoginCache() {
        currentUser = nil
        UserDefaults.standard.set(nil, forKey: PER_USER_MODEL_KEY)
        UserOverdueLogicManager.sharedManager().userOverdueState = .notLogin
    }
}

extension LoginManager {

    public func getSms(param: [AnyHashable: Any]?,
                       resultCallback: @escaping TUICallServiceResultCallback) {
        let appId = param?["appId"] as! String
        let ticket = param?["ticket"] as! String
        let phone = param?["phone"] as! String
        let email = param?["email"] as! String
        let randstr = param?["randstr"] as! String
        LoginNetworkManager.getSms(appId: appId, ticket: ticket, phone: phone,
                                   email: email, randstr: randstr,
                                   success: { model in
            let successResultParams = ["jsonModel": model]
            resultCallback(Int(model.errorCode), model.errorMessage, successResultParams)
        }, failed: { code, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": code, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(code), errMsg, failedResultParams)
        })
    }

    public func getEmailVerifyCode(param: [AnyHashable: Any]?,
                                   resultCallback: @escaping TUICallServiceResultCallback) {
        let appId = param?["appId"] as! String
        let ticket = param?["ticket"] as! String
        let phone = param?["phone"] as! String
        let email = param?["email"] as! String
        let randstr = param?["randstr"] as! String
        LoginNetworkManager.getSms(appId: appId, ticket: ticket, phone: phone,
                                   email: email, randstr: randstr,
                                   success: { model in
            let successResultParams = ["jsonModel": model]
            resultCallback(Int(model.errorCode), model.errorMessage, successResultParams)
        }, failed: { code, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": code, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(code), errMsg, failedResultParams)
        })
    }

    public func loginByToken(param: [AnyHashable: Any]?,
                             resultCallback: @escaping TUICallServiceResultCallback) {
        let userId = param?["userId"] as! String
        let token = param?["token"] as! String
        LoginNetworkManager.loginByToken(userId: userId, token: token,
                                         success: { [weak self] data in
            guard let self = self else { return }
            if let data = data {
                currentUser = data
            }
            currentUser?.isHighRiskUser = data?.isHighRiskUser ?? false
            currentUser?.isHighRiskIp = data?.isHighRiskIp ?? false
            if let user = currentUser {
                syncUserModelLocalData(user)
            }
            let resultParam = ["data": data] as [AnyHashable: Any]
            resultCallback(kAppLoginServiceSuccessCode, "success", resultParam)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
    }

    public func loginByPhone(param: [AnyHashable: Any]?,
                             resultCallback: @escaping TUICallServiceResultCallback) {
        let phone = param?["phone"] as! String
        let code = param?["code"] as! String
        let sessionId = param?["sessionId"] as! String
        LoginNetworkManager.login(phone: phone, sessionId: sessionId, code: code,
                                  success: { [weak self] data in
            guard let self = self else { return }
            if let data = data {
                currentUser = data
            }
            currentUser?.isHighRiskUser = data?.isHighRiskUser ?? false
            currentUser?.isHighRiskIp = data?.isHighRiskIp ?? false
            if let user = currentUser {
                syncUserModelLocalData(user)
            }
            let resultParam = ["userModel": data] as [AnyHashable: Any]
            resultCallback(kAppLoginServiceSuccessCode, "success", resultParam)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
    }

    public func loginByEmail(param: [AnyHashable: Any]?,
                             resultCallback: @escaping TUICallServiceResultCallback) {
        let email = param?["email"] as! String
        let code = param?["code"] as! String
        let sessionId = param?["sessionId"] as! String
        LoginNetworkManager.login(email: email, sessionId: sessionId, code: code,
                                  success: { [weak self] data in
            guard let self = self else { return }
            if let data = data {
                currentUser = data
            }
            currentUser?.isHighRiskUser = data?.isHighRiskUser ?? false
            currentUser?.isHighRiskIp = data?.isHighRiskIp ?? false
            if let user = currentUser {
                syncUserModelLocalData(user)
            }
            let resultParam = ["data": data] as [AnyHashable: Any]
            resultCallback(kAppLoginServiceSuccessCode, "success", resultParam)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
    }

    public func loginByMOA(ticket: String,
                           success: ((_ data: BSUserModel?) -> Void)?,
                           failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)?) {
        LoginNetworkManager.loginByMOA(ticket: ticket,
                                       success: { [weak self] data in
            guard let self = self else { return }
            data?.loginType = "moa"
            currentUser = data
            currentUser?.isHighRiskUser = data?.isHighRiskUser ?? false
            currentUser?.isHighRiskIp = data?.isHighRiskIp ?? false
            if let user = currentUser {
                syncUserModelLocalData(user)
            }
            success?(data)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            failed?(errorCode, errMsg)
        })
    }

    public func getGlobalData(param: [AnyHashable: Any]?,
                              resultCallback: @escaping TUICallServiceResultCallback) {
        LoginNetworkManager.getImageCaptcha { data in
            let successResultParams = ["jsonModel": data]
            resultCallback(Int(data.errorCode), data.errorMessage, successResultParams)
        } failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        }
    }

    public func logout(param: [AnyHashable: Any]?,
                       resultCallback: @escaping TUICallServiceResultCallback) {
        let token = param?["token"] as! String
        let userId = param?["userId"] as! String
        LoginNetworkManager.logout(userId: userId, token: token,
                                   success: { data in
            let resultParam = ["data": data] as [AnyHashable: Any]
            resultCallback(kAppLoginServiceSuccessCode, "success", resultParam)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
    }

    public func logoff(param: [AnyHashable: Any]?,
                       resultCallback: @escaping TUICallServiceResultCallback) {
        let token = param?["token"] as! String
        let userId = param?["userId"] as! String
        LoginNetworkManager.deleteUser(userId: userId, token: token,
                                       success: { data in
            let resultParam = ["data": data] as [AnyHashable: Any]
            resultCallback(kAppLoginServiceSuccessCode, "success", resultParam)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
    }

    public func userUpdate(param: [AnyHashable: Any]?,
                           resultCallback: @escaping TUICallServiceResultCallback) {
        let currentUserModel = param?["currentUserModel"] as! BSUserModel
        let name = param?["name"] as! String
        LoginNetworkManager.updateUser(currentUserModel: currentUserModel, name: name,
                                       success: { data in
            let resultParam = ["data": data] as [AnyHashable: Any]
            resultCallback(kAppLoginServiceSuccessCode, "success", resultParam)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "failed"
            let failedResultParams = ["errorCode": errorCode, "errorMessage": errMsg] as [AnyHashable: Any]
            resultCallback(Int(errorCode), errMsg, failedResultParams)
        })
    }

    public func getInviteCode(_ email: String?,
                              success: ((_ data: HttpJsonModel) -> Void)? = nil,
                              failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        LoginNetworkManager.requestInvitationCode(email, success: success, failed: failed)
    }

    public func noneAuthLogin(withInvitationCode invitationCode: String?,
                              success: ((_ data: BSUserModel?) -> Void)? = nil,
                              failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        LoginNetworkManager.noneAuthLogin(withInvitationCode: invitationCode, success: success, failed: failed)
    }

    public func needReceiveEmail(_ email: String,
                                 _ marketingStatus: Bool,
                                 success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                 failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        LoginNetworkManager.requestEdmSendEmail(email, marketingStatus, success: success, failed: failed)
    }

    public func getUserModuleBlackList(success: ((_ data: HttpJsonModel) -> Void)? = nil,
                                       failed: ((_ errorCode: Int32, _ errorMessage: String?) -> Void)? = nil) {
        LoginNetworkManager.getUserModuleBlackList(currentUser?.userId ?? TUILogin.getUserID() ?? "") { [weak self] result in
            guard let self = self, let map = result.data as? [String: Any] else { return }
            currentUser?.bannedModules = map["module"] as? [String: Bool] ?? [:]
            currentUser?.bannedFeatures = map["feature"] as? [String: Bool] ?? [:]
            success?(result)
        } failed: { errorCode, errorMessage in
            failed?(errorCode, errorMessage)
            debugPrint("\(errorCode) \(String(describing: errorMessage))")
        }
    }
}
