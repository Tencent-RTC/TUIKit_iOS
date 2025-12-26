//
//  AtomicPopover.swift
//  AtomicX
//
//  Created on 2025-12-04.
//

import UIKit
import Combine
import SnapKit

// MARK: - Public Types

public enum PopoverPosition: Equatable {
    case bottom
    case center
    case top
}

public enum PopoverHeight {
    case wrapContent
    case ratio(CGFloat)
}

public enum PopoverColor {
    case defaultThemeColor
    case custom(UIColor)
}

public enum PopoverAnimation {
    case slideFromBottom
    case slideFromTop
    case fade
    case scale
    case none
}

// MARK: - AtomicPopover

public final class AtomicPopover: UIViewController {
    // MARK: - Configuration
    public struct AtomicPopoverConfig {
        public var position: PopoverPosition
        public var height: PopoverHeight
        public var animation: PopoverAnimation
        public var backgroundColor: PopoverColor
        public var onBackdropTap: (() -> Void)?

        public init(
            position: PopoverPosition = .bottom,
            height: PopoverHeight = .wrapContent,
            animation: PopoverAnimation = .slideFromBottom,
            backgroundColor: PopoverColor = .defaultThemeColor,
            onBackdropTap: (() -> Void)? = nil
        ) {
            self.position = position
            self.height = height
            self.animation = animation
            self.backgroundColor = backgroundColor
            self.onBackdropTap = onBackdropTap
        }
        
        public static func centerDefault() -> AtomicPopoverConfig {
            return AtomicPopoverConfig(position: .center,
                                       height: .wrapContent,
                                       animation: .none,
                                       backgroundColor: .defaultThemeColor,
                                       onBackdropTap: nil
                )
            }
    }
    
    // MARK: - Properties
    private let centerWidthRatio = 0.9

    private let contentView: UIView
    private let configuration: AtomicPopoverConfig
    private var cancellables = Set<AnyCancellable>()

    private lazy var backdropView: UIView = {
        let view = UIView()
        view.alpha = 0
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    private var containerViewBottomConstraint: Constraint?
    private var containerViewCenterYConstraint: Constraint?
    private var containerViewTopConstraint: Constraint?
    private var containerViewHeightConstraint: Constraint?
    
    // MARK: - Initialization
    
    public init(
        contentView: UIView,
        configuration: AtomicPopoverConfig = AtomicPopoverConfig()
    ) {
        self.contentView = contentView
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupBackdrop()
        bindTheme()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animatePresentation()
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let isLandscape = size.width > size.height
        
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            if isLandscape {
                self?.dismiss(animated: true)
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        view.addSubview(backdropView)
        view.addSubview(containerView)
        
        containerView.addSubview(contentView)
    }
    
    private func setupConstraints() {
        backdropView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(containerView.safeAreaLayoutGuide.snp.top)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom)
        }

        updateContainerConstraints(animated: false)
    }
    
    private func updateContainerConstraints(animated: Bool, isInitialSetup: Bool = false) {
        let screenSize = view.bounds.size
        let safeAreaInsets = view.safeAreaInsets

        let maxAvailableHeight: CGFloat
        switch configuration.position {
        case .bottom:
            maxAvailableHeight = screenSize.height - safeAreaInsets.top
        case .top:
            maxAvailableHeight = screenSize.height - safeAreaInsets.bottom
        case .center:
            maxAvailableHeight = screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom
        }

        containerView.snp.remakeConstraints { make in
            switch configuration.position {
            case .center:
                make.width.equalTo(screenSize.width * centerWidthRatio)
                make.centerX.equalToSuperview()
            case .bottom, .top:
                make.left.right.equalToSuperview()
            }

            switch configuration.height {
            case .wrapContent:
                make.height.lessThanOrEqualTo(maxAvailableHeight)
            case .ratio(let ratio):
                let clampedRatio = min(ratio, 1.0)
                let height = screenSize.height * clampedRatio
                let clampedHeight = min(height, maxAvailableHeight)
                containerViewHeightConstraint = make.height.equalTo(clampedHeight).constraint
            }

            let initialOffset: CGFloat
            if isInitialSetup {
                switch configuration.animation {
                case .slideFromBottom:
                    initialOffset = screenSize.height
                case .slideFromTop:
                    initialOffset = -screenSize.height
                case .fade, .scale, .none:
                    initialOffset = 0
                }
            } else {
                initialOffset = 0
            }

            switch configuration.position {
            case .bottom:
                containerViewBottomConstraint = make.bottom.equalToSuperview().offset(initialOffset).constraint
                make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top)
            case .center:
                containerViewCenterYConstraint = make.centerY.equalTo(view.safeAreaLayoutGuide.snp.centerY).offset(initialOffset).constraint
            case .top:
                containerViewTopConstraint = make.top.equalToSuperview().offset(initialOffset).constraint
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.bottom)
            }
        }

        if animated {
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    private func setupBackdrop() {
        let theme = ThemeStore.shared.currentTheme
        backdropView.backgroundColor = theme.tokens.color.bgColorMask

        switch configuration.backgroundColor {
        case .defaultThemeColor:
            containerView.backgroundColor = theme.tokens.color.bgColorDialog
        case .custom(let color):
            containerView.backgroundColor = color
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
        backdropView.addGestureRecognizer(tapGesture)
    }
    
    private func bindTheme() {
        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.updateAppearance(theme: theme)
            }
            .store(in: &cancellables)
    }
    
    private func updateAppearance(theme: Theme) {
        backdropView.backgroundColor = theme.tokens.color.bgColorMask
        
        switch configuration.backgroundColor {
        case .defaultThemeColor:
            containerView.backgroundColor = theme.tokens.color.bgColorDialog
        case .custom:
            break
        }
        
        let cornerRadius = theme.tokens.borderRadius.radius20
        
        switch configuration.position {
        case .bottom:
            containerView.layer.cornerRadius = cornerRadius
            containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        case .top:
            containerView.layer.cornerRadius = cornerRadius
            containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .center:
            containerView.layer.cornerRadius = cornerRadius
            containerView.layer.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner
            ]
        }
        
        containerView.layer.cornerCurve = .continuous
    }
    
    // MARK: - Animation
    
    private func animatePresentation() {
        updateContainerConstraints(animated: false, isInitialSetup: true)
        
        switch configuration.animation {
        case .slideFromBottom, .slideFromTop:
            break
        case .fade:
            containerView.alpha = 0
        case .scale:
            containerView.alpha = 0
            containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        case .none:
            backdropView.alpha = 1
            updateConstraintsToFinalPosition()
            return
        }
        
        view.layoutIfNeeded()

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) { [weak self] in
            guard let self = self else { return }
            
            self.backdropView.alpha = 1

            self.updateConstraintsToFinalPosition()
            
            switch self.configuration.animation {
            case .slideFromBottom, .slideFromTop:
                break
            case .fade:
                self.containerView.alpha = 1
            case .scale:
                self.containerView.alpha = 1
                self.containerView.transform = .identity
            case .none:
                break
            }
            
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateConstraintsToFinalPosition() {
        switch configuration.position {
        case .bottom:
            containerViewBottomConstraint?.update(offset: 0)
        case .center:
            containerViewCenterYConstraint?.update(offset: 0)
        case .top:
            containerViewTopConstraint?.update(offset: 0)
        }
    }
    
    private func animateDismissal(completion: (() -> Void)? = nil) {
        let screenSize = view.bounds.size
        
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseIn]
        ) { [weak self] in
            guard let self = self else { return }
            
            self.backdropView.alpha = 0

            let exitOffset: CGFloat
            switch self.configuration.animation {
            case .slideFromBottom:
                exitOffset = screenSize.height
            case .slideFromTop:
                exitOffset = -screenSize.height
            case .fade:
                self.containerView.alpha = 0
                return
            case .scale:
                self.containerView.alpha = 0
                self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                return
            case .none:
                return
            }

            switch self.configuration.position {
            case .bottom:
                self.containerViewBottomConstraint?.update(offset: exitOffset)
            case .center:
                self.containerViewCenterYConstraint?.update(offset: exitOffset)
            case .top:
                self.containerViewTopConstraint?.update(offset: exitOffset)
            }
            
            self.view.layoutIfNeeded()
        } completion: { _ in
            completion?()
        }
    }

    // MARK: - Gesture Handlers
    
    @objc private func handleBackdropTap() {
        if let onBackdropTap = configuration.onBackdropTap {
            onBackdropTap()
        }
    }
}


// MARK: - UIApplication Extension

extension UIApplication {

    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? keyWindow?.rootViewController
        
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        
        return base
    }
    
    var keyWindow: UIWindow? {
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
