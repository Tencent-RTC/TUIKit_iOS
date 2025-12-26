//
//  AtomicAvatar.swift
//  AtomicX
//
//  Created on 2025-12-03.
//

import UIKit
import Combine
import SnapKit
import Kingfisher

// MARK: - Public Types

public enum AtomicAvatarContent {
    case url(_ url: String, placeholder: UIImage?)
    case text(name: String)
    case icon(image: UIImage)
}

public enum AtomicAvatarBadge {
    case none
    case dot
    case text(String)
}

public enum AtomicAvatarSize {
    case xxs
    case xs
    case s
    case m
    case l
    case xl
    case xxl

    public var size: CGFloat {
        switch self {
        case .xxs: return 16
        case .xs:  return 24
        case .s:   return 32
        case .m:   return 40
        case .l:   return 48
        case .xl:  return 64
        case .xxl: return 96
        }
    }

    public var textFont: UIFont {
        let typography = ThemeStore.shared.typography
        switch self {
        case .xxs: return typography.Medium10
        case .xs:  return typography.Medium12
        case .s:   return typography.Medium14
        case .m:   return typography.Medium16
        case .l:   return typography.Medium18
        case .xl:  return typography.Medium28
        case .xxl: return typography.Medium36
        }
    }

    public var borderRadius: CGFloat {
        let radius = ThemeStore.shared.borderRadius
        switch self {
        case .xxs, .xs, .s, .m:
            return radius.radius4
        case .l, .xl, .xxl:
            return radius.radius8
        }
    }
}

public enum AtomicAvatarShape {
    case round
    case roundRectangle
    case rectangle
}

// MARK: - AtomicAvatar

public final class AtomicAvatar: UIView {
    
    // MARK: - Constants
    
    private static let squareRootTwoOverTwo: CGFloat = 0.70710678
    private static let badgeExtraPadding: CGFloat = 2
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private var badgeView: BadgeView?
    private var avatarSize: AtomicAvatarSize
    private var avatarShape: AtomicAvatarShape
    private var cancellables = Set<AnyCancellable>()
    private var onTapAction: (() -> Void)?
    private var isViewReady = false
    private var initialContent: AtomicAvatarContent?
    private var initialBadge: AtomicAvatarBadge = .none
    
    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.isHidden = true
        return label
    }()
    
    // MARK: - Initialization
    
    public init(
        content: AtomicAvatarContent,
        size: AtomicAvatarSize = .m,
        shape: AtomicAvatarShape = .round,
        badge: AtomicAvatarBadge = .none,
        onTap: (() -> Void)? = nil
    ) {
        self.avatarSize = size
        self.avatarShape = shape
        self.onTapAction = onTap
        self.initialContent = content
        self.initialBadge = badge
        
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Lifecycle
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        updateAppearance()
    }
    
    // MARK: - Setup
    
    private func constructViewHierarchy() {
        addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(textLabel)
        containerView.clipsToBounds = true
        if let content = initialContent {
            setContent(content)
        }
        setBadge(initialBadge)
    }
    
    private func activateConstraints() {
        self.snp.makeConstraints { make in
            make.width.height.equalTo(avatarSize.size)
        }
        containerView.snp.makeConstraints { make in
            make.left.top.equalToSuperview()
            make.width.height.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        textLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        textLabel.font = ThemeStore.shared.currentTheme.tokens.typography.Medium12
    }
    
    private func bindInteraction() {
        if onTapAction != nil {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            containerView.addGestureRecognizer(tapGesture)
            containerView.isUserInteractionEnabled = true
        }
        
        bindTheme()
    }
    
    private func bindTheme() {
        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAppearance()
            }
            .store(in: &cancellables)
    }
    
    private func updateAppearance() {
        let theme = ThemeStore.shared.currentTheme
        containerView.backgroundColor = theme.tokens.color.bgColorAvatar
        textLabel.textColor = theme.tokens.color.textColorPrimary
        applyShapeAndCornerRadius()
    }
    
    // MARK: - Public Methods
    
    public func setContent(_ content: AtomicAvatarContent) {
        guard isViewReady else {
            initialContent = content
            return
        }
        
        switch content {
            case .url(let url, let placeholder):
                setImageContent(url: url, placeholder: placeholder)
            case .text(let name):
                setTextContent(name: name)
            case .icon(let image):
                setIconContent(image: image)
        }
    }
    
    public func setSize(_ size: AtomicAvatarSize) {
        avatarSize = size
        
        guard isViewReady else { return }
        
        containerView.snp.updateConstraints { make in
            make.width.height.equalTo(size.size)
        }
        
        textLabel.font = size.textFont
        applyShapeAndCornerRadius()
        updateBadgePosition()
    }
    
    public func setShape(_ shape: AtomicAvatarShape) {
        avatarShape = shape
        
        guard isViewReady else { return }
        
        applyShapeAndCornerRadius()
        updateBadgePosition()
    }
    
    public func setBadge(_ badge: AtomicAvatarBadge) {
        guard isViewReady else {
            initialBadge = badge
            return
        }
        
        badgeView?.removeFromSuperview()
        badgeView = nil
        
        switch badge {
            case .none:
                break
            case .dot:
                addBadge(BadgeView(type: .dot))
            case .text(let text):
                addBadge(BadgeView(type: .text(text)))
        }
        
        updateBadgePosition()
    }
    
    // MARK: - Private Methods
    
    private func setImageContent(url: String, placeholder: UIImage?) {
        imageView.isHidden = false
        textLabel.isHidden = true
        imageView.kf.setImage(with: URL(string: url), placeholder: placeholder)
    }
    
    private func setTextContent(name: String) {
        imageView.isHidden = true
        textLabel.isHidden = false
        textLabel.text = name
    }
    
    private func setIconContent(image: UIImage) {
        imageView.isHidden = false
        textLabel.isHidden = true
        imageView.image = image
    }
    
    private func applyShapeAndCornerRadius() {
        let cornerRadius: CGFloat
        switch avatarShape {
            case .round:
                cornerRadius = avatarSize.size / 2
            case .roundRectangle:
                cornerRadius = avatarSize.borderRadius
            case .rectangle:
                cornerRadius = 0
        }
        
        containerView.layer.cornerRadius = cornerRadius
        containerView.layer.cornerCurve = .continuous
    }
    
    private func addBadge(_ badge: BadgeView) {
        badgeView = badge
        addSubview(badge)
    }
    
    private func updateBadgePosition() {
        guard let badge = badgeView else {
            invalidateIntrinsicContentSize()
            return
        }
        
        let center = calculateBadgeCenter()
        
        badge.snp.remakeConstraints { make in
            make.centerX.equalToSuperview().offset(center.x - avatarSize.size / 2)
            make.centerY.equalToSuperview().offset(center.y - avatarSize.size / 2)
        }
        
        invalidateIntrinsicContentSize()
    }
    
    private func calculateBadgeCenter() -> CGPoint {
        let size = avatarSize.size
        
        switch avatarShape {
            case .round:
                return calculateRoundBadgeCenter(size: size)
            case .roundRectangle:
                return calculateRoundRectangleBadgeCenter(size: size)
            case .rectangle:
                return calculateRectangleBadgeCenter(size: size)
        }
    }
    
    private func calculateRoundBadgeCenter(size: CGFloat) -> CGPoint {
        let radius = size / 2
        let offset = (radius + Self.badgeExtraPadding) * Self.squareRootTwoOverTwo
        return CGPoint(x: radius + offset, y: radius - offset)
    }
    
    private func calculateRoundRectangleBadgeCenter(size: CGFloat) -> CGPoint {
        if case .dot = badgeView?.badgeType {
            let borderRadius = avatarSize.borderRadius
            let offset = borderRadius * (1 - Self.squareRootTwoOverTwo)
            return CGPoint(x: size - offset, y: offset)
        } else {
            return CGPoint(x: size, y: 0)
        }
    }
    
    private func calculateRectangleBadgeCenter(size: CGFloat) -> CGPoint {
        return CGPoint(x: size, y: 0)
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        onTapAction?()
    }
    
    // MARK: - Layout
    
    public override var intrinsicContentSize: CGSize {
        guard let badge = badgeView else {
            return CGSize(width: avatarSize.size, height: avatarSize.size)
        }
        
        let center = calculateBadgeCenter()
        let badgeSize = badge.intrinsicContentSize
        let badgeRight = center.x + badgeSize.width / 2
        let badgeTop = center.y - badgeSize.height / 2
        
        let width = max(avatarSize.size, badgeRight)
        let topOffset = badgeTop < 0 ? -badgeTop : 0
        let height = avatarSize.size + topOffset
        
        return CGSize(width: width, height: height)
    }
}

// MARK: - BadgeView

private final class BadgeView: UIView {
    
    // MARK: - Constants
    private enum Constants {
        static let dotSize: CGFloat = 8
        static let textHeight: CGFloat = 16
        static let textHorizontalPadding: CGFloat = ThemeStore.shared.space.space4
        static let textCornerRadius: CGFloat = ThemeStore.shared.borderRadius.radius8
        static let textFont: UIFont = ThemeStore.shared.typography.Medium12
    }
    
    // MARK: - Types
    
    enum BadgeType {
        case dot
        case text(String)
    }
    
    // MARK: - Properties
    
    let badgeType: BadgeType
    private let backgroundLayer = CAShapeLayer()
    private var textLabel: UILabel?
    
    // MARK: - Initialization
    
    init(type: BadgeType) {
        self.badgeType = type
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        layer.addSublayer(backgroundLayer)
        
        if case .text(let text) = badgeType {
            setupTextLabel(text: text)
        }
        
        setColors()
    }
    
    private func setupTextLabel(text: String) {
        let label = UILabel()
        label.text = text
        label.font = Constants.textFont
        label.textAlignment = .center
        addSubview(label)
        textLabel = label
        
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 0,
                left: Constants.textHorizontalPadding,
                bottom: 0,
                right: Constants.textHorizontalPadding
            ))
        }
    }

    private func setColors() {
        let colors = ThemeStore.shared.color
        backgroundLayer.fillColor = colors.textColorError.cgColor
        textLabel?.textColor = colors.textColorButton
    }

    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let path: UIBezierPath
        switch badgeType {
            case .dot:
                path = UIBezierPath(ovalIn: bounds)
            case .text:
                path = UIBezierPath(roundedRect: bounds, cornerRadius: Constants.textCornerRadius)
        }
        
        backgroundLayer.path = path.cgPath
        backgroundLayer.frame = bounds
    }
    
    override var intrinsicContentSize: CGSize {
        switch badgeType {
            case .dot:
                return CGSize(width: Constants.dotSize, height: Constants.dotSize)
            case .text(let text):
                guard !text.isEmpty else { return .zero }
                let font = Constants.textFont
                let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
                let width = ceil(textWidth) + Constants.textHorizontalPadding * 2
                return CGSize(width: width, height: Constants.textHeight)
        }
    }
}
