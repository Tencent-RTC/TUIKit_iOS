//
//  TUILoginListenerHandler.swift
//  Login
//

import Foundation
import TUICore

// MARK: - TUILoginListenerHandler

final class TUILoginListenerHandler: NSObject, AppLifecycleHandler {

    static let shared = TUILoginListenerHandler()
    private override init() { super.init() }

    func register() {
        AppLifecycleRegistry.shared.register(self)
    }

    // MARK: - AppLifecycleHandler

    func applicationDidFinishLaunching(_ application: UIApplication) {
        TUILogin.add(self)
    }
}

// MARK: - TUILoginListener

extension TUILoginListenerHandler: TUILoginListener {
    func onConnecting() {}

    func onConnectSuccess() {}

    func onConnectFailed(_ code: Int32, err: String!) {
        LoginLogger.Login.warn("TUILoginListener.onConnectFailed code=\(code) err=\(err ?? "nil")")
    }

    func onKickedOffline() {
        LoginLogger.Login.warn("TUILoginListener.onKickedOffline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }

    func onUserSigExpired() {
        LoginLogger.Login.warn("TUILoginListener.onUserSigExpired")
        LoginEntry.shared.onTokenExpired?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }
}
