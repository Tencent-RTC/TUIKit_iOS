//
//  ModuleConfig.swift
//  AppAssembly
//

import TUILiveKit
import UIKit

public struct ModuleConfig {
    public let identifier: String

    public let title: String

    public let description: String

    public let iconName: String

    public let iconImage: UIImage?

    public let cardStyle: EntranceCardStyle

    public let gradientColors: [UIColor]

    public let isHot: Bool

    public let targetProvider: () -> UIViewController?

    public let analyticsEvent: String

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
