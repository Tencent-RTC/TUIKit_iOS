//
//  ModuleConfig.swift
//  AppAssembly
//
//  模块配置数据模型 — 描述一个首页入口卡片的全部信息
//

import TUILiveKit
import UIKit

/// 模块配置 — 描述一个首页入口卡片的全部信息
///
/// 每个业务模块通过 `ModuleProvider` 提供一个 `ModuleConfig`，
/// 首页根据此配置渲染卡片 UI 和处理点击跳转。
public struct ModuleConfig {
    /// 唯一标识（用于权限控制、埋点、去重）
    public let identifier: String

    /// 卡片标题
    public let title: String

    /// 卡片描述文字
    public let description: String

    /// 图标名（xcassets 中的图片名，也支持 http URL）
    public let iconName: String

    /// 预加载的图标图片（优先级高于 iconName，用于跨 Bundle 加载）
    public let iconImage: UIImage?

    /// 卡片样式
    public let cardStyle: EntranceCardStyle

    /// 渐变背景色（uiComponent/banner 样式使用）
    public let gradientColors: [UIColor]

    /// 是否显示"热门"标签
    public let isHot: Bool

    /// 点击后创建的目标 VC（闭包延迟创建，避免提前 import 业务模块）
    ///
    /// 注：实际存储的是经过 `init` 包装后的闭包——若 `keyMetricsEvent != nil`，
    /// 包装层会在调用原始闭包前先发起 `KeyMetrics.reportAtomicMetrics`，
    /// 实现 SDK 集成度量上报的统一收拢，外部首页无感知。
    public let targetProvider: () -> UIViewController?

    /// 埋点事件名
    public let analyticsEvent: String

    /// KeyMetrics 集成度量事件 ID（对应 TUILiveKit `Constants.DataReport.kDataReport*`）
    ///
    /// 与 `analyticsEvent`（神策侧产品口径）并行的"SDK 集成度量"通道——上报到 IM 后台，
    /// 用于统计 demo 工程对 atomic-x 各 UI 组件的点击转化率。
    /// 默认 `nil` 表示不上报，与 Android 端 `MainTypeEnum.reportEvent: Int = -1` 语义对齐。
    public let keyMetricsEvent: Int?

    public init(identifier: String,
                title: String,
                description: String,
                iconName: String,
                iconImage: UIImage? = nil,
                cardStyle: EntranceCardStyle,
                gradientColors: [UIColor] = [],
                isHot: Bool = false,
                targetProvider: @escaping () -> UIViewController?,
                analyticsEvent: String = "",
                keyMetricsEvent: Int? = nil) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.iconName = iconName
        self.iconImage = iconImage
        self.cardStyle = cardStyle
        self.gradientColors = gradientColors
        self.isHot = isHot
        self.analyticsEvent = analyticsEvent
        self.keyMetricsEvent = keyMetricsEvent

        // 用 KeyMetrics 上报装饰原始 targetProvider，实现"单一上报点"
        // 注：上报放在原始闭包**之前**——与 Android `MainFragment.onItemClick` 中
        // `KeyMetrics.reportAtomicMetrics(...)` 早于 `Intent` 构造的顺序对齐。
        if let event = keyMetricsEvent {
            self.targetProvider = {
                KeyMetrics.reportAtomicMetrics(platform: event)
                return targetProvider()
            }
        } else {
            self.targetProvider = targetProvider
        }
    }
}

