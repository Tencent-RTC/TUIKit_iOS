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
            if UserOverdueLogicManager.sharedManager().userOverdueState == .loggedAndOverdue {
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
        let alertController = UIAlertController(
            title: LoginLocalize("Demo.TRTC.LiveRoom.prompt"),
            message: LoginLocalize("Demo.TRTC.Home.useroverduemessage"),
            preferredStyle: .alert
        )
        let sureAction = UIAlertAction(title: LoginLocalize("LoginNetwork.AppUtils.determine"), style: .default) { _ in
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
