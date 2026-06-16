//
//  TUILoginListenerHandler.swift
//  Login
//
//  TUILogin 被踢下线 / UserSig 过期监听
//
//  通过 AppLifecycleRegistry 机制接入，App 启动时自动注册 TUILoginListener，
//  收到被踢或过期回调后，交由 UserOverdueLogicManager 处理弹窗 → 引导重登。
//

import Foundation
import TUICore

// MARK: - TUILoginListenerHandler

/// TUILogin 登录状态监听 Handler
///
/// 职责：
///   - `applicationDidFinishLaunching` 时注册 `TUILogin.add(self)`
///   - 收到 `onKickedOffline` / `onUserSigExpired` 时，设置 `UserOverdueLogicManager` 状态为 `.loggedAndOverdue`
///   - 由 `UserOverdueLogicManager` 内部弹窗并清理登录缓存
///
/// 使用方式：
///   在 `LoginEntry.initialize()` 中调用 `TUILoginListenerHandler.shared.register()`
final class TUILoginListenerHandler: NSObject, AppLifecycleHandler {

    static let shared = TUILoginListenerHandler()
    private override init() { super.init() }

    /// 注册到 AppLifecycleRegistry（幂等，重复调用无副作用）
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

    /// 当前用户被踢下线，触发 UserOverdueLogicManager 弹窗 → 引导重登
    func onKickedOffline() {
        LoginLogger.Login.warn("TUILoginListener.onKickedOffline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }

    /// 在线时票据过期，触发 UserOverdueLogicManager 弹窗 → 引导重登
    func onUserSigExpired() {
        LoginLogger.Login.warn("TUILoginListener.onUserSigExpired")
        // 通知壳工程：token / userSig 过期事件（精确语义，独立于被动登出）
        // 注意：onKickedOffline 不在此回调范围内——被踢下线虽然也走"凭证失效→重登"，
        // 但语义上属于服务端主动剔除（多端登录冲突等），与"凭证自然过期"不同。
        LoginEntry.shared.onTokenExpired?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserOverdueLogicManager.sharedManager().userOverdueState = .loggedAndOverdue
        }
    }
}
