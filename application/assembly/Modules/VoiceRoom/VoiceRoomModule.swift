//
//  VoiceRoomModule.swift
//  main
//
//  语聊房模块
//

import Combine
import Login
import TUILiveKit
import UIKit

// MARK: - VoiceRoomModule

/// VoiceRoom 模块入口
final class VoiceRoomModule: ModuleProvider {
    let config: ModuleConfig
    private var environment: ModuleEnvironment?
    private var cancellable: AnyCancellable?

    init(config: ModuleConfig) {
        self.config = config
        AtomicXCoreLogin.shared.startAutoLogin()
    }

    func setup(with environment: ModuleEnvironment) {
        self.environment = environment
        startKaraokeAutoSetup()
    }

    /// 便捷工厂方法，使用默认配置创建 VoiceRoomModule
    static var standard: VoiceRoomModule {
        let config = ModuleConfig(
            identifier: "voice_chat",
            title: VoiceRoomLocalize("assembly_voiceroom_card_title"),
            description: VoiceRoomLocalize("assembly_voiceroom_card_description"),
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

// MARK: - Karaoke Configuration

extension VoiceRoomModule {
    /// 监听登录状态，登录成功后初始化 KaraokeConfig 并注入网络版曲库服务
    ///
    /// 参考 AtomicXCoreLogin 的模式：在 userModel 变更时读取当前 config，
    /// 确保 sdkAppId/secretKey 是登录完成后的最终值（switchConfig 已执行完毕）。
    private func startKaraokeAutoSetup() {
        guard cancellable == nil else { return }
        cancellable = LoginEntry.shared.$userModel
            .receive(on: RunLoop.main)
            .removeDuplicates(by: { lhs, rhs in
                lhs?.userId == rhs?.userId
            })
            .sink { [weak self] userModel in
                guard let self = self else { return }
                if userModel != nil {
                    let config = LoginEntry.shared.config
                    KaraokeConfig.shared.updateConfig(
                        SDKAPPID: Int32(config.sdkAppId),
                        SECRETKEY: config.secretKey
                    )
                    let licenseKey = self.environment?.copyrightedMusicLicenseKey ?? ""
                    let licenseUrl = self.environment?.copyrightedMusicLicenseUrl ?? ""
                    MusicCatalogServiceManager.shared.setService(
                        MusicCatalogServiceImpl(
                            copyrightedLicenseKey: licenseKey,
                            copyrightedLicenseUrl: licenseUrl
                        )
                    )
                } else {
                    MusicCatalogServiceManager.shared.resetToDefault()
                }
            }
    }
}
