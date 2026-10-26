import TUIChatKit
import Combine
import UIKit

extension HomeTabBarController {
    private static let tabTitleFontSize: CGFloat = 10
    private static let tabIconGradientStart = CGPoint(x: 0.66, y: -0.33)
    private static let tabIconGradientEnd = CGPoint(x: -0.24, y: 0.6875)
    private static let assistantIconViewportSize: CGFloat = 24
    private static let assistantStarPoints: [CGPoint] = [
        CGPoint(x: 12, y: 2), CGPoint(x: 14.09, y: 8.26), CGPoint(x: 20.5, y: 8.5),
        CGPoint(x: 15.45, y: 12.47), CGPoint(x: 17.18, y: 18.7), CGPoint(x: 12, y: 15.1),
        CGPoint(x: 6.82, y: 18.7), CGPoint(x: 8.55, y: 12.47), CGPoint(x: 3.5, y: 8.5),
        CGPoint(x: 9.91, y: 8.26)
    ]
    private static let assistantSparklePoints: [CGPoint] = [
        CGPoint(x: 19, y: 15), CGPoint(x: 19.94, y: 17.06), CGPoint(x: 22, y: 18),
        CGPoint(x: 19.94, y: 18.94), CGPoint(x: 19, y: 21), CGPoint(x: 18.06, y: 18.94),
        CGPoint(x: 16, y: 18), CGPoint(x: 18.06, y: 17.06)
    ]

    internal func observeThemeChanges() {
        ThemeState.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTabBarAppearance()
            }
            .store(in: &cancellables)
    }

    internal func updateTabBarAppearance() {
        let themeColors = ThemeState.shared.colors
        let tertiaryColor = themeColors.textColorTertiary
        let linkColor = themeColors.textColorLink
        let titleFont = UIFont.systemFont(ofSize: Self.tabTitleFontSize)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = themeColors.bgColorTopBar
        appearance.shadowColor = .clear
        appearance.selectionIndicatorTintColor = .clear
        let itemAppearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        for itemAppearance in itemAppearances {
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: tertiaryColor, .font: titleFont]
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: linkColor, .font: titleFont]
        }
        tabBar.isTranslucent = false
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = linkColor
        tabBar.unselectedItemTintColor = tertiaryColor
        renderTabIcons()
        refreshUnreadBadgesAfterTabLayout()
        if messageUnreadBadge.superview === tabBar {
            tabBar.bringSubviewToFront(messageUnreadBadge)
        }
    }

    private func renderTabIcons() {
        for (index, page) in (viewControllers ?? []).enumerated() {
            guard index < Self.tabIconBaseNames.count else { continue }
            let baseName = Self.tabIconBaseNames[index]
            let cutoutName = baseName == "tab_chat" ? "tab_chat_lines" : nil
            page.tabBarItem.image = renderTabIcon(baseName: baseName, cutoutName: cutoutName, selected: false)
            page.tabBarItem.selectedImage = renderTabIcon(baseName: baseName, cutoutName: cutoutName, selected: true)
        }
    }

    private func renderTabIcon(baseName: String, cutoutName: String?, selected: Bool) -> UIImage? {
        let baseImage: CGImage?
        if baseName == "tab_ai" {
            baseImage = Self.renderAssistantIconMask(size: Self.tabIconSize)?.cgImage
        } else {
            baseImage = UIImage(named: baseName)?.cgImage
        }
        guard let base = baseImage else { return nil }
        let size = CGSize(width: Self.tabIconSize, height: Self.tabIconSize)
        let colors = ThemeState.shared.colors
        let fill: UIImage
        if selected {
            fill = gradientFillImage(
                size: size,
                colors: [colors.bgColorBubbleOwn.cgColor, colors.textColorLink.cgColor]
            )
        } else {
            fill = solidFillImage(size: size, color: colors.textColorTertiary)
        }
        var image = maskedImage(fill: fill, mask: base, size: size)
        if let cutoutName, let cutout = UIImage(named: cutoutName)?.cgImage {
            let cutoutFill = solidFillImage(size: size, color: colors.bgColorBottomBar)
            let cutoutImage = maskedImage(fill: cutoutFill, mask: cutout, size: size)
            image = compositeImage(bottom: image, top: cutoutImage, size: size)
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    private func solidFillImage(size: CGSize, color: UIColor) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func gradientFillImage(size: CGSize, colors: [CGColor]) -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(origin: .zero, size: size)
        gradientLayer.colors = colors
        gradientLayer.startPoint = Self.tabIconGradientStart
        gradientLayer.endPoint = Self.tabIconGradientEnd
        return UIGraphicsImageRenderer(size: size).image { context in
            gradientLayer.render(in: context.cgContext)
        }
    }

    private func maskedImage(fill: UIImage, mask: CGImage, size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            let rect = CGRect(origin: .zero, size: size)
            cgContext.clip(to: rect, mask: mask)
            if let fillImage = fill.cgImage {
                cgContext.draw(fillImage, in: rect)
            }
        }
    }

    private func compositeImage(bottom: UIImage, top: UIImage, size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            bottom.draw(in: CGRect(origin: .zero, size: size))
            top.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func renderAssistantIconMask(size: CGFloat) -> UIImage? {
        let scale = size / assistantIconViewportSize
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            UIColor.black.setFill()
            for points in [assistantStarPoints, assistantSparklePoints] {
                scaledIconPath(points: points, scale: scale).fill()
            }
        }
    }

    private static func scaledIconPath(points: [CGPoint], scale: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let scaledPoint = CGPoint(x: point.x * scale, y: point.y * scale)
            if index == 0 {
                path.move(to: scaledPoint)
            } else {
                path.addLine(to: scaledPoint)
            }
        }
        path.close()
        return path
    }
}
