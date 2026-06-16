//
//  LiveModule.swift
//  main
//
//  直播模块
//

import AtomicXCore
import Combine
import TUILiveKit
import UIKit

#if canImport(TCMediaX)
import TCMediaX
#endif

// MARK: - LiveModule

/// Live 模块入口
final class LiveModule: ModuleProvider {
    let config: ModuleConfig
    private var environment: ModuleEnvironment?

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
        // 注册房间内高风险 IP 用户 IM 消息监听（Live/Call 共用，V2TIMManager 自动去重）
        RoomRiskIPObserver.shared.register()
    }

    func setup(with environment: ModuleEnvironment) {
        self.environment = environment
    }

    /// 便捷工厂方法，使用默认配置创建 LiveModule
    /// - Parameter target: 当前构建目标。
    ///   - `.overseas`（TencentRTC）：先进入 `LiveEntranceViewController` 二级入口（Live / Voice Room 二选一）；
    ///   - `.domestic` / `.lab`：直接进入 `LiveListViewController` 直播列表。
    static func standard(target: AppTarget) -> LiveModule {
        // 使用 Box 让 targetProvider 闭包能访问模块实例的 environment
        class EnvironmentBox {
            weak var module: LiveModule?
        }
        let box = EnvironmentBox()

        let config = ModuleConfig(
            identifier: "live",
            title: LiveLocalize("assembly_live_card_title"),
            description: LiveLocalize("assembly_live_card_description"),
            iconName: "main_entrance_tuilivekit",
            iconImage: AppAssemblyBundle.image(named: "main_entrance_tuilivekit"),
            cardStyle: .uiComponent,
            gradientColors: stubUIComponentGradient,
            targetProvider: {
                box.module?.initLicenseIfNeeded()
                switch target {
                case .overseas:
                    return LiveEntranceViewController()
                case .domestic, .lab:
                    return LiveListViewController()
                }
            },
            analyticsEvent: "live_streaming",
            keyMetricsEvent: Constants.DataReport.kDataReportDemoClickLive
        )
        let module = LiveModule(config: config)
        box.module = module
        return module
    }

    /// 初始化 License（由外部在合适时机调用）
    func initLicenseIfNeeded() {
        Self.initLicense(with: environment)
    }
}

// MARK: - License

extension LiveModule {
    private static func initLicense(with environment: ModuleEnvironment?) {
        callTEBeautyKitSetLicense(with: environment)

        #if canImport(TCMediaX)
        if let url = environment?.playerLicenseURL, let key = environment?.playerLicenseKey,
           !url.isEmpty, !key.isEmpty {
            TCMediaXBase.getInstance().setLicenceURL(url, key: key)
        }
        #endif
    }

    private static func callTEBeautyKitSetLicense(with environment: ModuleEnvironment?) {
        guard let env = environment, !env.effectLicenseURL.isEmpty, !env.effectLicenseKey.isEmpty else {
            debugPrint(" effectLicense 未配置，跳过美颜 License 设置")
            return
        }

        guard let teBeautyKitClass = NSClassFromString("TEBeautyKit") as? NSObject.Type else {
            debugPrint("TEBeautyKit class not found")
            return
        }

        let setLicenseSelector = NSSelectorFromString("setTELicense:key:completion:")

        if teBeautyKitClass.responds(to: setLicenseSelector) {
            typealias SetLicenseFunction = @convention(c)
                (AnyClass, Selector, NSString, NSString, @escaping (Int, String?) -> Void) -> Void

            let method = class_getClassMethod(teBeautyKitClass, setLicenseSelector)
            if let method = method {
                let implementation = method_getImplementation(method)
                let function = unsafeBitCast(implementation, to: SetLicenseFunction.self)
                function(
                    teBeautyKitClass, setLicenseSelector,
                    env.effectLicenseURL as NSString,
                    env.effectLicenseKey as NSString
                ) { code, message in
                    debugPrint("TEBeautyKit license set with code: \(code), message: \(message ?? "nil")")
                    callTEUIConfigSetPanelLevel()
                }
            }
        }
    }

    private static func callTEUIConfigSetPanelLevel() {
        guard let teUIConfigClass = NSClassFromString("TEUIConfig") as? NSObject.Type else { return }

        let shareInstanceSelector = NSSelectorFromString("shareInstance")
        if teUIConfigClass.responds(to: shareInstanceSelector) {
            typealias ShareInstanceFunction = @convention(c) (AnyClass, Selector) -> AnyObject?

            let method = class_getClassMethod(teUIConfigClass, shareInstanceSelector)
            if let method = method {
                let implementation = method_getImplementation(method)
                let function = unsafeBitCast(implementation, to: ShareInstanceFunction.self)

                if let instance = function(teUIConfigClass, shareInstanceSelector) {
                    let setPanelLevelSelector = NSSelectorFromString("setPanelLevel:")
                    if instance.responds(to: setPanelLevelSelector) {
                        typealias SetPanelLevelFunction = @convention(c) (AnyObject, Selector, Int) -> Void

                        let instanceMethod = class_getInstanceMethod(type(of: instance), setPanelLevelSelector)
                        if let instanceMethod = instanceMethod {
                            let impl = method_getImplementation(instanceMethod)
                            let fn = unsafeBitCast(impl, to: SetPanelLevelFunction.self)
                            fn(instance, setPanelLevelSelector, 14)
                        }
                    }
                }
            }
        }
    }
}
