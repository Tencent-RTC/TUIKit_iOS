//
//  LoginNetworkService.swift
//  login
//
//  登录相关网络请求统一封装
//
//  旧版来源：
//    - LoginManager (BusinessService) — 正式版网络请求
//    - IMLogicRequest (BusinessService) — IM 登录/登出
//
//  封装原则：
//    - 对 LoginManager 做一层薄封装
//    - 统一异步回调为 Result 类型
//    - 登录成功后构建 LoginResult 返回（埋点绑定由壳工程 AppAnalytics 处理）
//

import Foundation
import TUICore

/// 登录网络服务
///
/// 所有子模块 Store 通过此类访问网络，不直接依赖 `LoginManager`
public final class LoginNetworkService {
    // MARK: - 发送短信验证码
    
    /// 发送短信验证码
    /// - Parameters:
    ///   - phone: 完整手机号（区号+号码，如 "8613800138000"）
    ///   - captcha: 人机验证结果
    ///   - success: 成功回调，返回 sessionId
    ///   - failed: 失败回调
    public func sendSms(
        phone: String,
        captcha: CaptchaResult,
        success: @escaping (_ sessionId: String) -> Void,
        failed: @escaping (_ error: LoginError) -> Void
    ) {
        let param: [String: Any] = [
            "appId": captcha.appId,
            "ticket": captcha.ticket,
            "phone": phone,
            "email": "",
            "randstr": captcha.randstr,
        ]
        LoginManager.shared.getSms(param: param) { code, errorMessage, result in
            if code == kAppLoginServiceSuccessCode {
                guard let model = result["jsonModel"] as? HttpJsonModel,
                      let sessionId = model.sessionID
                else {
                    failed(.verifyCodeFailed(message: errorMessage))
                    return
                }
                success(sessionId)
            } else {
                if code == kAppLoginServiceIOTDenyCode {
                    failed(.verifyCodeFailed(message: LoginLocalize("login_error_iot_phone")))
                } else {
                    failed(.verifyCodeFailed(message: errorMessage))
                }
            }
        }
    }
    
    // MARK: - 发送邮箱验证码
    
    /// 发送邮箱验证码
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - captcha: 人机验证结果
    ///   - success: 成功回调，返回 sessionId
    ///   - failed: 失败回调
    public func sendEmailVerifyCode(
        email: String,
        captcha: CaptchaResult,
        success: @escaping (_ sessionId: String) -> Void,
        failed: @escaping (_ error: LoginError) -> Void
    ) {
        let param: [String: Any] = [
            "appId": captcha.appId,
            "ticket": captcha.ticket,
            "phone": "",
            "email": email,
            "randstr": captcha.randstr,
        ]
        LoginManager.shared.getEmailVerifyCode(param: param) { code, errorMessage, result in
            if code == kAppLoginServiceSuccessCode || code == 0 {
                guard let model = result["jsonModel"] as? HttpJsonModel,
                      let sessionId = model.sessionID
                else {
                    failed(.verifyCodeFailed(message: errorMessage))
                    return
                }
                success(sessionId)
            } else {
                failed(.verifyCodeFailed(message: errorMessage))
            }
        }
    }
    
    // MARK: - 手机号登录
    
    /// 手机号验证码登录
    /// - Parameters:
    ///   - phone: 完整手机号
    ///   - sessionId: 验证码 sessionId
    ///   - code: 验证码
    ///   - completion: 结果回调
    public func loginByPhone(
        phone: String,
        sessionId: String,
        code: String,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        let param: [String: Any] = [
            "phone": phone,
            "sessionId": sessionId,
            "code": code,
            "apaasAppId": LoginEntry.shared.config.apaasAppId,
        ]
        LoginManager.shared.loginByPhone(param: param) { [weak self] resultCode, errorMessage, _ in
            if resultCode == kAppLoginServiceSuccessCode {
                guard let self = self else {
                    completion(.failure(.unknown(message: "LoginNetworkService was deallocated")))
                    return
                }
                self.handleLoginSuccess(mode: .phoneVerify, completion: completion)
            } else {
                LoginNetworkManager.processLoginFailCode(code: Int32(resultCode))
                completion(.failure(.loginFailed(code: resultCode, message: errorMessage)))
            }
        }
    }
    
    // MARK: - 邮箱登录
    
    /// 邮箱验证码登录
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - sessionId: 验证码 sessionId
    ///   - code: 验证码
    ///   - completion: 结果回调
    public func loginByEmail(
        email: String,
        sessionId: String,
        code: String,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        let param: [String: Any] = [
            "email": email,
            "sessionId": sessionId,
            "code": code,
            "apaasAppId": LoginEntry.shared.config.apaasAppId,
        ]
        LoginManager.shared.loginByEmail(param: param) { [weak self] resultCode, errorMessage, _ in
            if resultCode == kAppLoginServiceSuccessCode {
                guard let self = self else {
                    completion(.failure(.unknown(message: "LoginNetworkService was deallocated")))
                    return
                }
                self.handleLoginSuccess(mode: .emailVerify, completion: completion)
            } else {
                LoginNetworkManager.processLoginFailCode(code: Int32(resultCode))
                completion(.failure(.loginFailed(code: resultCode, message: errorMessage)))
            }
        }
    }
    
    // MARK: - Token 登录
    
    /// Token 自动登录
    /// - Parameters:
    ///   - userId: 用户 ID
    ///   - token: 用户 Token
    ///   - originalMode: 上次登录成功时的登录方式，用于保持 loginMode 一致性
    ///   - completion: 结果回调
    public func loginByToken(
        userId: String,
        token: String,
        originalMode: LoginMode,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        let param: [String: Any] = [
            "userId": userId,
            "token": token,
            "apaasAppId": LoginEntry.shared.config.apaasAppId,
        ]
        LoginManager.shared.loginByToken(param: param) { [weak self] resultCode, _, _ in
            if resultCode == kAppLoginServiceSuccessCode {
                guard let self = self else {
                    completion(.failure(.unknown(message: "LoginNetworkService was deallocated")))
                    return
                }
                self.handleLoginSuccess(mode: originalMode, completion: completion)
            } else {
                UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
                LoginNetworkManager.processLoginFailCode(code: Int32(resultCode))
                // 通知壳工程：token 过期事件（精确语义，独立于被动登出）
                LoginEntry.shared.onTokenExpired?()
                completion(.failure(.tokenExpired))
            }
        }
    }
    
    // MARK: - MOA 票据登录
    
    /// iOA / MOA 票据登录
    /// - Parameters:
    ///   - ticket: ITLogin SDK 返回的 credentialkey 票据
    ///   - completion: 结果回调
    public func loginByMOA(
        ticket: String,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        LoginManager.shared.loginByMOA(ticket: ticket, success: { [weak self] _ in
            guard let self = self else {
                completion(.failure(.unknown(message: "LoginNetworkService was deallocated")))
                return
            }
            self.handleLoginSuccess(mode: .ioaAuth, completion: completion)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "iOA login failed"
            LoginNetworkManager.processLoginFailCode(code: errorCode)
            completion(.failure(.ioaAuthFailed(message: errMsg)))
        })
    }
    
    // MARK: - 无验证登录（邀请码）
    
    /// 无验证登录（邀请码模式）
    /// - Parameters:
    ///   - invitationCode: 邀请码（可选）
    ///   - completion: 结果回调
    public func noneAuthLogin(
        invitationCode: String?,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        LoginManager.shared.noneAuthLogin(withInvitationCode: invitationCode, success: { [weak self] _ in
            guard let self = self else {
                completion(.failure(.unknown(message: "LoginNetworkService was deallocated")))
                return
            }
            self.handleLoginSuccess(mode: .inviteCode, completion: completion)
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "Login failed"
            completion(.failure(.loginFailed(code: Int(errorCode), message: errMsg)))
        })
    }
    
    // MARK: - 登出
    
    /// 登出
    /// - Parameter completion: 结果回调
    public func logout(completion: @escaping (Result<Void, LoginError>) -> Void) {
        guard let user = LoginManager.shared.getCurrentUser() else {
            completion(.failure(.unknown(message: "No current user")))
            return
        }
        let param: [String: Any] = [
            "userId": user.userId,
            "token": user.token,
        ]
        LoginManager.shared.logout(param: param) { resultCode, errorMessage, _ in
            if resultCode == kAppLoginServiceSuccessCode {
                LoginManager.shared.removeLoginCache()
                completion(.success(()))
            } else {
                completion(.failure(.networkError(message: errorMessage)))
            }
        }
    }
    
    // MARK: - 注销账户
    
    /// 注销账户（删除用户）
    /// - Parameter completion: 结果回调
    public func deleteAccount(completion: @escaping (Result<Void, LoginError>) -> Void) {
        guard let user = LoginManager.shared.getCurrentUser() else {
            completion(.failure(.unknown(message: "No current user")))
            return
        }
        let param: [String: Any] = [
            "userId": user.userId,
            "token": user.token,
        ]
        LoginManager.shared.logoff(param: param) { resultCode, errorMessage, _ in
            if resultCode == kAppLoginServiceSuccessCode {
                LoginManager.shared.removeLoginCache()
                completion(.success(()))
            } else {
                completion(.failure(.networkError(message: errorMessage)))
            }
        }
    }
    
    // MARK: - 修改用户昵称
    
    /// 修改用户昵称
    /// - Parameters:
    ///   - name: 新昵称
    ///   - completion: 结果回调
    public func updateUserName(
        name: String,
        completion: @escaping (Result<Void, LoginError>) -> Void
    ) {
        guard let user = LoginManager.shared.getCurrentUser() else {
            completion(.failure(.unknown(message: "No current user")))
            return
        }
        let param: [String: Any] = [
            "currentUserModel": user,
            "name": name,
        ]
        LoginManager.shared.userUpdate(param: param) { resultCode, errorMessage, _ in
            if resultCode == kAppLoginServiceSuccessCode {
                completion(.success(()))
            } else {
                completion(.failure(.networkError(message: errorMessage)))
            }
        }
    }
    
    // MARK: - 获取缓存用户
    
    /// 获取缓存中的当前用户
    /// - Returns: 当前登录用户，未登录时返回 nil
    public func getCachedUser() -> UserModel? {
        guard let user = LoginManager.shared.getCurrentUser() else { return nil }
        return UserModel(
            userId: user.userId,
            token: user.token,
            userSig: user.userSig,
            phone: user.phone,
            email: user.email,
            name: user.name,
            avatar: user.avatar
        )
    }
    
    /// 获取缓存用户的原始 BSUserModel
    /// 供内部需要传递给 LoginManager 的场景使用
    func getRawCachedUser() -> BSUserModel? {
        return LoginManager.shared.getCurrentUser()
    }
    
    // MARK: - 申请邀请码
    
    /// 申请邀请码
    /// - Parameters:
    ///   - email: 邮箱
    ///   - completion: 结果回调
    public func requestInvitationCode(
        email: String?,
        completion: @escaping (Result<Void, LoginError>) -> Void
    ) {
        LoginManager.shared.getInviteCode(email, success: { _ in
            completion(.success(()))
        }, failed: { errorCode, errorMessage in
            let errMsg = errorMessage ?? "Request failed"
            completion(.failure(.loginFailed(code: Int(errorCode), message: errMsg)))
        })
    }
    
    // MARK: - 营销邮件订阅
    
    /// 营销邮件订阅
    /// - Parameters:
    ///   - email: 邮箱
    ///   - marketingStatus: 是否订阅营销邮件
    public func needReceiveEmail(
        email: String,
        marketingStatus: Bool
    ) {
        LoginManager.shared.needReceiveEmail(email, marketingStatus)
    }
    
    // MARK: - 获取用户模块黑名单
    
    /// 获取用户模块黑名单
    /// - Parameter completion: 结果回调
    public func getUserModuleBlackList(
        completion: @escaping (Result<Void, LoginError>) -> Void
    ) {
        LoginManager.shared.getUserModuleBlackList(success: { _ in
            completion(.success(()))
        }, failed: { _, errorMessage in
            let errMsg = errorMessage ?? "Request failed"
            completion(.failure(.networkError(message: errMsg)))
        })
    }
    
    // MARK: - 登录成功后构建结果

    /// 登录成功后构建 LoginResult
    /// 调用此方法会：
    ///   1. 从 LoginManager 获取当前用户数据
    ///   2. 构建 LoginResult 并返回
    ///
    /// 埋点用户身份绑定由壳工程（SceneDelegate + AppAnalytics）在收到结果后处理，
    /// 本模块不依赖任何埋点 SDK。
    private func handleLoginSuccess(mode: LoginMode,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        guard let rawUser = LoginManager.shared.getCurrentUser() else {
            completion(.failure(.loginFailed(code: -1, message: "Login succeeded but user data not found")))
            return
        }

        // 构建结果
        let userModel = UserModel(
            userId: rawUser.userId,
            token: rawUser.token,
            userSig: rawUser.userSig,
            phone: rawUser.phone,
            email: rawUser.email,
            name: rawUser.name,
            avatar: rawUser.avatar
        )
        let loginResult = LoginResult(userModel: userModel, mode: mode)
        completion(.success(loginResult))
    }
    
    // MARK: - 心跳保活
    
    /// 启动心跳保活
    public func startKeepAlive() {
        LoginManager.shared.keepAlive()
    }
}
