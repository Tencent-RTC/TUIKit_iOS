//
//  ProfileManager.swift
//  login
//

import Foundation
import TUICore
import ImSDK_Plus

public class ProfileManager: NSObject {
    public static let shared = ProfileManager()
    private override init() {}

    var sessionId: String = ""
    public internal(set) var curUserModel: BSUserModel? = nil

    public func getCurrentUser() -> BSUserModel? {
        if curUserModel == nil {
            if let cacheData = UserDefaults.standard.object(forKey: PER_USER_MODEL_KEY) as? Data {
                do {
                    curUserModel = try JSONDecoder().decode(BSUserModel.self, from: cacheData)
                } catch {
                    return nil
                }
            }
        }
        return curUserModel
    }

    public func login(phone: String,
                      name: String,
                      token: String,
                      success: @escaping () -> Void,
                      failed: ((_ error: String) -> Void)? = nil, auto: Bool = false) {
        let phoneValue = phone
        if !auto {
            assert(phoneValue.count > 0)
            curUserModel = generateUserModel(userID: phoneValue, token: token)
        }
        do {
            let cacheData = try JSONEncoder().encode(curUserModel)
            UserDefaults.standard.set(cacheData, forKey: PER_USER_MODEL_KEY)
            success()
        } catch {
            LoginLogger.Login.warn("ProfileManager.login encode failed")
            failed?("usermodel save failed")
        }
    }

    public func localizeUserModel() {
        do {
            let cacheData = try JSONEncoder().encode(curUserModel)
            UserDefaults.standard.set(cacheData, forKey: PER_USER_MODEL_KEY)
        } catch {
            print("Save Failed")
        }
    }

    public func setNickName(name: String, success: @escaping () -> Void,
                            failed: @escaping (_ error: String) -> Void) {
        let userInfo = V2TIMUserFullInfo()
        userInfo.nickName = name
        curUserModel?.name = name
        V2TIMManager.sharedInstance()?.setSelfInfo(info: userInfo, succ: {
            success()
            debugPrint("set profile success")
        }, fail: { (code, desc) in
            failed(desc ?? "")
            debugPrint("set profile failed.")
        })
    }

    public func IMLogin(sdkAppId: Int, userSig: String, success: @escaping () -> Void, failed: @escaping (_ error: String) -> Void) {
        guard let userID = curUserModel?.userId else {
            LoginLogger.Login.warn("ProfileManager.IMLogin curUserModel.userId is nil")
            failed("userID wrong")
            return
        }
        let user = String(userID)
        LoginLogger.Login.info("ProfileManager.IMLogin sdkAppId=\(sdkAppId) userID=\(user)")

        TUILogin.login(Int32(sdkAppId), userID: user, userSig: userSig) { [weak self] in
            self?.fetchSelfInfoGated(userID: user, success: success, failed: failed)
        } fail: { (code, errorDes) in
            LoginLogger.Login.warn("ProfileManager.IMLogin TUILogin.login FAILED code=\(code) err=\(errorDes ?? "nil")")
            failed(errorDes ?? "")
        }
    }

    private func fetchSelfInfoGated(userID: String,
                                    success: @escaping () -> Void,
                                    failed: @escaping (_ error: String) -> Void) {
        fetchSelfInfo(userID: userID, success: success, failedRaw: { [weak self] code, err in
            guard let self = self else { return }
            let status = V2TIMManager.sharedInstance()?.getLoginStatus()
            if status == .STATUS_LOGINED {
                LoginLogger.Login.warn("ProfileManager.fetchSelfInfo failed after settled, code=\(code) err=\(err ?? "nil")")
                failed(err ?? "")
                return
            }

            LoginLogger.Login.info("ProfileManager.fetchSelfInfo first attempt failed code=\(code) status=\(String(describing: status)), waiting IMConnectGate")
            IMConnectGate.shared.waitOnce(timeout: 1.0) { [weak self] in
                LoginLogger.Login.info("ProfileManager.fetchSelfInfo gate fired, retrying")
                self?.fetchSelfInfo(userID: userID, success: success, failedRaw: { code2, err2 in
                    LoginLogger.Login.warn("ProfileManager.fetchSelfInfo retry failed code=\(code2) err=\(err2 ?? "nil")")
                    failed(err2 ?? "")
                })
            }
        })
    }

    private func fetchSelfInfo(userID: String,
                               success: @escaping () -> Void,
                               failedRaw: @escaping (_ code: Int32, _ err: String?) -> Void) {
        V2TIMManager.sharedInstance()?.getUsersInfo([userID], succ: { [weak self] (infos) in
            guard let self = self else { return }
            if let info = infos?.first {
                self.curUserModel?.avatar = info.faceURL ?? ""
                self.curUserModel?.name = info.nickName ?? ""
                self.curUserModel?.userId = info.userID ?? ""
                self.localizeUserModel()
                UserOverdueLogicManager.sharedManager().userOverdueState = .alreadyLogged
                LoginLogger.Login.info("ProfileManager.IMLogin SUCCESS userID=\(info.userID ?? "nil") name='\(info.nickName ?? "")'")
                success()
            } else {
                LoginLogger.Login.warn("ProfileManager.fetchSelfInfo getUsersInfo SUCC but empty infos")
                failedRaw(0, "empty infos")
            }
        }, fail: { (code, err) in
            failedRaw(code, err)
        })
    }

    public func curUserID() -> String? {
        guard let userID = curUserModel?.userId else {
            return nil
        }
        return userID
    }

    public func removeLoginCache() {
        UserDefaults.standard.set(nil, forKey: PER_USER_MODEL_KEY)
    }

    public func curUserSig() -> String {
        return curUserModel?.userSig ?? ""
    }

    public func synchronizUserInfo() {
        guard let userModel = curUserModel else {
            return
        }
        let userInfo = V2TIMUserFullInfo()
        userInfo.nickName = userModel.name
        userInfo.faceURL = userModel.avatar
        V2TIMManager.sharedInstance()?.setSelfInfo(info: userInfo, succ: {
            debugPrint("set profile success")
        }, fail: { (code, desc) in
            debugPrint("set profile failed.")
        })
    }

    func generateUserModel(userID: String, token: String) -> BSUserModel {
        let defaultAvatar = "https://imgcache.qq.com/qcloud/public/static//avatar1_100.20191230.png"
        let userModel = BSUserModel(token: "",
                                    phone: userID, email: "",
                                    name: "",
                                    avatar: defaultAvatar,
                                    userId: userID,
                                    appId: "",
                                    userSig: token,
                                    apaasAppId: "",
                                    apaasUserId: "",
                                    sdkUserSig: "")
        return userModel
    }
}
