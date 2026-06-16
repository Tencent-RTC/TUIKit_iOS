//
//  RoomModule.swift
//  main
//
//  多人房间模块
//

import TUILiveKit
import TUIRoomKit
import UIKit

// MARK: - RoomModule

/// Room 模块入口
final class RoomModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
    }

    /// 便捷工厂方法，使用默认配置创建 RoomModule
    static var standard: RoomModule {
        let config = ModuleConfig(
            identifier: "room",
            title: RoomLocalize("assembly_room_card_title"),
            description: RoomLocalize("assembly_room_card_description"),
            iconName: "main_entrance_tuiroom",
            iconImage: AppAssemblyBundle.image(named: "main_entrance_tuiroom"),
            cardStyle: .uiComponent,
            gradientColors: [],
            targetProvider: {
                // 通话中禁止进入 Room 入口（会议创建入口在 SDK 内部无法精确拦截，
                // 采用粗粒度：通话中整个 Room 入口禁用并 Toast）
                guard AppAssembly.shared.canStartNewRoom else {
                    AppAssembly.shared.showCannotStartRoomToast()
                    return nil
                }
                return RoomHomeViewController()
            },
            analyticsEvent: "conference",
            keyMetricsEvent: Constants.DataReport.kDataReportDemoClickRoom
        )
        return RoomModule(config: config)
    }
}

