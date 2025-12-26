//
//  AtomicToast.swift
//  AtomicX
//
//  Created on 2025-12-02.
//

import UIKit
import Combine
import SnapKit
import AtomicXCore
import ImSDK_Plus

// MARK: - UIView Extension

extension UIView {

    public func showAtomicToast(
        eventId: Int? = nil,
        text: String,
        customIcon: UIImage? = nil,
        style: ToastStyle = .text,
        position: ToastPosition = .center,
        duration: ToastDuration = .short,
        dismissOnTap: Bool = true,
        extension_info: [String: Any]? = nil
    ) {
        let toast = AtomicToast(
            eventId: eventId,
            text: text,
            style: style,
            customIcon: customIcon,
            extension_info: extension_info
        )

        toast.show(in: self, at: position, duration: duration, dismissOnTap: dismissOnTap)
    }
}


// MARK: - Toast Duration

public enum ToastDuration {
    case short
    case long
    
    var timeInterval: TimeInterval {
        switch self {
        case .short:
            return 2.0
        case .long:
            return 3.5
        }
    }
}

// MARK: - Toast Position

public enum ToastPosition {
    case top
    case center
    case bottom
}

// MARK: - Toast Size

private struct ToastSize {
    static let defaultHeight: CGFloat = 40
    static let defaultMaxWidth: CGFloat = 340
    
    let height: CGFloat
    let maxWidth: CGFloat
    let iconSize: CGFloat
    let elementSpacing: CGFloat
    let insetHorizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(tokens: DesignTokenSet) {
        self.height = Self.defaultHeight
        self.maxWidth = Self.defaultMaxWidth
        self.elementSpacing = tokens.space.space4
        self.insetHorizontalPadding = tokens.space.space16
        self.iconSize = tokens.space.space16
        self.verticalPadding = tokens.space.space40
    }
}

// MARK: - AtomicToast

class AtomicToast: UIView {
    
    // MARK: - Animation Constants

    private enum AnimationDuration {
        static let `in`: TimeInterval = 0.3
        static let out: TimeInterval = 0.2
    }

    private enum AnimationScale {
        static let initial: CGFloat = 0.8
        static let final: CGFloat = 0.9
    }
    
    // MARK: - Public Properties
    
    private(set) var text: String
    private(set) var config: AtomicToastConfig
    
    private let style: ToastStyle
    private let customIcon: UIImage?
    private let size: ToastSize
    
    // MARK: - Private Properties
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.text = text
        label.isUserInteractionEnabled = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var iconImageView: UIImageView? = {
        guard let icon = config.customIcon else { return nil }
        let imageView = UIImageView(image: icon)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()
    
    private lazy var containerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = size.elementSpacing
        stackView.isUserInteractionEnabled = false
        
        if let iconImageView = iconImageView {
            stackView.addArrangedSubview(iconImageView)
        }
        stackView.addArrangedSubview(textLabel)
        
        return stackView
    }()
    
    private var cancellables = Set<AnyCancellable>()
    
    // Animation & Dismiss
    private var dismissTimer: Timer?
    private var backgroundView: UIView?
    private let eventId: Int?
    private let extension_info: [String: Any]?
    
    // MARK: - Initialization

    public init(
        eventId: Int?,
        text: String,
        style: ToastStyle,
        customIcon: UIImage? = nil,
        extension_info: [String: Any]? = nil
    ) {
        self.text = text
        let currentTheme = ThemeStore.shared.currentTheme
        self.config = AtomicToastConfig.style(style, for: currentTheme, customIcon: customIcon)
        self.style = style
        self.customIcon = customIcon
        self.size = ToastSize(tokens: currentTheme.tokens)
        
        self.eventId = eventId
        self.extension_info = extension_info
        
        super.init(frame: .zero)
        
        bindTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        dismissTimer?.invalidate()
        cancellables.removeAll()
    }

    func show(
        in containerView: UIView,
        at position: ToastPosition = .center,
        duration: ToastDuration = .short,
        dismissOnTap: Bool = true
    ) {
        if let eventId = eventId {
            trackToastDisplay(eventId: eventId, text: text, extension_info: extension_info)
        }
        setupViews(in: containerView, at: position, dismissOnTap: dismissOnTap)
        prepareForDisplay()
        animateIn()
        scheduleAutoDismiss(after: duration.timeInterval)
    }

    func dismiss(animated: Bool = true) {
        dismissTimer?.invalidate()
        dismissTimer = nil

        if animated {
            animateOut { [weak self] in
                self?.backgroundView?.removeFromSuperview()
                self?.backgroundView = nil
                self?.removeFromSuperview()
            }
        } else {
            backgroundView?.removeFromSuperview()
            backgroundView = nil
            removeFromSuperview()
        }
    }


    private func scheduleAutoDismiss(after duration: TimeInterval) {
        dismissTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    // MARK: - Setup
    
    private func setupViews(in containerView: UIView, at position: ToastPosition, dismissOnTap: Bool) {
        self.isUserInteractionEnabled = false
        if dismissOnTap {
            setupBackgroundView(in: containerView)
        }

        containerView.addSubview(self)
        addSubview(containerStackView)
        setupConstraints(position: position)
    }
    
    private func prepareForDisplay() {
        apply(designConfig: config)
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    private func setupBackgroundView(in containerView: UIView) {
        let bgView = UIView()
        bgView.backgroundColor = .clear
        bgView.isUserInteractionEnabled = true
        containerView.addSubview(bgView)

        bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        bgView.addGestureRecognizer(tapGesture)

        self.backgroundView = bgView
    }
    
    private func setupConstraints(position: ToastPosition) {
        self.snp.makeConstraints { make in
            make.height.equalTo(size.height)
            make.width.lessThanOrEqualTo(size.maxWidth)
            make.centerX.equalToSuperview()
            applyPositionConstraint(make, for: position)
        }
        
        containerStackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(size.insetHorizontalPadding)
            make.right.equalToSuperview().offset(-size.insetHorizontalPadding)
        }
        
        iconImageView?.snp.makeConstraints { make in
            make.width.height.equalTo(size.iconSize)
        }
    }
    
    private func applyPositionConstraint(_ make: ConstraintMaker, for position: ToastPosition) {
        guard let superView = self.superview else {return}
        switch position {
        case .top:
            make.top.equalTo(superView.safeAreaLayoutGuide.snp.top).offset(size.verticalPadding)
        case .center:
            make.centerY.equalToSuperview()
        case .bottom:
            make.bottom.equalTo(superView.safeAreaLayoutGuide.snp.bottom).offset(-size.verticalPadding)
        }
    }
    
    private func bindTheme() {
        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                guard let self = self else { return }
                self.config = AtomicToastConfig.style(self.style, for: theme, customIcon: self.customIcon)
                self.apply(designConfig: self.config)
            }
            .store(in: &cancellables)
    }
    
    private func apply(designConfig: AtomicToastConfig) {
        backgroundColor = designConfig.backgroundColor
        
        textLabel.textColor = designConfig.textColor
        textLabel.font = designConfig.font
        
        if let shadow = designConfig.shadow {
            layer.shadowColor = shadow.color.cgColor
            layer.shadowRadius = shadow.radius
            layer.shadowOpacity = shadow.opacity
            layer.shadowOffset = CGSize(width: shadow.x, height: shadow.y)
            layer.masksToBounds = false
        }
        
        layer.cornerCurve = .continuous
        layer.cornerRadius = config.cornerRadius
    }
    
    private func trackToastDisplay(eventId: Int, text: String, extension_info: [String: Any]?) {
        reportAtomicEvent(code: eventId, message: text, extension_info: extension_info)
    }
    
    private func reportAtomicEvent(code: Int, message: String?, extension_info: [String: Any]?) {
        let extensionJson = extension_info.flatMap { jsonString(from: $0) } ?? ""
        
        let params: [String: Any] = [
            "event_id": 100011,
            "event_code": code,
            "event_message": message ?? "",
            "more_message": "AtomicToast",
            "extension_message": extensionJson
        ]
        
        callV2TIMExperimentalAPI(api: "reportRoomEngineEvent", params: params)
    }
    
    private func callV2TIMExperimentalAPI(api: String, params: [String: Any]) {
        guard let jsonString = jsonString(from: params) else { return }
        V2TIMManager.sharedInstance().callExperimentalAPI(api: api, param: jsonString as NSObject) { _ in
        } fail: { _, _ in }
    }
    
    private func jsonString(from dictionary: [String: Any]) -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Error converting dictionary to JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Animations
    
    private func animateIn() {
        alpha = 0
        transform = CGAffineTransform(scaleX: AnimationScale.initial, y: AnimationScale.initial)
        
        UIView.animate(
            withDuration: AnimationDuration.in,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: AnimationDuration.out,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: AnimationScale.final, y: AnimationScale.final)
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Gestures
    
    @objc private func handleTap() {
        dismiss()
    }
}
