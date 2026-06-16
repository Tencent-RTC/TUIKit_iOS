//
//  EntranceCollectionCell.swift
//  main
//
//  模块入口卡片 Cell — 从旧版 EntranceCollectionCell.swift 迁移
//
//  变更说明：
//    - 数据源从 `MainMenuItemModel` 改为 `ResolvedModule`
//    - 三种卡片样式（standard / uiComponent / banner）对应旧版（default / ui_components / webview）
//    - 移除 `import RTCCommon`、`import TUICore` 直接依赖，改为内联辅助函数
//    - UI 布局和样式完全保持旧版不变
//

import UIKit
import SnapKit
import Kingfisher
import TUICore
import AtomicX
import AppAssembly

class EntranceCollectionCell: UICollectionViewCell {

    // MARK: - Properties

    private var gradientColors: [UIColor] = []
    private var cardStyle: EntranceCardStyle = .standard

    // MARK: - UI Elements

    let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius6
        view.layer.masksToBounds = true
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: convertPixel(w: 12))
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let hotLabel: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("main_hot_component")
        label.textColor = .white
        label.textAlignment = .center
        label.isHidden = true
        label.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(h: 12))
        label.backgroundColor = ThemeStore.shared.colorTokens.textColorWarning
        label.layer.cornerRadius = 2
        label.layer.masksToBounds = true
        return label
    }()

    private let uiComIconView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.textColorLink
        view.layer.cornerRadius = 2
        view.layer.masksToBounds = true
        return view
    }()

    private let uiComLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = UIImage(named: "main_entrance_pusharrow")
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "main_entrance_scenarios")
        imageView.isHidden = true
        return imageView
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(w: 17.0 - englishOffset))
        uiComLabel.font = UIFont(name: "PingFangSC-Semibold", size: convertPixel(w: 12.0 - englishOffset))
        if ScreenWidth <= 375.0 && isEnglishLanguage {
            uiComIconView.isHidden = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let layer = containerView.gradient(colors: gradientColors)
        if cardStyle == .banner {
            layer.startPoint = CGPoint(x: 0.0, y: 0.5)
            layer.endPoint = CGPoint(x: 1.0, y: 0.5)
        } else {
            layer.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        }
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        contentView.addSubview(containerView)
        containerView.addSubview(backgroundImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(iconImageView)
        uiComIconView.addSubview(uiComLabel)
        containerView.addSubview(uiComIconView)
        containerView.addSubview(arrowImageView)
        containerView.addSubview(descLabel)
        containerView.addSubview(hotLabel)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(convertPixel(h: 4))
            make.bottom.right.equalToSuperview().offset(convertPixel(h: -4))
        }

        backgroundImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(16)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(convertPixel(w: 6))
            make.right.equalTo(uiComIconView.snp.left).offset(convertPixel(w: -6))
            make.centerY.equalTo(iconImageView)
        }

        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalToSuperview().offset(-16)
            make.size.equalTo(CGSize(width: 16.0, height: 16.0))
        }

        uiComLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(4)
        }

        uiComIconView.snp.makeConstraints { make in
            make.left.equalTo(uiComLabel).offset(convertPixel(h: 6))
            make.bottom.top.equalTo(uiComLabel)
            make.centerY.equalTo(titleLabel)
        }

        descLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(convertPixel(w: 14))
            make.right.equalToSuperview().offset(convertPixel(w: -14))
            make.top.greaterThanOrEqualTo(iconImageView.snp.bottom).offset(convertPixel(h: 6))
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(convertPixel(h: 6))
            make.bottom.lessThanOrEqualToSuperview().offset(convertPixel(h: -8))
        }

        hotLabel.snp.makeConstraints { make in
            make.left.equalTo(uiComLabel).offset(convertPixel(h: 6))
            make.centerY.equalTo(titleLabel)
            make.height.equalTo(18)
            make.width.equalTo(32)
            make.right.lessThanOrEqualToSuperview().offset(-16)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: - Public Config

    /// 使用 ResolvedModule 配置 Cell
    func config(_ module: ResolvedModule) {
        self.cardStyle = module.config.cardStyle
        switch module.config.cardStyle {
        case .standard:
            setupStandardConfig(module)
        case .uiComponent:
            setupUIComponentConfig(module)
        case .banner:
            setupBannerConfig(module)
        }
    }

    // MARK: - Style Configuration

    private func setupStandardConfig(_ module: ResolvedModule) {
        let config = module.config
        titleLabel.text = config.title
        titleLabel.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(w: 17.0 - englishOffset))
        descLabel.text = config.description
        hotLabel.isHidden = !config.isHot
        uiComIconView.isHidden = true

        // 清除复用残留的渐变背景
        gradientColors = []
        containerView.gradientLayer?.removeFromSuperlayer()
        containerView.gradientLayer = nil
        containerView.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate

        setIconImage(name: config.iconName, preloaded: config.iconImage)

        iconImageView.snp.remakeConstraints { make in
            make.top.left.equalToSuperview().offset(16)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.remakeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(convertPixel(w: 6))
            if config.isHot {
                make.right.equalTo(hotLabel.snp.left).offset(convertPixel(w: -6 + englishOffset))
            } else {
                make.right.equalToSuperview()
            }
            make.centerY.equalTo(iconImageView)
        }

        arrowImageView.snp.remakeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalToSuperview().offset(-16)
            make.size.equalTo(CGSize(width: 16.0, height: 16.0))
        }

        descLabel.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(convertPixel(w: 14))
            make.right.equalToSuperview().offset(convertPixel(w: -14))
            make.top.greaterThanOrEqualTo(iconImageView.snp.bottom).offset(convertPixel(h: 6))
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(convertPixel(h: 6))
            make.bottom.lessThanOrEqualToSuperview().offset(convertPixel(h: -8))
        }

        arrowImageView.isHidden = true
        backgroundImageView.isHidden = true
    }

    private func setupUIComponentConfig(_ module: ResolvedModule) {
        let config = module.config
        if !config.gradientColors.isEmpty {
            gradientColors = config.gradientColors
            uiComLabel.text = MainLocalize("main_ui_component")
            containerView.gradientLayer?.colors = config.gradientColors
            containerView.gradient(colors: gradientColors, bounds: containerView.bounds, isVertical: true)
        }

        titleLabel.text = config.title
        titleLabel.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: convertPixel(w: 17.0 - englishOffset))
        descLabel.text = config.description
        hotLabel.isHidden = true
        uiComIconView.isHidden = (ScreenWidth <= 375.0 && isEnglishLanguage)

        setIconImage(name: config.iconName, preloaded: config.iconImage)

        iconImageView.snp.remakeConstraints { make in
            make.top.left.equalToSuperview().offset(16)
            make.width.height.equalTo(24)
        }

        arrowImageView.snp.remakeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalToSuperview().offset(-16)
            make.size.equalTo(CGSize(width: 16.0, height: 16.0))
        }

        titleLabel.snp.remakeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(convertPixel(w: 6))
            make.right.equalTo(uiComIconView.snp.left).offset(convertPixel(w: -6))
            make.centerY.equalTo(iconImageView)
        }

        descLabel.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(convertPixel(w: 14))
            make.right.equalToSuperview().offset(convertPixel(w: -14))
            make.top.greaterThanOrEqualTo(iconImageView.snp.bottom).offset(convertPixel(h: 6))
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(convertPixel(h: 6))
            make.bottom.lessThanOrEqualToSuperview().offset(convertPixel(h: -8))
        }

        arrowImageView.isHidden = true
        backgroundImageView.isHidden = true
    }

    private func setupBannerConfig(_ module: ResolvedModule) {
        let config = module.config
        if !config.gradientColors.isEmpty {
            gradientColors = config.gradientColors
            containerView.gradientLayer?.colors = config.gradientColors
            containerView.gradient(colors: gradientColors, bounds: containerView.bounds, isVertical: false)
        }

        titleLabel.text = config.title
        titleLabel.textColor = ThemeStore.shared.colorTokens.textColorLink
        titleLabel.font = ThemeStore.shared.typographyTokens.Medium14
        descLabel.text = config.description
        arrowImageView.isHidden = false
        uiComIconView.isHidden = true
        hotLabel.isHidden = true
        iconImageView.image = nil

        titleLabel.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(convertPixel(w: 16))
            make.right.equalToSuperview().offset(convertPixel(w: -12))
            make.centerY.equalToSuperview()
        }

        arrowImageView.snp.remakeConstraints { make in
            make.centerY.equalTo(descLabel.snp.centerY)
            make.leading.equalTo(descLabel.snp.trailing)
        }

        descLabel.snp.remakeConstraints { make in
            make.right.equalToSuperview().inset(convertPixel(w: 40))
            make.centerY.equalTo(titleLabel)
        }

        backgroundImageView.isHidden = false
    }

    // MARK: - Helpers

    private func setIconImage(name: String, preloaded: UIImage? = nil) {
        if let preloaded = preloaded {
            iconImageView.image = preloaded
        } else if name.hasPrefix("http"), let imageURL = URL(string: name) {
            iconImageView.kf.setImage(with: imageURL)
        } else {
            iconImageView.image = UIImage(named: name)
        }
    }

    private var englishOffset: CGFloat {
        return isEnglishLanguage ? 2 : 0
    }

    private var isEnglishLanguage: Bool {
        guard let language = TUIGlobalization.getPreferredLanguage() else {
            return false
        }
        return !language.contains("zh")
    }

    // MARK: - Static Height Calculation

    /// 计算卡片所需的动态高度（用于 UICollectionViewDelegateFlowLayout）
    /// - Parameters:
    ///   - module: 要展示的模块
    ///   - cellWidth: 单元格宽度
    /// - Returns: 所需高度（最小值为 106）
    static func calculateHeight(for module: ResolvedModule, cellWidth: CGFloat) -> CGFloat {
        let config = module.config

        if config.cardStyle == .banner {
            return 58
        }

        let isEnglish: Bool = {
            guard let language = TUIGlobalization.getPreferredLanguage() else { return false }
            return !language.contains("zh")
        }()
        let engOffset: CGFloat = isEnglish ? 2 : 0

        // Container inset: 4pt on each side (top + bottom)
        let containerVerticalInset: CGFloat = convertPixel(h: 4) * 2
        let containerWidth = cellWidth - convertPixel(h: 4) * 2

        // Top padding (icon top margin from container)
        let topPadding: CGFloat = 16
        // Icon height
        let iconHeight: CGFloat = 24

        // Calculate available title width
        let titleLeftOffset: CGFloat = 16 + 24 + convertPixel(w: 6) // iconLeft + iconWidth + gap
        var titleRightOffset: CGFloat = 0
        if config.cardStyle == .uiComponent {
            // UIKit badge approximate width (~40pt) + gap
            if !(ScreenWidth <= 375.0 && isEnglish) {
                titleRightOffset = 40 + convertPixel(w: 6)
            }
        } else if config.isHot {
            // Hot badge width(32) + gap
            titleRightOffset = 32 + convertPixel(w: 6 - engOffset)
        }
        let titleWidth = max(containerWidth - titleLeftOffset - titleRightOffset, 0)

        // Calculate title height
        let titleFontSize = convertPixel(w: 17.0 - engOffset)
        let titleFont = UIFont(name: "PingFangSC-Medium", size: titleFontSize)
            ?? UIFont.systemFont(ofSize: titleFontSize, weight: .medium)
        let titleHeight = Self.textHeight(config.title, font: titleFont, width: titleWidth, maxLines: 2)

        // Header area height: max of icon and title
        let headerHeight = max(iconHeight, titleHeight)

        // Spacing between header and description
        let spacing = convertPixel(h: 6)

        // Calculate description height
        let descHorizontalInset = convertPixel(w: 14) * 2
        let descWidth = max(containerWidth - descHorizontalInset, 0)
        let descFontSize = convertPixel(w: 12)
        let descFont = UIFont(name: "PingFangSC-Regular", size: descFontSize)
            ?? UIFont.systemFont(ofSize: descFontSize)
        let descHeight = Self.textHeight(config.description, font: descFont, width: descWidth, maxLines: 3)

        // Bottom padding
        let bottomPadding = convertPixel(h: 8)

        let totalHeight = containerVerticalInset + topPadding + headerHeight + spacing + descHeight + bottomPadding

        // Minimum height matches Android's 106dp
        return max(ceil(totalHeight), 106)
    }

    /// 计算文本在指定宽度和最大行数下的高度
    private static func textHeight(_ text: String, font: UIFont, width: CGFloat, maxLines: Int) -> CGFloat {
        guard !text.isEmpty, width > 0 else { return 0 }
        let maxHeight = font.lineHeight * CGFloat(maxLines)
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return min(ceil(boundingRect.height), maxHeight)
    }
}
