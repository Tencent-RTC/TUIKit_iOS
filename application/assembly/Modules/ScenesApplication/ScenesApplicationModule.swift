//
//  ScenesApplicationModule.swift
//  AppAssembly
//

import UIKit

// MARK: - ScenesApplicationModule

final class ScenesApplicationModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
    }

    static let moduleIdentifier = "scenes_application"

    static var standard: ScenesApplicationModule {
        let config = ModuleConfig(
            identifier: moduleIdentifier,
            title: AssemblyLocalize("assembly_scenes_application_card_title"),
            description: AssemblyLocalize("assembly_scenes_application_card_description"),
            iconName: "",
            cardStyle: .banner,
            gradientColors: stubUIComponentGradient,
            targetProvider: { nil },
            analyticsEvent: ""
        )
        return ScenesApplicationModule(config: config)
    }
}
