//
//  ProfileManager.swift
//  login
//
//  从 BusinessService 复制的 Debug 登录用 ProfileManager
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
            // 第一次拉 profile；失败时按"是否 settled"决定是抛错还是等 onConnect* 后重试
            self?.fetchSelfInfoGated(userID: user, success: success, failed: failed)
        } fail: { (code, errorDes) in
            LoginLogger.Login.warn("ProfileManager.IMLogin TUILogin.login FAILED code=\(code) err=\(errorDes ?? "nil")")
            failed(errorDes ?? "")
        }
    }

    /// 拉取 self profile，失败时通过 IMConnectGate 等待 IM 连接 settled 后重试一次。
    ///
    /// 触发竞态的根因（详见 IMConnectGate.swift 顶部注释）：
    ///   - 冷启动 + has-login 短路 → TUILogin.login 同步 success；
    ///   - 但 V2TIM 底层 ticket exchange 还在进行，在飞 packet 会被 NotifyTicketChange 中断；
    ///   - 此时 getUsersInfo 容易拿到 6222 / 7009 等过渡态错误。
    ///
    /// 策略：
    ///   1) 第一次直接调 getUsersInfo；
    ///   2) 若失败且 `getLoginStatus() == .STATUS_LOGINED`（已 settled）→ 真错误，立即抛；
    ///   3) 若失败但仍非 LOGINED → 通过 gate 等待 onConnectSuccess / onConnectFailed / 超时
    ///      任一信号后重试一次；重试结果直接终判（不再继续等）。
    private func fetchSelfInfoGated(userID: String,
                                    success: @escaping () -> Void,
                                    failed: @escaping (_ error: String) -> Void) {
        fetchSelfInfo(userID: userID, success: success, failedRaw: { [weak self] code, err in
            guard let self = self else { return }
            let status = V2TIMManager.sharedInstance()?.getLoginStatus()
            if status == .STATUS_LOGINED {
                // 已 settled 仍失败 → 真错误
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

    /// 单次 getUsersInfo + 写回 curUserModel 的最小操作（不带任何重试逻辑）
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
