import AtomicXCore
import SnapKit
import UIKit

final class JoinGroupDetailViewController: ChatSettingBaseViewController {
    private static let cardHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let cardVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let avatarTextSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let nameIDSpacing: CGFloat = 2

    private static let identityFontSize: CGFloat = 12

    private static let sectionTitleTop: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let sectionTitleBottom: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let inputCardPadding: CGFloat = 14

    private static let inputCardMinHeight: CGFloat = 120

    private static let sectionSpacerHeight: CGFloat = 10

    private static let actionRowHeight: CGFloat = 52

    private static let toastDuration: TimeInterval = 2

    private let groupInfo: GroupInfo

    private let dismissAll: () -> Void

    private let scrollView = UIScrollView()

    private let contentStack = UIStackView()

    private let infoCard = UIView()

    private let avatar = ChatAvatarView(size: .l, isRound: false)

    private let nameLabel = UILabel()

    private let idLabel = UILabel()

    private let sectionTitleContainer = UIView()

    private let sectionTitleLabel = UILabel()

    private let inputCard = UIView()

    private let wordingTextView = UITextView()

    private let spacerView = UIView()

    private let sendButton = UIButton(type: .custom)

    private var isSending = false

    init(groupInfo: GroupInfo, dismissAll: @escaping () -> Void) {
        self.groupInfo = groupInfo
        self.dismissAll = dismissAll
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    // MARK: - Send

    private func constructViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        infoCard.addSubview(avatar)
        infoCard.addSubview(nameLabel)
        infoCard.addSubview(idLabel)
        inputCard.addSubview(wordingTextView)
        sectionTitleContainer.addSubview(sectionTitleLabel)
        contentStack.addArrangedSubview(infoCard)
        contentStack.addArrangedSubview(sectionTitleContainer)
        contentStack.addArrangedSubview(inputCard)
        contentStack.addArrangedSubview(spacerView)
        contentStack.addArrangedSubview(sendButton)
    }

    private func activateConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        avatar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.cardHorizontalPadding)
            make.top.equalToSuperview().offset(Self.cardVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.cardVerticalPadding)
            make.width.height.equalTo(ChatAvatarSize.l.size)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatar.snp.trailing).offset(Self.avatarTextSpacing)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.cardHorizontalPadding)
            make.centerY.equalTo(avatar).offset(-(Self.identityFontSize + Self.nameIDSpacing) / 2)
        }
        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(Self.nameIDSpacing)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.cardHorizontalPadding)
        }
        wordingTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.inputCardPadding)
        }
        inputCard.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.inputCardMinHeight)
        }
        sectionTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.cardHorizontalPadding)
            make.top.equalToSuperview().offset(Self.sectionTitleTop)
            make.bottom.equalToSuperview().offset(-Self.sectionTitleBottom)
        }
        spacerView.snp.makeConstraints { make in
            make.height.equalTo(Self.sectionSpacerHeight)
        }
        sendButton.snp.makeConstraints { make in
            make.height.equalTo(Self.actionRowHeight)
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorDefault
        setNavTitle(LocalizedChatString("GroupDetailTitle"))
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill

        infoCard.backgroundColor = colors.bgColorOperate
        let name = ContactDisplayFormatter.name(for: groupInfo)
        avatar.configure(avatarURL: groupInfo.avatarURL, fallbackName: name)
        nameLabel.text = name
        nameLabel.font = FontScheme.caption1Bold
        nameLabel.textColor = colors.textColorPrimary
        idLabel.text = String(
            format: LocalizedChatString("ContactLabelValueFormat"),
            LocalizedChatString("GroupID"),
            groupInfo.groupID
        )
        idLabel.font = .systemFont(ofSize: Self.identityFontSize)
        idLabel.textColor = colors.textColorSecondary

        sectionTitleLabel.text = LocalizedChatString("FillVerificationInfo")
        sectionTitleLabel.font = FontScheme.caption2Regular
        sectionTitleLabel.textColor = colors.textColorSecondary

        inputCard.backgroundColor = colors.bgColorOperate
        wordingTextView.backgroundColor = .clear
        wordingTextView.font = FontScheme.caption1Regular
        wordingTextView.textColor = colors.textColorPrimary
        wordingTextView.textContainer.lineFragmentPadding = 0
        wordingTextView.text = Self.defaultWording()

        spacerView.backgroundColor = colors.bgColorDefault

        sendButton.setTitle(LocalizedChatString("Send"), for: .normal)
        sendButton.setTitleColor(colors.textColorLink, for: .normal)
        sendButton.titleLabel?.font = FontScheme.caption1Regular
        sendButton.backgroundColor = colors.bgColorOperate
    }

    private func bindInteraction() {
        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        scrollView.keyboardDismissMode = .onDrag
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        backgroundTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(backgroundTap)
    }

    private static func defaultWording() -> String {
        let loginInfo = LoginStore.shared.state.value.loginUserInfo
        let nickname = loginInfo?.nickname ?? ""
        let displayName = !nickname.isEmpty ? nickname : loginInfo?.userID ?? ""
        return String(format: LocalizedChatString("ContactListAddWordingIAm"), displayName)
    }

    @objc private func handleSend() {
        guard !isSending else { return }
        if GroupStore.shared.state.value.joinedGroupList.contains(where: { $0.groupID == groupInfo.groupID }) {
            WindowToastManager.shared.show(LocalizedChatString("AlreadyGroupMember"), type: .error, duration: Self.toastDuration)
            return
        }
        setSending(true)
        GroupStore.shared.joinGroup(
            groupID: groupInfo.groupID,
            message: wordingTextView.text,
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleJoinResult(result)
                }
            }
        )
    }

    private func handleJoinResult(_ result: Result<Void, ErrorInfo>) {
        setSending(false)
        switch result {
        case .success:
            WindowToastManager.shared.show(LocalizedChatString("GroupJoinRequestSent"), type: .success, duration: Self.toastDuration)
            dismissAll()
        case .failure(let error):
            WindowToastManager.shared.show(groupErrorText(code: error.code), type: .error, duration: Self.toastDuration)
        }
    }

    private func groupErrorText(code: Int) -> String {
        switch code {
        case 10013: return LocalizedChatString("AlreadyGroupMember")
        case 10010: return LocalizedChatString("GroupNotFound")
        case 10015: return LocalizedChatString("GroupJoinRequestAlreadySent")
        case 10016: return LocalizedChatString("GroupJoinForbidden")
        default: return LocalizedChatString("GroupJoinRequestFailed")
        }
    }

    private func setSending(_ sending: Bool) {
        isSending = sending
        sendButton.isEnabled = !sending
        sendButton.setTitle(
            sending ? LocalizedChatString("Joining") : LocalizedChatString("Send"),
            for: .normal
        )
    }

    @objc private func handleBackgroundTapped() {
        view.endEditing(true)
    }
}
