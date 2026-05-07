//
//  VoiceRoomModule.swift
//  main
//

import UIKit
import TUILiveKit

// MARK: - VoiceRoomModule

final class VoiceRoomModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
    }

    static var standard: VoiceRoomModule {
        let config = ModuleConfig(
            identifier: "voice_chat",
            title: AssemblyLocalize("Demo.TRTC.Portal.Main.VoiceRoom"),
            description: AssemblyLocalize("Demo.TRTC.Portal.Main.VoiceRoomContent"),
            iconName: "main_entrance_voice_room",
            iconImage: AppAssemblyBundle.image(named: "main_entrance_voice_room"),
            cardStyle: .standard,
            gradientColors: [],
            targetProvider: {
                VoiceRoomViewController()
            },
            analyticsEvent: "voice_room"
        )
        return VoiceRoomModule(config: config)
    }
}
