//
//  LiveModule.swift
//  main
//

import AtomicXCore
import Combine
import TUILiveKit
import UIKit

#if canImport(TCMediaX)
import TCMediaX
#endif

// MARK: - LiveModule

final class LiveModule: ModuleProvider {
    let config: ModuleConfig
    private var environment: ModuleEnvironment?

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
        RoomRiskIPObserver.shared.register()
    }

    func setup(with environment: ModuleEnvironment) {
        self.environment = environment
    }

    static var standard: LiveModule {
        class EnvironmentBox {
            weak var module: LiveModule?
        }
        let box = EnvironmentBox()

        let config = ModuleConfig(
            identifier: "live",
            title: AssemblyLocalize("Demo.TRTC.Portal.Main.live"),
            description: AssemblyLocalize("Demo.TRTC.Portal.Main.liveContent"),
            iconName: "main_entrance_tuilivekit",
            iconImage: AppAssemblyBundle.image(named: "main_entrance_tuilivekit"),
            cardStyle: .uiComponent,
            gradientColors: stubUIComponentGradient,
            targetProvider: {
                box.module?.initLicenseIfNeeded()
                return LiveListViewController()
            },
            analyticsEvent: "live_streaming"
        )
        let module = LiveModule(config: config)
        box.module = module
        return module
    }

    func initLicenseIfNeeded() {
        Self.initLicense(with: environment)
    }
}

// MARK: - License

extension LiveModule {
    private static func initLicense(with environment: ModuleEnvironment?) {
        callTEBeautyKitSetLicense(with: environment)

        #if canImport(TCMediaX)
        if let url = environment?.beautyLicenseURL, let key = environment?.beautyLicenseKey,
           !url.isEmpty, !key.isEmpty {
            TCMediaXBase.getInstance().setLicenceURL(url, key: key)
        }
        #endif
    }

    private static func callTEBeautyKitSetLicense(with environment: ModuleEnvironment?) {
        guard let env = environment, !env.beautyLicenseURL.isEmpty, !env.beautyLicenseKey.isEmpty else {
            debugPrint(" beautyLicense 未配置，跳过美颜 License 设置")
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
                    env.beautyLicenseURL as NSString,
                    env.beautyLicenseKey as NSString
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
