//
//  RoomModule.swift
//  main
//

import Login
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
                let vc = RoomHomeViewController()
                vc.onLoggedOut = { [weak vc] in
                    LoginEntry.shared.logout { _ in
                        DispatchQueue.main.async {
                            AppAssembly.shared.showLoginHandler?()
                            vc?.navigationController?.popToRootViewController(animated: false)
                        }
                    }
                }
                return vc
            },
            analyticsEvent: "conference",
            keyMetricsEvent: Constants.DataReport.kDataReportDemoClickRoom
        )
        return RoomModule(config: config)
    }
}
