//
//  UserOverdueLogicManager.swift
//  login
//
//  从 BusinessService 复制的用户过期状态管理
//

import Foundation
import UIKit
import TUICore

/// 用户状态枚举
@objc public enum UserOverdueState: Int {
    case notLogin = 0          // 用户没有登录
    case alreadyLogged = 1     // 用户已经登录
    case loggedAndOverdue = 2  // 登录了 token 已经失效或者被踢出
}

// MARK: - 用户登录状态管理
public class UserOverdueLogicManager: NSObject {
    private static let staticInstance: UserOverdueLogicManager = UserOverdueLogicManager()
    public static func sharedManager() -> UserOverdueLogicManager { staticInstance }

    private override init() {
        super.init()
        viewModel = UserOverdueViewModel()
        self.addObserver(viewModel, forKeyPath: "_userOverdueState", options: [.old, .new], context: nil)
    }

    public var viewModel: UserOverdueViewModel!

    @objc dynamic private var _userOverdueState: UserOverdueState = .notLogin
    weak var nowAlertController: UIAlertController?

    public var userOverdueState: UserOverdueState {
        set {
            let oldValue = _userOverdueState
            // 仅当写入 .loggedAndOverdue 时打印调用栈，方便定位是哪条路径触发了"登录状态失效"弹窗
            if newValue == .loggedAndOverdue {
                LoginLogger.Login.warn("UserOverdueState \(oldValue) -> .loggedAndOverdue, caller stack:")
                Thread.callStackSymbols.prefix(12).enumerated().forEach { idx, frame in
                    LoginLogger.Login.warn("  #\(idx) \(frame)")
                }
            }
            switch newValue {
            case .notLogin:
                if _userOverdueState == .alreadyLogged {
                    _userOverdueState = newValue
                }
                // 否则忽略（不能从 .loggedAndOverdue 直接静默回 .notLogin）
            case .alreadyLogged:
                _userOverdueState = newValue
            case .loggedAndOverdue:
                _userOverdueState = newValue
            }
        }
        get {
            return _userOverdueState
        }
    }
}

// MARK: - token 失效
public class UserOverdueViewModel: NSObject {
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                      change: [NSKeyValueChangeKey: Any]?,
                                      context: UnsafeMutableRawPointer?) {
        if keyPath == "_userOverdueState" {
            let current = UserOverdueLogicManager.sharedManager().userOverdueState
            if current == .loggedAndOverdue {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
                    self.showOverdueAlertView()
                }
            }
        }
    }

    func showOverdueAlertView() {
        if UserOverdueLogicManager.sharedManager().nowAlertController != nil {
            return
        }
        LoginLogger.Login.warn("UserOverdueViewModel.showOverdueAlertView present")
        let alertController = UIAlertController(
            title: LoginLocalize("login_common_prompt"),
            message: LoginLocalize("login_home_user_overdue"),
            preferredStyle: .alert
        )
        let sureAction = UIAlertAction(title: LoginLocalize("login_common_btn_ok"), style: .default) { _ in
            LoginEntry.shared.logout { _ in
                LoginEntry.shared.onPassiveLogout?()
            }
        }
        alertController.addAction(sureAction)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = keyWindow.rootViewController {
            rootViewController.present(alertController, animated: true, completion: nil)
        }
        UserOverdueLogicManager.sharedManager().nowAlertController = alertController
    }
}
