//
//  CallKitLifecycleHandler.swift
//  Call
//
//    CallKitLifecycleHandler.shared.register()
//

import UIKit
import TUICallKit_Swift
import TUICore
import Login

// MARK: - CallKitLifecycleHandler

final class CallKitLifecycleHandler: NSObject, AppLifecycleHandler {

    static let shared = CallKitLifecycleHandler()
    private override init() { super.init() }

    func register() {
        AppLifecycleRegistry.shared.register(self)
        addTUILoginSuccessObserver()
    }
}

// MARK: - TUICallKit Configuration

private extension CallKitLifecycleHandler {

    func addTUILoginSuccessObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTUILoginSuccess),
            name: NSNotification.Name.TUILoginSuccess,
            object: nil
        )
    }

    @objc func handleTUILoginSuccess() {
        let callKit = TUICallKit.createInstance()
        callKit.enableFloatWindow(enable: SettingsConfig.share.floatWindow)
        callKit.enableVirtualBackground(enable: SettingsConfig.share.enableVirtualBackground)
        callKit.enableIncomingBanner(enable: SettingsConfig.share.enableIncomingBanner)
        callKit.enableAITranscriber(enable: SettingsConfig.share.enableAITranscriber)
        debugPrint(" TUICallKit 全局配置已完成")
    }
}
