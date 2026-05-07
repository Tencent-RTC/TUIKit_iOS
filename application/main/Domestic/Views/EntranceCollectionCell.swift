//
//  EntranceCollectionCell.swift
//  main
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
        label.text = MainLocalize("Demo.TRTC.Portal.Main.HotComponent")
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
            make.top.equalTo(iconImageView.snp.bottom).offset(convertPixel(h: 6)).priority(.high)
            make.bottom.lessThanOrEqualToSuperview().offset(convertPixel(h: -8))
        }

        hotLabel.snp.makeConstraints { make in
            make.left.equalTo(uiComLabel).offset(convertPixel(h: 6))
            make.centerY.equalTo(titleLabel)
            make.height.equalTo(18)
            make.width.equalTo(32)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: - Public Config

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
            make.top.equalTo(iconImageView.snp.bottom).offset(convertPixel(h: 6)).priority(.high)
            make.bottom.lessThanOrEqualToSuperview().offset(convertPixel(h: -8))
        }

        arrowImageView.isHidden = true
        backgroundImageView.isHidden = true
    }

    private func setupUIComponentConfig(_ module: ResolvedModule) {
        let config = module.config
        if !config.gradientColors.isEmpty {
            gradientColors = config.gradientColors
            uiComLabel.text = MainLocalize("Demo.TRTC.Portal.Main.UICompnent")
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
            make.top.equalTo(iconImageView.snp.bottom).offset(convertPixel(h: 6)).priority(.high)
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
}
