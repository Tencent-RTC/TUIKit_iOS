//
//  ScenesApplicationModule.swift
//  main
//

import UIKit

// MARK: - ScenesApplicationModule

final class ScenesApplicationModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
    }

    // MARK: - Constants

    private static let exhibitionURL = "https://trtc.io/exhibition/details?lang=zh&from=app"

    static var standard: ScenesApplicationModule {
        let config = ModuleConfig(
            identifier: "scenes_application",
            title: AssemblyLocalize("Demo.TRTC.Portal.Main.IndustryScenarioPractice"),
            description: AssemblyLocalize("Demo.TRTC.Portal.Main.Exploremore"),
            iconName: "",
            cardStyle: .banner,
            gradientColors: stubUIComponentGradient,
            targetProvider: {
                if let url = URL(string: ScenesApplicationModule.exhibitionURL) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                return nil
            },
            analyticsEvent: ""
        )
        return ScenesApplicationModule(config: config)
    }
}
