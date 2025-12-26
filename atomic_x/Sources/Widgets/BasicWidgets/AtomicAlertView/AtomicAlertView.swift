//
//  AtomicAlertView.swift
//  atomic_x
//
//  Created by CY on 2025/12/05.
//

import UIKit
import Combine
import Kingfisher

// MARK: - Text Color Preset

public enum TextColorPreset {
    case primary
    case grey
    case blue
    case red
}

// MARK: - Button Config

public struct AlertButtonConfig {
    public let text: String
    public let type: TextColorPreset
    public let isBold: Bool
    public let onClick: ((AtomicAlertView) -> Void)?
    
    public init(
        text: String,
        type: TextColorPreset = .grey,
        isBold: Bool = false,
        onClick: ((AtomicAlertView) -> Void)? = nil
    ) {
        self.text = text
        self.type = type
        self.isBold = isBold
        self.onClick = onClick
    }
}

// MARK: - Dialog Config

public struct AlertViewConfig {
    public var title: String?
    public var content: String?
    public var iconUrl: String?
    public var countdownDuration: TimeInterval?
    public var onCountdownFinished: ((AtomicAlertView) -> Void)?
    public var cancelButton: AlertButtonConfig?
    public var confirmButton: AlertButtonConfig?
    public var items: [AlertButtonConfig]
    
    public init(
        title: String? = nil,
        content: String? = nil,
        iconUrl: String? = nil,
        cancelButton: AlertButtonConfig? = nil,
        confirmButton: AlertButtonConfig? = nil,
        items: [AlertButtonConfig] = [],
        countdownDuration: TimeInterval? = nil,
        onCountdownFinished: ((AtomicAlertView) -> Void)? = nil
    ) {
        self.title = title
        self.content = content
        self.iconUrl = iconUrl
        self.countdownDuration = countdownDuration
        self.onCountdownFinished = onCountdownFinished
        self.cancelButton = cancelButton
        self.confirmButton = confirmButton
        self.items = items
    }
}

// MARK: - AtomicAlertView

public class AtomicAlertView: UIView {
    
    // MARK: - Constants
    private let dividerThickness: CGFloat = 1.0
    private let buttonHeight: CGFloat = 56.0
    
    // MARK: - Properties
    public let config: AlertViewConfig
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: AnyCancellable?
    private weak var countdownTargetButton: AtomicButton?
    
    fileprivate weak var parentOverlay: AlertOverlayView?
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var rootStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var headerContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(
            top: currentTokens.space.space24,
            left: currentTokens.space.space24,
            bottom: currentTokens.space.space24,
            right: currentTokens.space.space24
        )
        return stackView
    }()
    
    private lazy var iconView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("", placeholder: UIImage.avatarPlaceholderImage),
            size: .xs,
            shape: .round
        )
        avatar.contentMode = .scaleAspectFit
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.isHidden = true
        return avatar
    }()
    
    private lazy var titleLabel: UILabel = {
        let titleLabel = AtomicLabel { theme in
            LabelAppearance(textColor: theme.tokens.color.textColorPrimary,
                            backgroundColor: theme.tokens.color.clearColor,
                            font: theme.tokens.typography.Bold18,
                            cornerRadius: 0)
        }
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()
    
    private lazy var contentLabel: UILabel = {
        let contentLabel = AtomicLabel { theme in
            LabelAppearance(textColor: theme.tokens.color.textColorPrimary,
                            backgroundColor: theme.tokens.color.clearColor,
                            font: theme.tokens.typography.Regular16,
                            cornerRadius: 0)
        }
        contentLabel.textAlignment = .center
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.isHidden = true
        return contentLabel
    }()
    
    private var dividers: [UIView] = []
    
    private var currentTokens: DesignTokenSet {
        return ThemeStore.shared.currentTheme.tokens
    }

    // MARK: - Initialization
    public init(config: AlertViewConfig) {
        self.config = config
        super.init(frame: .zero)
        
        setupUI()
        bindTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopCountdown()
        cancellables.removeAll()
    }
    
    // MARK: - 1. Setup UI
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(containerView)
        containerView.addSubview(rootStackView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            rootStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            rootStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            rootStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            rootStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        setupHeaderSection()
        
        setupBottomSection()
    }
    
    private func setupHeaderSection() {
        let hasTitle = !(config.title?.isEmpty ?? true)
        let hasContent = !(config.content?.isEmpty ?? true)
        
        guard hasTitle || hasContent else { return }
        
        rootStackView.addArrangedSubview(headerContainer)
        
        let titleWrapper = UIStackView()
        titleWrapper.axis = .horizontal
        titleWrapper.alignment = .center
        titleWrapper.spacing = 8
        titleWrapper.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addArrangedSubview(titleWrapper)

        titleWrapper.addArrangedSubview(iconView)
        if let iconUrl = config.iconUrl, !iconUrl.isEmpty {
            iconView.setContent(.url(iconUrl, placeholder: UIImage.avatarPlaceholderImage))
            iconView.isHidden = false
        }

        titleWrapper.addArrangedSubview(titleLabel)
        titleLabel.text = config.title

        if hasContent {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: currentTokens.space.space16).isActive = true
            headerContainer.addArrangedSubview(spacer)

            headerContainer.addArrangedSubview(contentLabel)
            contentLabel.text = config.content
            contentLabel.isHidden = false
        }
    }
    
    private func setupBottomSection() {
        if !config.items.isEmpty {
            setupVerticalListMode()
        } else if config.cancelButton != nil || config.confirmButton != nil {
            setupStandardButtonMode()
        }
    }
    
    private func setupVerticalListMode() {
        if !config.items.isEmpty && !rootStackView.arrangedSubviews.isEmpty {
            addDivider()
        }
        
        for (index, itemConfig) in config.items.enumerated() {
            if index > 0 { addDivider() }
            
            let button = createButton(config: itemConfig)
            
            button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            button.tag = index
            button.addTarget(self, action: #selector(handleItemButtonTap(_:)), for: .touchUpInside)
            rootStackView.addArrangedSubview(button)
        }
    }
    
    private func setupStandardButtonMode() {
        if !rootStackView.arrangedSubviews.isEmpty {
            addDivider()
        }
        
        let buttonContainer = UIStackView()
        buttonContainer.axis = .horizontal
        buttonContainer.alignment = .fill
        buttonContainer.distribution = .fill
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        rootStackView.addArrangedSubview(buttonContainer)
        
        var buttonsInRow: [UIButton] = []
        
        if let cancelConfig = config.cancelButton {
            let button = createButton(config: cancelConfig)
            button.addTarget(self, action: #selector(handleCancelButtonTap(_:)), for: .touchUpInside)
            buttonsInRow.append(button)
            
            if let duration = config.countdownDuration, duration > 0 {
                self.countdownTargetButton = button
                startCountdown(duration: duration)
            }
        }
        
        if let confirmConfig = config.confirmButton {
            let button = createButton(config: confirmConfig)
            button.addTarget(self, action: #selector(handleConfirmButtonTap(_:)), for: .touchUpInside)
            buttonsInRow.append(button)
        }
        
        let buttonCount = CGFloat(buttonsInRow.count)
        guard buttonCount > 0 else { return }
        
        let separatorCount = max(0, buttonCount - 1)
        let totalSeparatorWidth = separatorCount * dividerThickness
        
        let widthConstant = -(totalSeparatorWidth / buttonCount)
        
        for (index, button) in buttonsInRow.enumerated() {
            if index > 0 {
                addVerticalDivider(parent: buttonContainer)
            }
            buttonContainer.addArrangedSubview(button)
            
            button.widthAnchor.constraint(
                equalTo: buttonContainer.widthAnchor,
                multiplier: 1.0 / buttonCount,
                constant: widthConstant
            ).isActive = true
        }
    }

    // MARK: - Update Appearance
    private func updateAppearance() {
        containerView.backgroundColor = currentTokens.color.bgColorDialog
        containerView.layer.cornerRadius = currentTokens.borderRadius.radius20
        let isContentEmpty = config.content?.isEmpty ?? true
        if isContentEmpty {
            titleLabel.font = currentTokens.typography.Bold16
        }
        dividers.forEach { $0.backgroundColor = currentTokens.color.strokeColorPrimary }
    }
    
    // MARK: - Theme Binding
    private func bindTheme() {
        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateAppearance()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    private func addDivider() {
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: dividerThickness).isActive = true
        rootStackView.addArrangedSubview(divider)
        dividers.append(divider)
    }
    
    private func addVerticalDivider(parent: UIStackView) {
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: dividerThickness).isActive = true
        parent.addArrangedSubview(divider)
        dividers.append(divider)
    }
    
    private func createButton(config: AlertButtonConfig) -> AtomicButton {
        let button = AtomicButton(content: .textOnly(text: config.text)) { theme in
            let resolvedColor = Self.resolveButtonTextColor(type: config.type, tokens: theme.tokens)
            let buttonColors = ButtonColors(backgroundColor: theme.tokens.color.clearColor,
                                            textColor: resolvedColor,
                                            borderColor: theme.tokens.color.clearColor)
            return AtomicButtonConfig(normalButtonColor: buttonColors,
                                      borderWidth: 0,
                                      font: config.isBold ? theme.tokens.typography.Bold16 : theme.tokens.typography.Medium16)
        }
        return button
    }
    
    static func resolveButtonTextColor(type: TextColorPreset, tokens: DesignTokenSet) -> UIColor {
        switch type {
        case .red: return tokens.color.textColorError
        case .blue: return tokens.color.textColorLink
        case .primary: return tokens.color.textColorPrimary
        case .grey: return tokens.color.textColorSecondary
        }
    }
    
    // MARK: - Countdown Logic
    private func startCountdown(duration: TimeInterval) {
        updateCountdownText(timeLeft: duration)
        
        var remainingTime = duration
        
        countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                remainingTime -= 1
                
                if remainingTime <= 0 {
                    self.stopCountdown()
                    self.config.onCountdownFinished?(self)
                } else {
                    self.updateCountdownText(timeLeft: remainingTime)
                }
            }
    }
    
    private func stopCountdown() {
        countdownTimer?.cancel()
        countdownTimer = nil
    }
    
    private func updateCountdownText(timeLeft: TimeInterval) {
        guard let button = countdownTargetButton,
              let originalText = config.cancelButton?.text else { return }
        
        let newText = "\(originalText) (\(Int(timeLeft)))"
        
        button.setButtonContent(.textOnly(text: newText))
        
        button.layoutIfNeeded()
    }
    
    // MARK: - Actions
    
    @objc private func handleItemButtonTap(_ sender: UIButton) {
        guard sender.tag < config.items.count else { return }
        self.isHidden = true
        config.items[sender.tag].onClick?(self)
    }
    
    @objc private func handleCancelButtonTap(_ sender: UIButton) {
        self.isHidden = true
        config.cancelButton?.onClick?(self)
    }
    
    @objc private func handleConfirmButtonTap(_ sender: UIButton) {
        self.isHidden = true
        config.confirmButton?.onClick?(self)
    }
}

public extension AtomicAlertView {
    
    /// 直接在当前最顶层的 VC 显示 Alert
    /// - Parameters:
    ///   - animated: 是否开启动画
    ///   - completion: 显示完成后的回调
    func show(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let topViewController = UIApplication.shared.topViewController() else {
            return
        }
        
        let overlay = AlertOverlayView(contentView: self)
        overlay.frame = topViewController.view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.layoutIfNeeded()
        
        self.parentOverlay = overlay
        topViewController.view.addSubview(overlay)
        
        if animated {
            overlay.animateIn(completion: completion)
        } else {
            completion?()
        }
    }
    
    func dismiss() {
        stopCountdown()
        if let overlay = parentOverlay {
            overlay.dismiss(animated: false)
        }
    }
}

private class AlertOverlayView: UIView {
    
    private let contentView: UIView
    private let backgroundView = UIView()
    private let contentWidthScale = 0.9
    
    init(contentView: UIView) {
        self.contentView = contentView
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.alpha = 0
        addSubview(backgroundView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.alpha = 0
        contentView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            contentView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9)
            
        ])
    }
    
    func animateIn(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.backgroundView.alpha = 1
            self.contentView.alpha = 1
            self.contentView.transform = .identity
        } completion: { _ in
            completion?()
        }
    }
    
    func dismiss(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
                self.backgroundView.alpha = 0
                self.contentView.alpha = 0
                self.contentView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            } completion: { _ in
                self.removeFromSuperview()
            }
        } else {
            self.removeFromSuperview()
        }
    }
}
