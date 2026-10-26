//
//  RoomScheduleView+Factory.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import SnapKit
import Kingfisher

// MARK: - Layout constants
enum RoomScheduleLayout {
    static let horizontalPadding: CGFloat = 16
    static let cardInnerPadding: CGFloat = 20
    static let rowHeight: CGFloat = 50
    static let cardCornerRadius: CGFloat = 10
    static let buttonHeight: CGFloat = 44
    static let buttonHorizontalInset: CGFloat = 16
    static let navBarHeight: CGFloat = 60
    static let backButtonSize: CGFloat = 16
    static let navBarTopInset: CGFloat = 22
    static let topSpacingAfterNav: CGFloat = 20
    static let cardSpacing: CGFloat = 12
    static let chevronSize: CGFloat = 16
    static let passwordDigits: Int = 6
}

// MARK: - Chevron direction (accessory arrow on the right edge of a row)
public enum RoomScheduleChevronDirection {
    case right
    case down
    case none
}

// MARK: - Participants value view
final class RoomScheduleParticipantsValueView: UIView {

    private enum Layout {
        static let avatarSize: CGFloat = 24
        static let avatarSpacing: CGFloat = 8
        static let maxAvatars: Int = 3
        static let avatarToTextSpacing: CGFloat = 8
    }

    private let countLabel = UILabel()

    private lazy var avatarStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: avatarImageViews)
        stack.axis = .horizontal
        stack.spacing = Layout.avatarSpacing
        stack.alignment = .center
        return stack
    }()

    private let avatarImageViews: [UIImageView] = (0..<Layout.maxAvatars).map { _ in
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Layout.avatarSize / 2
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.white.cgColor
        iv.snp.makeConstraints { $0.width.height.equalTo(Layout.avatarSize) }
        return iv
    }

    init() {
        super.init(frame: .zero)
        setupSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupSubviews() {
        addSubview(avatarStackView)
        addSubview(countLabel)

        countLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        countLabel.textColor = RoomColors.valueText
        countLabel.textAlignment = .right
        countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        avatarStackView.setContentHuggingPriority(.required, for: .horizontal)
        avatarStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupConstraints() {
        countLabel.snp.makeConstraints { make in
            make.right.centerY.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview()
        }
        avatarStackView.snp.makeConstraints { make in
            make.right.equalTo(countLabel.snp.left).offset(-Layout.avatarToTextSpacing)
            make.left.greaterThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    func update(avatarURLs: [String?], countText: String?, placeholder: String?) {
        let urls = Array(avatarURLs.prefix(Layout.maxAvatars))
        let hasAttendees = !urls.isEmpty

        for (index, iv) in avatarImageViews.enumerated() {
            if index < urls.count {
                iv.isHidden = false
                if let urlString = urls[index], let url = URL(string: urlString) {
                    iv.kf.setImage(with: url,
                                   placeholder: ResourceLoader.loadImage("avatar_placeholder"))
                } else {
                    iv.image = ResourceLoader.loadImage("avatar_placeholder")
                }
            } else {
                iv.isHidden = true
                iv.image = nil
            }
        }

        avatarStackView.isHidden = !hasAttendees
        countLabel.text = hasAttendees ? countText : placeholder
    }
}

// MARK: - Factory Helpers
extension RoomScheduleView {
    
    func makeLabel(_ text: String,
                   color: UIColor = RoomColors.g2,
                   weight: UIFont.Weight = .regular) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: weight)
        label.textColor = color
        return label
    }
    
    /// Right-side value label (grey, right-aligned).
    func makeValueLabel(placeholder: String = "") -> UILabel {
        let label = UILabel()
        label.text = placeholder
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.valueText
        label.textAlignment = .right
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    
    func makeParticipantsValueView() -> RoomScheduleParticipantsValueView {
        return RoomScheduleParticipantsValueView()
    }
    
    func makeValueField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        field.textColor = RoomColors.valueText
        field.textAlignment = .right
        field.borderStyle = .none
        field.clearButtonMode = .never
        field.returnKeyType = .done
        field.delegate = self
        field.inputAccessoryView = makeKeyboardDoneToolbar()
        let placeholderColor = RoomColors.g3.withAlphaComponent(0.4)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: RoomFonts.pingFangSCFont(size: 16, weight: .regular),
            ]
        )
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    
    func makeKeyboardDoneToolbar() -> UIToolbar {
        let initialFrame = CGRect(x: 0,
                                  y: 0,
                                  width: UIScreen.main.bounds.width,
                                  height: 44)
        let toolbar = UIToolbar(frame: initialFrame)
        toolbar.autoresizingMask = [.flexibleWidth]
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                       target: nil,
                                       action: nil)
        let done = UIBarButtonItem(title: .factoryConfirm,
                                   style: .done,
                                   target: self,
                                   action: #selector(handleKeyboardDoneTapped))
        done.tintColor = RoomColors.b1
        toolbar.items = [flexible, done]
        toolbar.sizeToFit()
        return toolbar
    }
    
    func makeSwitch() -> UISwitch {
        let toggle = UISwitch()
        toggle.onTintColor = RoomColors.b1
        return toggle
    }
    
    func makeCardStackView() -> UIStackView {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.backgroundColor = .white
        sv.layer.cornerRadius = RoomScheduleLayout.cardCornerRadius
        sv.clipsToBounds = true
        sv.layoutMargins = UIEdgeInsets(top: 0,
                                        left: RoomScheduleLayout.cardInnerPadding,
                                        bottom: 0,
                                        right: RoomScheduleLayout.cardInnerPadding)
        sv.isLayoutMarginsRelativeArrangement = true
        return sv
    }
    
    func makeAccessoryRow(_ title: UILabel,
                          _ value: UIView,
                          chevron: RoomScheduleChevronDirection) -> UIStackView {
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        var arrangedViews: [UIView] = [title, value]
        
        if chevron != .none {
            let chevronView = UIImageView(image: ResourceLoader.loadImage("room_schedule_arrow"))
            chevronView.contentMode = .scaleAspectFit
            if chevron == .right {
                chevronView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
            }
            chevronView.setContentHuggingPriority(.required, for: .horizontal)
            chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)
            chevronView.snp.makeConstraints { make in
                make.width.height.equalTo(RoomScheduleLayout.chevronSize)
            }
            arrangedViews.append(chevronView)
        }
        
        let row = UIStackView(arrangedSubviews: arrangedViews)
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.isUserInteractionEnabled = true
        row.snp.makeConstraints { $0.height.equalTo(RoomScheduleLayout.rowHeight) }
        return row
    }
    
    func makeSwitchRow(_ title: String, _ switchView: UISwitch) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [makeLabel(title), switchView])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fill
        row.snp.makeConstraints { $0.height.equalTo(RoomScheduleLayout.rowHeight) }
        return row
    }
    
    func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = RoomColors.g8
        line.snp.makeConstraints { $0.height.equalTo(1.0 / UIScreen.main.scale) }
        return line
    }
}

private extension String {
    static let factoryConfirm = "roomkit_confirm".localized
}
