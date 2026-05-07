//
//  IOAAuthManager.swift
//  login
//

import Foundation
import UIKit
import ITLogin

public final class IOAAuthManager: NSObject {
    public static let shared = IOAAuthManager()
    private override init() { super.init() }
    
    weak var activeNavigator: LoginNavigator?
    
    private var isIOAInitialized = false
    
    func setupIOA(appKey: String, appId: String) {
        guard !isIOAInitialized else { return }
        isIOAInitialized = true
        
        ITLogin.sharedInstance().start(withAppKey: appKey, appId: appId)
        ITLogin.sharedInstance().disableLoginPage(true)
        ITLogin.sharedInstance().delegate = self
        
        AppLifecycleRegistry.shared.register(self)
    }
}

// MARK: - AppLifecycleHandler

extension IOAAuthManager: AppLifecycleHandler {
    public func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        guard isIOAInitialized else { return false }
        if ITLogin.sharedInstance().shouldHandleSSO(url) {
            ITLogin.sharedInstance().handleSSOURL(url)
            return true
        }
        return false
    }
}

// MARK: - ITLoginDelegate

extension IOAAuthManager: ITLoginDelegate {
    public func didValidateLoginSuccess() {
        let ticket = ITLogin.sharedInstance().getInfo().credentialkey
        performIOALogin(ticket: ticket)
    }
    
    public func didValidateLoginFailWithError(_ error: ITLoginError!) {}
    
    public func didValidateLoginFail(withError error: ITLoginError!) {}
    
    public func didTokenLoginSuccess() {
        let ticket = ITLogin.sharedInstance().getInfo().credentialkey
        performIOALogin(ticket: ticket)
    }
    
    public func didTokenLoginFailWithError(_ error: ITLoginError!) {}
    
    public func didTokenLoginFail(withError error: ITLoginError!) {}
    
    public func didFinishLogout() {}
    
    // MARK: - Helper
    
    private func performIOALogin(ticket: String) {
        activeNavigator?.handleIOATicket(ticket)
    }
}
