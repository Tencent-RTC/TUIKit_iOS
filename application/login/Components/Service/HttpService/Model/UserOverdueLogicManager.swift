//
//  UserOverdueLogicManager.swift
//  login
//

import Foundation
import UIKit
import TUICore

@objc public enum UserOverdueState: Int {
    case notLogin = 0
    case alreadyLogged = 1
    case loggedAndOverdue = 2
}

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
