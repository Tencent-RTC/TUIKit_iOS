//
//  RoomModule.swift
//  main
//

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
            title: AssemblyLocalize("Demo.TRTC.Portal.Main.tuiRoom"),
            description: AssemblyLocalize("Demo.TRTC.Portal.Main.tuiRoomContent"),
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
            analyticsEvent: "conference"
        )
        return RoomModule(config: config)
    }
}
