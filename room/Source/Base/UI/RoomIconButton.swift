//
//  RoomIconButton.swift
//  TUIRoomKit
//
//  Created on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit

/// Icon position relative to title
public enum RoomIconPosition {
    case left
    case right
    case top
    case bottom
}

/// A versatile button component that supports flexible icon positioning
/// - Supports icon placement: left, right, top, bottom
/// - Customizable spacing between icon and title
/// - Uses SnapKit for layout constraints
///
/// **Usage Example:**
/// ```swift
/// let button = RoomIconButton()
/// button.setIcon(UIImage(named: "icon"))
/// button.setTitle("Button")
/// button.setIconPosition(.left, spacing: 8)
/// button.setTitleColor(RoomColors.g2)
/// button.setTitleFont(RoomFonts.pingFangSCFont(size: 14, weight: .regular))
/// button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
/// ```
public class RoomIconButton: UIControl {
    
    // MARK: - Properties
    
    /// Icon position relative to title (default: .left)
    private var iconPosition: RoomIconPosition = .left
    
    /// Spacing between icon and title (default: 8)
    private var iconSpacing: CGFloat = 8
    
    private var iconSize: CGSize = .zero
    
    /// Badge red dot size (default: 8x8)
    private var badgeDotSize: CGFloat = 8
    
    /// Badge offset from top-right corner
    private var badgeOffset: CGPoint = CGPoint(x: 2, y: -2)

    // MARK: - UI Components
    
    private lazy var badgeView: UILabel = {
        let label = UILabel()
        label.backgroundColor = RoomColors.endTitleColor
        label.textColor = .white
        label.font = RoomFonts.pingFangSCFont(size: 10, weight: .medium)
        label.textAlignment = .center
        label.clipsToBounds = true
        label.isHidden = true
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        return label
    }()
    
    private lazy var containerStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = iconSpacing
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        addSubview(containerStackView)
        addSubview(badgeView)
        
        containerStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview()
            make.right.lessThanOrEqualToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        updateBadgeConstraints()
        
        // Set content compression resistance priority
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    // MARK: - Public Methods
    
    /// Set icon image
    /// - Parameter image: Icon image
    public func setIcon(_ image: UIImage?) {
        iconImageView.image = image
        iconImageView.isHidden = (image == nil)
        updateLayout()
    }
    
    /// Set title text
    /// - Parameter title: Title text
    public func setTitle(_ title: String?) {
        titleLabel.text = title
        titleLabel.isHidden = (title == nil || title?.isEmpty == true)
        updateLayout()
    }
    
    /// Set title color
    /// - Parameter color: Title color
    public func setTitleColor(_ color: UIColor) {
        titleLabel.textColor = color
    }
    
    /// Set title font
    /// - Parameter font: Title font
    public func setTitleFont(_ font: UIFont) {
        titleLabel.font = font
    }
    
    /// Set icon size
    /// - Parameter size: Icon size
    public func setIconSize(_ size: CGSize) {
        iconSize = size
        updateLayout()
    }
    
    /// Set icon position and spacing
    /// - Parameters:
    ///   - position: Icon position relative to title
    ///   - spacing: Spacing between icon and title
    public func setIconPosition(_ position: RoomIconPosition, spacing: CGFloat = 8) {
        iconPosition = position
        iconSpacing = spacing
        updateLayout()
    }
    
    /// Set container alignment
    /// - Parameter alignment: StackView alignment
    public func setContentAlignment(_ alignment: UIStackView.Alignment) {
        containerStackView.alignment = alignment
    }
    
    // MARK: - Badge Methods
    
    /// Show or hide the badge red dot
    /// - Parameter isHidden: Whether to hide the badge
    public func setBadgeHidden(_ isHidden: Bool) {
        badgeView.isHidden = isHidden
    }
    
    /// Set badge count. Shows red dot when count > 0, hides when count == 0.
    /// - When count > 0 and <= 99: displays the number
    /// - When count > 99: displays "99+"
    /// - When count == 0: hides the badge
    /// - Parameter count: Badge count
    public func setBadgeCount(_ count: Int) {
        if count <= 0 {
            badgeView.isHidden = true
            badgeView.text = nil
            updateBadgeConstraints()
            return
        }
        
        badgeView.isHidden = false
        if count > 99 {
            badgeView.text = "99+"
        } else {
            badgeView.text = "\(count)"
        }
        updateBadgeConstraints()
    }
    
    /// Show badge as a simple red dot without number
    public func showBadgeDot() {
        badgeView.isHidden = false
        badgeView.text = nil
        updateBadgeConstraints()
    }
    
    /// Set badge dot size (for dot mode without number)
    /// - Parameter size: Dot diameter
    public func setBadgeDotSize(_ size: CGFloat) {
        badgeDotSize = size
        updateBadgeConstraints()
    }
    
    /// Set badge offset from the top-right corner of containerStackView
    /// - Parameter offset: Offset point (positive x moves right, positive y moves down)
    public func setBadgeOffset(_ offset: CGPoint) {
        badgeOffset = offset
        updateBadgeConstraints()
    }
    
    // MARK: - Private Methods
    
    private func updateBadgeConstraints() {
        badgeView.snp.remakeConstraints { make in
            if let text = badgeView.text, !text.isEmpty {
                // Number mode: auto-size with minimum width
                let textSize = badgeView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 16))
                let badgeHeight: CGFloat = 16
                let badgeWidth = max(badgeHeight, textSize.width + 8)
                make.height.equalTo(badgeHeight)
                make.width.equalTo(badgeWidth)
                badgeView.layer.cornerRadius = badgeHeight / 2
            } else {
                // Dot mode: simple circle
                make.width.height.equalTo(badgeDotSize)
                badgeView.layer.cornerRadius = badgeDotSize / 2
            }
            make.right.equalTo(containerStackView.snp.right).offset(badgeOffset.x)
            make.top.equalTo(containerStackView.snp.top).offset(badgeOffset.y)
        }
    }
    
    private func updateLayout() {
        // Remove all arranged subviews
        let viewsToBeRemoved = containerStackView.arrangedSubviews
        for view in viewsToBeRemoved {
            containerStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Remove existing titleLabel constraints
        titleLabel.snp.removeConstraints()
        
        // Update spacing
        containerStackView.spacing = iconSpacing
        
        // Update axis and order based on position
        switch iconPosition {
        case .left:
            containerStackView.axis = .horizontal
            if !iconImageView.isHidden {
                containerStackView.addArrangedSubview(iconImageView)
                if iconSize != .zero {
                    iconImageView.snp.makeConstraints { make in
                        make.size.equalTo(iconSize)
                    }
                }
            }
            if !titleLabel.isHidden {
                containerStackView.addArrangedSubview(titleLabel)
            }
            
        case .right:
            containerStackView.axis = .horizontal
            if !titleLabel.isHidden {
                containerStackView.addArrangedSubview(titleLabel)
            }
            if !iconImageView.isHidden {
                containerStackView.addArrangedSubview(iconImageView)
                if iconSize != .zero {
                    iconImageView.snp.makeConstraints { make in
                        make.size.equalTo(iconSize)
                    }
                }
            }
            
        case .top:
            containerStackView.axis = .vertical
            if !iconImageView.isHidden {
                containerStackView.addArrangedSubview(iconImageView)
                if iconSize != .zero {
                    iconImageView.snp.makeConstraints { make in
                        make.size.equalTo(iconSize)
                    }
                }
            }
            if !titleLabel.isHidden {
                containerStackView.addArrangedSubview(titleLabel)
                titleLabel.snp.makeConstraints { make in
                    make.width.lessThanOrEqualTo(self.snp.width).priority(.required)
                }
            }
            
        case .bottom:
            containerStackView.axis = .vertical
            if !titleLabel.isHidden {
                containerStackView.addArrangedSubview(titleLabel)
                titleLabel.snp.makeConstraints { make in
                    make.width.lessThanOrEqualTo(self.snp.width).priority(.required)
                }
            }
            if !iconImageView.isHidden {
                containerStackView.addArrangedSubview(iconImageView)
                if iconSize != .zero {
                    iconImageView.snp.makeConstraints { make in
                        make.size.equalTo(iconSize)
                    }
                }
            }
        }
        
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - Intrinsic Content Size
    
    public override var intrinsicContentSize: CGSize {
        let stackSize = containerStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return stackSize
    }
}
