//
//  CallModule.swift
//  main
//
//  通话模块
//

import Combine
import TUICallKit_Swift
import TUILiveKit
import UIKit

// MARK: - CallModule

/// Call 模块入口
final class CallModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
        // 注册 TUICallKit 生命周期处理（悬浮窗、虚拟背景、来电横幅、AI转写）
        CallKitLifecycleHandler.shared.register()
        // 注册通话反诈提示（事件监听；反诈 UI 由 AppAssembly 通过闭包注入）
        CallAntifraudHandler.shared.register()
        // 注册房间内高风险 IP 用户 IM 消息监听（Live/Call 共用，V2TIMManager 自动去重）
        RoomRiskIPObserver.shared.register()
    }

    /// 便捷工厂方法，使用默认配置创建 CallModule
    /// - Parameter target: 当前构建目标，Lab 版使用 CallViewController，其余使用 CallingEntranceMenuViewController
    static func standard(target: AppTarget) -> CallModule {
        let config = ModuleConfig(
            identifier: "call",
            title: CallingLocalize("assembly_call_card_title"),
            description: CallingLocalize("assembly_call_card_description"),
            iconName: "main_entrance_tuicallkit",
            iconImage: AppAssemblyBundle.image(named: "main_entrance_tuicallkit"),
            cardStyle: .uiComponent,
            gradientColors: stubUIComponentGradient,
            targetProvider: {
                switch target {
                case .lab:
                    return CallViewController()
                case .domestic, .overseas:
                    return CallingEntranceMenuViewController()
                }
            },
            analyticsEvent: "video_call",
            keyMetricsEvent: Constants.DataReport.kDataReportDemoClickCall
        )
        return CallModule(config: config)
    }
}
