//
//  RoomModule.swift
//  main
//

import TUILiveKit
import TUIRoomKit
import UIKit

// MARK: - RoomModule

final class RoomModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
    }

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
