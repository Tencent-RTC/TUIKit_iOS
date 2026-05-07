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

    func onConnectFailed(_ code: Int32, err: String!) {}

    func onKickedOffline() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }

    func onUserSigExpired() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }
}
