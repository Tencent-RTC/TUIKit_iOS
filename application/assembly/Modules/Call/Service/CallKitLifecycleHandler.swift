//
//  CallKitLifecycleHandler.swift
//  Call
//
//  TUICallKit 全局配置 — 通过 AppLifecycleRegistry 接入 App 生命周期
//
//  职责：
//    - 监听 TUILogin 成功通知
//    - 登录成功后统一配置 TUICallKit（悬浮窗、虚拟背景、来电横幅、AI转写）
//
//  使用方式：
//    CallKitLifecycleHandler.shared.register()
//    → 内部会自注册到 AppLifecycleRegistry
//    → 在 applicationDidFinishLaunching 时添加 TUILoginSuccess 观察者
//

import UIKit
import TUICallKit_Swift
import TUICore
import Login

// MARK: - CallKitLifecycleHandler

/// TUICallKit 全局配置管理器
///
/// 通过 `AppLifecycleHandler` 协议接入 App 生命周期，
/// 在 `didFinishLaunching` 时注册 TUILoginSuccess 监听，
/// 登录成功后自动配置 TUICallKit。
final class CallKitLifecycleHandler: NSObject, AppLifecycleHandler {

    static let shared = CallKitLifecycleHandler()
    private override init() { super.init() }

    /// 注册到 AppLifecycleRegistry，由 CallModule 初始化时调用
    func register() {
        AppLifecycleRegistry.shared.register(self)
        addTUILoginSuccessObserver()
    }
}

// MARK: - TUICallKit Configuration

private extension CallKitLifecycleHandler {

    /// 监听 TUILogin 成功通知
    func addTUILoginSuccessObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTUILoginSuccess),
            name: NSNotification.Name.TUILoginSuccess,
            object: nil
        )
    }

    /// TUILogin 成功后配置 TUICallKit
    ///
    /// 对应旧版 AppDelegate 中 `tuiLoginSuccessNotification()` 的功能：
    ///   - 开启悬浮窗（通话最小化后显示浮窗）
    ///   - 开启虚拟背景
    ///   - 开启来电横幅（收到来电时顶部弹出横幅）
    ///   - 开启 AI 转写
    @objc func handleTUILoginSuccess() {
        let callKit = TUICallKit.createInstance()
        callKit.enableFloatWindow(enable: SettingsConfig.share.floatWindow)
        callKit.enableVirtualBackground(enable: SettingsConfig.share.enableVirtualBackground)
        callKit.enableIncomingBanner(enable: SettingsConfig.share.enableIncomingBanner)
        callKit.enableAITranscriber(enable: SettingsConfig.share.enableAITranscriber)
        debugPrint(" TUICallKit 全局配置已完成")
    }
}
