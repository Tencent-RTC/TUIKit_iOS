//
//  LoginNetworkService.swift
//  login
//

import Foundation
import TUICore

public final class LoginNetworkService {
    
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
                    failed(.verifyCodeFailed(message: LoginLocalize("LoginNetwork.ProfileManager.iotfailed")))
                } else {
                    failed(.verifyCodeFailed(message: errorMessage))
                }
            }
        }
    }
    
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
                completion(.failure(.tokenExpired))
            }
        }
    }
    
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
    
    func getRawCachedUser() -> BSUserModel? {
        return LoginManager.shared.getCurrentUser()
    }
    
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
    
    public func needReceiveEmail(
        email: String,
        marketingStatus: Bool
    ) {
        LoginManager.shared.needReceiveEmail(email, marketingStatus)
    }
    
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
    
    private func handleLoginSuccess(mode: LoginMode,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) {
        guard let rawUser = LoginManager.shared.getCurrentUser() else {
            completion(.failure(.loginFailed(code: -1, message: "Login succeeded but user data not found")))
            return
        }

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
    
    public func startKeepAlive() {
        LoginManager.shared.keepAlive()
    }
}
