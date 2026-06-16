//
//  IOAAuthManager.swift
//  login
//
//  iOA SDK 生命周期管理（模块内闭环）
//
//  职责：
//    1. 初始化 ITLogin SDK（`start` / `disableLoginPage` / 设置 delegate）
//    2. 实现 ITLoginDelegate 接收票据回调
//    3. 实现 AppLifecycleHandler 处理 SSO URL 回调
//    4. 将票据转发给当前活跃的 LoginNavigator
//
//  设计：
//    - 单例，由 LoginEntry.initialize() 在传入 ioaAppKey/ioaAppId 时调用 setupIOA()
//    - iOA 相关的所有逻辑在此闭环，LoginEntry 不再 import ITLogin
//

import Foundation
import UIKit
import ITLogin

/// iOA SDK 生命周期管理器（单例）
///
/// 封装 ITLogin SDK 的初始化、回调处理和 SSO URL 分发，
/// 使 iOA 相关逻辑完全收拢在 IOAAuth 模块内部。
public final class IOAAuthManager: NSObject {
    public static let shared = IOAAuthManager()
    private override init() { super.init() }
    
    /// 当前活跃的 LoginNavigator，用于转发 iOA 票据（保留向后兼容）
    /// 由 LoginEntry.launch() 设置，登录完成后由 LoginEntry 清除
    weak var activeNavigator: LoginNavigator?

    /// 当前活跃的 IOA 登录模态控制器，用于直接转发票据
    /// 由 LoginNavigator.pushIOAAuth() 设置，登录完成后自动清除
    weak var activeIOAViewController: IOAAuthViewController?

    private var isIOAInitialized = false

    // MARK: - IOA SDK 初始化
    
    /// 初始化 ITLogin SDK 并注册为 AppLifecycleHandler
    ///
    /// 内部会自动：
    ///   1. 调用 `ITLogin.start(withAppKey:appId:)` 启动 SDK
    ///   2. 设置 `disableLoginPage(true)` 禁用 SDK 自带登录页
    ///   3. 将 IOAAuthManager 设为 ITLoginDelegate
    ///   4. 将自身注册到 `AppLifecycleRegistry`，接收 URL 回调
    ///
    /// 重复调用安全 — 内部有防重入标志。
    func setupIOA(appKey: String, appId: String) {
        guard !isIOAInitialized else { return }
        isIOAInitialized = true
        
        ITLogin.sharedInstance().start(withAppKey: appKey, appId: appId)
        ITLogin.sharedInstance().disableLoginPage(true)
        ITLogin.sharedInstance().delegate = self
        
        // 注册到 AppLifecycleRegistry，接收 URL 打开回调（用于 SSO）
        AppLifecycleRegistry.shared.register(self)
    }

    // MARK: - IOA SDK 登出

    /// 退出 ITLogin SDK 登录态，清除 SDK 缓存的凭证。
    ///
    /// 必须在用户退出登录时调用，否则下次进入 IOA 登录时，
    /// SDK 会用缓存的旧 token 自动触发 `didTokenLoginSuccess`，
    /// 拿到已失效的 ticket 导致后端返回 "MOA ticket key required" 错误。
    func logoutIOA() {
        guard isIOAInitialized else { return }
        ITLogin.sharedInstance().logout()
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
        // 优先使用模态 VC 的直接引用（新方案）
        if let vc = activeIOAViewController {
            vc.handleTicket(ticket)
        } else {
            // 兜底：通过 navigator 的旧路径转发
            activeNavigator?.handleIOATicket(ticket)
        }
    }
}
