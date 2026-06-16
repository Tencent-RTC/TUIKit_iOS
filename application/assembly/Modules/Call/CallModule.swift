//
//  CallModule.swift
//  main
//

import Combine
import TUICallKit_Swift
import TUILiveKit
import UIKit

// MARK: - CallModule

final class CallModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
        CallKitLifecycleHandler.shared.register()
        CallAntifraudHandler.shared.register()
        RoomRiskIPObserver.shared.register()
    }

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
