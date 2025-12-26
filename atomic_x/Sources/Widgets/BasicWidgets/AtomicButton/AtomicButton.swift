//
//  AtomicButton.swift
//  AtomicX
//
//  Created on 2025-11-26.
//

import UIKit
import Combine

// MARK: - Enums & Configurations

public enum ButtonVariant {
    case filled, outlined, text
}

public enum ButtonColorType {
    case primary, secondary, danger
}

public enum ButtonContent: Equatable {
    case textOnly(text: String)
    case iconOnly(icon: UIImage?)
    case iconLeading(text: String, icon: UIImage?)
    case iconTrailing(text: String, icon: UIImage?)
    
    var text: String? {
        switch self {
        case .textOnly(let t), .iconLeading(let t, _), .iconTrailing(let t, _): return t
        default: return nil
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .iconOnly(let i), .iconLeading(_, let i), .iconTrailing(_, let i): return i
        default: return nil
        }
    }
    
    func hasSameStructure(as other: ButtonContent) -> Bool {
        switch (self, other) {
        case (.textOnly, .textOnly), (.iconOnly, .iconOnly),
             (.iconLeading, .iconLeading), (.iconTrailing, .iconTrailing):
            return true
        default: return false
        }
    }
}

public enum ButtonSize {
    case xsmall, small, medium, large
    
    public var height: CGFloat {
        switch self {
        case .xsmall: return 24
        case .small:  return 32
        case .medium: return 40
        case .large:  return 48
        }
    }
    public var minWidth: CGFloat {
        switch self {
        case .xsmall: return 48
        case .small:  return 64
        case .medium: return 80
        case .large:  return 96
        }
    }
    public var horizontalPadding: CGFloat {
        switch self {
        case .xsmall: return 8
        case .small:  return 12
        case .medium: return 16
        case .large:  return 20
        }
    }
    public var iconSize: CGFloat {
        switch self {
        case .xsmall: return 14
        case .small:  return 16
        case .medium: return 20
        case .large:  return 20
        }
    }
    public var spacing: CGFloat { return 6.0 }
}

// MARK: - AtomicButton Class

public class AtomicButton: UIButton {
    private let autoCornerRadius: CGFloat = 9999

    public enum Defaults {
        public static let spacing: CGFloat = 6.0
        public static let fallbackIconSize: CGFloat = 20.0
    }
    
    public typealias ButtonConfigProvider = (Theme) -> AtomicButtonConfig
    
    // MARK: - Properties
    
    public let fixedSize: ButtonSize?
    
    public private(set) var content: ButtonContent
    private var currentVariant: ButtonVariant
    private var currentColorType: ButtonColorType
    
    public let contentInsets: NSDirectionalEdgeInsets
    
    // Private UI
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = fixedSize?.spacing ?? Defaults.spacing
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var iconImageView: UIImageView?
    private var contentLabel: UILabel?
    
    // Logic
    private let buttonConfigProvider: ButtonConfigProvider
    private var clickAction: ((AtomicButton) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var targetCornerRadius: CGFloat = 0
    
    // MARK: - Initialization
    
    // 预设模式
    public init(variant: ButtonVariant = .filled,
                colorType: ButtonColorType = .primary,
                size: ButtonSize = .small,
                content: ButtonContent = .textOnly(text: "")) {
        self.fixedSize = size
        self.contentInsets = .zero
        self.content = content
        self.currentVariant = variant
        self.currentColorType = colorType
        self.buttonConfigProvider = { theme in
            AtomicButtonConfig.preset(colorType: colorType, variant: variant, ButtonSize: size, for: theme)
        }
        super.init(frame: .zero)
        
        setupViews()
        setupConstraints()
        bindTheme()
        updateAppearance()
    }
    
    // 自定义模式
    public init(content: ButtonContent = .textOnly(text: ""),
                contentInsets: NSDirectionalEdgeInsets = .zero,
                buttonConfigProvider: @escaping ButtonConfigProvider) {
        self.fixedSize = nil
        self.contentInsets = contentInsets
        self.content = content
        self.currentVariant = .filled
        self.currentColorType = .primary
        self.buttonConfigProvider = buttonConfigProvider
        super.init(frame: .zero)
        
        setupViews()
        setupConstraints()
        bindTheme()
        updateAppearance()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Public API
    public func setButtonContent(_ content: ButtonContent) {
        self.content = content
        updateContent()
    }
    
    public func setVariant(_ variant: ButtonVariant) {
        guard fixedSize != nil else { return }
        self.currentVariant = variant
        updateAppearance()
    }
    
    public func setColorType(_ colorType: ButtonColorType) {
        guard fixedSize != nil else { return }
        self.currentColorType = colorType
        updateAppearance()
    }
    
    // MARK: - Private Helpers

    // MARK: - API Compatibility (UIButton Override)
    
    public override var currentTitle: String? { return content.text }
    public override var currentImage: UIImage? { return content.icon }

    // MARK: - UI Updates
    
    private func createContentViews() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        iconImageView = nil
        contentLabel = nil
        
        let iconSize = fixedSize?.iconSize ?? Defaults.fallbackIconSize
        
        switch content {
        case .textOnly(let text):
            addLabel(text)
        case .iconOnly(let icon):
            addIcon(icon, size: iconSize)
        case .iconLeading(let text, let icon):
            addIcon(icon, size: iconSize)
            addLabel(text)
        case .iconTrailing(let text, let icon):
            addLabel(text)
            addIcon(icon, size: iconSize)
        }
    }
    
    private func updateContent() {
        createContentViews()
        updateAppearance()
    }
    
    // MARK: - Standard Button Logic
    
    private func setupViews() {
        addSubview(stackView)
        createContentViews()
    }
    
    private func setupConstraints() {
        var constraints = [
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]
        
        if let size = fixedSize {
            constraints.append(heightAnchor.constraint(equalToConstant: size.height))
            constraints.append(widthAnchor.constraint(greaterThanOrEqualToConstant: size.minWidth))
            constraints.append(stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: size.horizontalPadding))
            constraints.append(stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -size.horizontalPadding))
        } else {
            constraints.append(stackView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top))
            constraints.append(stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom))
            constraints.append(stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.leading))
            constraints.append(stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.trailing))
        }
        NSLayoutConstraint.activate(constraints)
    }
    
    private func bindTheme() {
        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateAppearance() }
            .store(in: &cancellables)
    }
    
    private func updateAppearance() {
        let config: AtomicButtonConfig
        if let size = fixedSize {
            config = AtomicButtonConfig.preset(
                colorType: currentColorType,
                variant: currentVariant,
                ButtonSize: size,
                for: ThemeStore.shared.currentTheme
            )
        } else {
            config = buttonConfigProvider(ThemeStore.shared.currentTheme)
        }
        
        let currentColors: ButtonColors
        if !isEnabled {
            currentColors = config.disabledButtonColor
        } else if isHighlighted {
            currentColors = config.highlightedButtonColor
        } else {
            currentColors = config.normalButtonColor
        }
        
        UIView.performWithoutAnimation {
            self.backgroundColor = currentColors.backgroundColor
            self.layer.borderColor = currentColors.borderColor.cgColor
            self.layer.borderWidth = config.borderWidth
            self.iconImageView?.tintColor = currentColors.textColor
            self.contentLabel?.textColor = currentColors.textColor
            self.contentLabel?.font = config.font
            self.targetCornerRadius = config.cornerRadius
            self.setNeedsLayout()
        }
    }
    
    public func setClickAction(_ action: @escaping (AtomicButton) -> Void) {
        self.clickAction = action
        self.removeTarget(self, action: #selector(handleTap), for: .touchUpInside)
        self.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    
    @objc private func handleTap() { clickAction?(self) }
    
    private func addLabel(_ text: String) {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        stackView.addArrangedSubview(label)
        self.contentLabel = label
    }
    
    private func addIcon(_ icon: UIImage?, size: CGFloat) {
        let imageView = UIImageView(image: icon)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
        stackView.addArrangedSubview(imageView)
        self.iconImageView = imageView
    }
    
    public override var isHighlighted: Bool {
        didSet { if oldValue != isHighlighted {updateAppearance()} }
    }
    
    public override var isEnabled: Bool {
        didSet { if oldValue != isEnabled { updateAppearance()} }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.masksToBounds = true

        if targetCornerRadius == autoCornerRadius {
            layer.cornerRadius = min(bounds.width, bounds.height) / 2.0
        } else {
            layer.cornerRadius = targetCornerRadius
        }
        
        layer.cornerCurve = .continuous
    }
}
