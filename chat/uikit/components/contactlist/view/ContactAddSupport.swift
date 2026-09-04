import AtomicXCore
import SnapKit
import UIKit

final class ContactSearchResultCell: UIControl {
    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let verticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let avatarSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private let avatar = ChatAvatarView(size: .l, isRound: false)

    private let textColumn = UIStackView()

    private let nameLabel = UILabel()

    private let identityLabel = UILabel()

    private let tipLabel = UILabel()

    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(avatarURL: String?, name: String, identityLabelText: String, identityValue: String, tip: String? = nil) {
        avatar.configure(avatarURL: avatarURL, fallbackName: name)
        nameLabel.text = name
        let colors = TUIChatKitTheme.colors
        let fullText = String(format: LocalizedChatString("ContactLabelValueFormat"), identityLabelText, identityValue)
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [.foregroundColor: colors.textColorSecondary]
        )
        if let valueRange = fullText.range(of: identityValue) {
            attributed.addAttribute(.foregroundColor, value: colors.textColorLink, range: NSRange(valueRange, in: fullText))
        }
        identityLabel.attributedText = attributed
        tipLabel.text = tip
        tipLabel.isHidden = tip == nil
    }

    private func constructViewHierarchy() {
        textColumn.axis = .vertical
        textColumn.spacing = 0
        textColumn.addArrangedSubview(nameLabel)
        textColumn.addArrangedSubview(identityLabel)
        addSubview(avatar)
        addSubview(textColumn)
        addSubview(tipLabel)
    }

    private func activateConstraints() {
        avatar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.width.height.equalTo(ChatAvatarSize.l.size)
        }
        textColumn.snp.makeConstraints { make in
            make.leading.equalTo(avatar.snp.trailing).offset(Self.avatarSpacing)
            make.centerY.equalTo(avatar)
            make.trailing.lessThanOrEqualTo(tipLabel.snp.leading).offset(-Self.avatarSpacing)
        }
        tipLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        tipLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        nameLabel.font = FontScheme.caption1Regular
        nameLabel.textColor = colors.textColorPrimary
        identityLabel.font = FontScheme.caption3Regular
        identityLabel.textColor = colors.textColorSecondary
        tipLabel.font = FontScheme.caption3Regular
        tipLabel.textColor = colors.textColorSecondary
    }

    @objc private func handleTap() {
        handler()
    }
}

// MARK: - Store Completion Handlers

final class ContactLookupHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}

final class GroupLookupHandler: GetGroupInfoCompletionHandler {
    private let onSuccessBlock: (GroupInfo) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (GroupInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(groupInfo: GroupInfo) {
        onSuccessBlock(groupInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
