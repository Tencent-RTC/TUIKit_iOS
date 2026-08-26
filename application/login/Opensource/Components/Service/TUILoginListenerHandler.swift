//
//  TUILoginListenerHandler.swift
//  Login
//

import Foundation
import TUICore
import UIKit

final class TUILoginListenerHandler: NSObject, AppLifecycleHandler, TUILoginListener {

    static let shared = TUILoginListenerHandler()
    private override init() { super.init() }

    private weak var currentAlert: UIAlertController?

    func register() {
        AppLifecycleRegistry.shared.register(self)
    }

    // MARK: - AppLifecycleHandler

    func applicationDidFinishLaunching(_ application: UIApplication) {
        TUILogin.add(self)
    }

    // MARK: - TUILoginListener

    func onConnecting() {}

    func onConnectSuccess() {}

    func onConnectFailed(_ code: Int32, err: String!) {
        LoginLogger.Login.warn("TUILoginListener.onConnectFailed code=\(code) err=\(err ?? "nil")")
    }

    func onKickedOffline() {
        LoginLogger.Login.warn("TUILoginListener.onKickedOffline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showOverdueAlert()
        }
    }

    func onUserSigExpired() {
        LoginLogger.Login.warn("TUILoginListener.onUserSigExpired")
        LoginEntry.shared.onTokenExpired?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showOverdueAlert()
        }
    }

    // MARK: - Private

    private func showOverdueAlert() {
        guard currentAlert == nil else { return }
        guard let topVC = TUILoginListenerHandler.topMostViewController() else {
            performPassiveLogout()
            return
        }
        let alert = UIAlertController(
            title: LoginLocalize("login_common_prompt"),
            message: LoginLocalize("login_home_user_overdue"),
            preferredStyle: .alert
        )
        alert.addAction(.init(title: LoginLocalize("login_common_btn_ok"), style: .default) { [weak self] _ in
            self?.performPassiveLogout()
        })
        currentAlert = alert
        topVC.present(alert, animated: true)
    }

    private func performPassiveLogout() {
        currentAlert = nil
        LoginEntry.shared.logout { _ in
            LoginEntry.shared.onPassiveLogout?()
        }
    }

    private static func topMostViewController() -> UIViewController? {
        guard let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return nil }
        var vc = keyWindow.rootViewController
        while let presented = vc?.presentedViewController {
            vc = presented
        }
        return vc
    }
}
