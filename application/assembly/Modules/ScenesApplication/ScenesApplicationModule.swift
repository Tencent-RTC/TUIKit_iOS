//
//  ScenesApplicationModule.swift
//  AppAssembly
//
//  行业场景实践模块入口（通栏 banner 卡片）
//
//  ⚠️ 跳转策略由壳工程决定：assembly 不感知 target，只暴露卡片。
//     - 国内/Lab：`EntranceViewController` 拦截 identifier 打开外链
//     - 海外（TencentRTC）：`OverseasMainViewController` 拦截 identifier
//        push 壳工程内的 `MiniProgramViewController`（依赖 TCMPPSDK，
//        仅在 TencentRTC target 接入）
//
//  约定：识别号 `scenes_application` 是壳工程拦截跳转的唯一 key。
//

import UIKit

// MARK: - ScenesApplicationModule

/// 行业场景实践模块（通栏 banner 卡片）
///
/// `targetProvider` 故意返回 nil —— 由壳工程基于 `config.identifier`
/// 拦截点击事件并执行跳转。
final class ScenesApplicationModule: ModuleProvider {
    let config: ModuleConfig

    init(config: ModuleConfig) {
        self.config = config
    }

    /// 模块识别号 — 壳工程基于此拦截跳转
    static let moduleIdentifier = "scenes_application"

    /// 便捷工厂方法
    static var standard: ScenesApplicationModule {
        let config = ModuleConfig(
            identifier: moduleIdentifier,
            title: AssemblyLocalize("assembly_scenes_application_card_title"),
            description: AssemblyLocalize("assembly_scenes_application_card_description"),
            iconName: "",
            cardStyle: .banner,
            gradientColors: stubUIComponentGradient,
            // 由壳工程基于 identifier 拦截跳转，此处不返回任何 VC
            targetProvider: { nil },
            analyticsEvent: ""
        )
        return ScenesApplicationModule(config: config)
    }
}
