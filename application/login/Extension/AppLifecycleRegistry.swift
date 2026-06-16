//
//  AppLifecycleRegistry.swift
//  Login
//
//  AppDelegate 回调分发中心（Login Pod 内部副本）
//
//  设计目标：
//    多个模块（login、分享、支付等）可能都需要处理 AppDelegate 中的回调（如 URL 打开），
//    通过注册机制让各模块自行注册 handler，AppDelegate 只负责转发，互不干扰。
//
//  使用方式：
//    1. 模块实现 AppLifecycleHandler 协议
//    2. 在模块初始化时调用 AppLifecycleRegistry.shared.register(handler)
//    3. 壳工程在系统回调中转发：
//       - AppDelegate 架构：AppLifecycleRegistry.shared.handleOpenURL(url, options:)
//       - SceneDelegate 架构：AppLifecycleRegistry.shared.handleOpenURLContexts(contexts)
//
//  分发规则：
//    - URL 处理：按注册顺序依次调用，任一 handler 返回 true 即短路（不再继续）
//    - 生命周期事件：全部 handler 都会收到通知

import UIKit

// MARK: - Protocol

/// 模块级 App 生命周期处理协议
///
/// 各模块实现此协议并注册到 `AppLifecycleRegistry`，
/// 即可接收 AppDelegate 转发的系统回调，无需直接耦合 AppDelegate。
public protocol AppLifecycleHandler: AnyObject {
    
    /// 处理 URL 打开事件（SSO 回调、Deep Link 等）
    ///
    /// - Parameters:
    ///   - url: 系统传入的 URL
    ///   - options: 附加选项
    /// - Returns: `true` 表示已处理该 URL（后续 handler 将不再收到）；`false` 跳过
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool
    
    /// App 完成启动
    func applicationDidFinishLaunching(_ application: UIApplication)
    
    /// App 即将进入前台
    func applicationWillEnterForeground(_ application: UIApplication)
    
    /// App 已进入后台
    func applicationDidEnterBackground(_ application: UIApplication)
    
    /// 收到远程推送 DeviceToken
    func applicationDidRegisterForRemoteNotifications(deviceToken: Data)
}

/// 为所有方法提供默认空实现，模块只需实现自己关心的回调
public extension AppLifecycleHandler {
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool { return false }
    func applicationDidFinishLaunching(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {}
}

// MARK: - Registry

/// App 生命周期回调分发中心（单例）
///
/// AppDelegate 将系统回调转发到这里，Registry 按注册顺序分发给所有 handler。
public final class AppLifecycleRegistry {
    public static let shared = AppLifecycleRegistry()
    private init() {}
    
    /// 弱引用包装，避免 Registry 持有模块导致内存泄漏
    private struct WeakHandler {
        weak var value: AppLifecycleHandler?
    }
    
    private var handlers: [WeakHandler] = []
    
    // MARK: - 注册 / 注销
    
    /// 注册 handler（弱引用持有，模块释放后自动移除）
    public func register(_ handler: AppLifecycleHandler) {
        // 去重：同一实例不重复注册
        cleanUp()
        guard !handlers.contains(where: { $0.value === handler }) else { return }
        handlers.append(WeakHandler(value: handler))
    }
    
    /// 手动注销 handler（可选，正常情况下弱引用会自动清理）
    public func unregister(_ handler: AppLifecycleHandler) {
        handlers.removeAll { $0.value === handler }
    }
    
    // MARK: - 分发方法（由 AppDelegate 调用）
    
    /// 分发 URL 打开事件
    ///
    /// 按注册顺序调用，任一 handler 返回 `true` 即短路。
    @discardableResult
    public func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        cleanUp()
        for wrapper in handlers {
            if let handler = wrapper.value, handler.handleOpenURL(url, options: options) {
                return true
            }
        }
        return false
    }
    
    /// 分发 Scene 维度的 URL 打开事件（`scene(_:openURLContexts:)` / `connectionOptions.urlContexts`）
    ///
    /// 把 `UIOpenURLContext` 的拆解（URL + options 字典映射）封装在 Login 模块内部，
    /// 壳工程的 SceneDelegate 直接传入 `Set<UIOpenURLContext>` 即可，
    /// 无需关心如何把 `UIOpenURLContext.options` 翻译成 `UIApplication.OpenURLOptionsKey` 字典。
    ///
    /// - Parameter contexts: 系统投递的 URL 上下文集合
    /// - Returns: 集合中**至少有一个** URL 被某个 handler 消费时返回 `true`；否则 `false`，
    ///   壳工程可据此决定是否继续把 URL 喂给其它非生命周期通道（如埋点 SDK）。
    @discardableResult
    public func handleOpenURLContexts(_ contexts: Set<UIOpenURLContext>) -> Bool {
        var consumedAny = false
        for context in contexts {
            let options: [UIApplication.OpenURLOptionsKey: Any] = [
                .sourceApplication: context.options.sourceApplication as Any,
                .annotation: context.options.annotation as Any,
                .openInPlace: context.options.openInPlace,
            ]
            if handleOpenURL(context.url, options: options) {
                consumedAny = true
            }
        }
        return consumedAny
    }
    
    /// 分发 App 完成启动事件
    public func applicationDidFinishLaunching(_ application: UIApplication) {
        cleanUp()
        handlers.forEach { $0.value?.applicationDidFinishLaunching(application) }
    }
    
    /// 分发 App 即将进入前台
    public func applicationWillEnterForeground(_ application: UIApplication) {
        cleanUp()
        handlers.forEach { $0.value?.applicationWillEnterForeground(application) }
    }
    
    /// 分发 App 已进入后台
    public func applicationDidEnterBackground(_ application: UIApplication) {
        cleanUp()
        handlers.forEach { $0.value?.applicationDidEnterBackground(application) }
    }
    
    /// 分发远程推送 DeviceToken
    public func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        cleanUp()
        handlers.forEach { $0.value?.applicationDidRegisterForRemoteNotifications(deviceToken: deviceToken) }
    }
    
    // MARK: - Private
    
    /// 清理已释放的弱引用
    private func cleanUp() {
        handlers.removeAll { $0.value == nil }
    }
}
