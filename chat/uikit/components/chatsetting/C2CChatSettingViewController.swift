import AtomicXCore
import Combine
import SnapKit
import TUICallKit_Swift
import UIKit

public final class C2CChatSettingViewController: ChatSettingBaseViewController {
    private static let headerAvatarSize = ChatAvatarSize.l

    private static let headerSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let headerSubFontSize: CGFloat = 13

    private static let headerIDTopSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let headerSignatureTopSpacing: CGFloat = 2

    private static let toastDuration: TimeInterval = 2

    private let userID: String

    private let contactStore: ContactStore

    private let conversationStore: ConversationListStore

    private let onSendMessageClick: (() -> Void)?

    private let onContactDelete: (() -> Void)?

    private let config: C2CChatSettingConfigProtocol

    private var remark: String = ""

    private var nick: String = ""

    private var avatar: String = ""

    private var aboutMe: String = ""

    private var isNotDisturb: Bool = false

    private var isPinned: Bool = false

    private var isInBlacklist: Bool = false

    private var chatBackgroundURI: String?

    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()

    private let stackView = UIStackView()

    private let headerView = UIView()

    private let avatarView = ChatAvatarView(size: .l, isRound: false)

    private let nameLabel = UILabel()

    private let userIDLabel = UILabel()

    private let signatureLabel = UILabel()

    private let headerTextStack = UIStackView()

    private lazy var remarkRow = ChatSettingRowView(title: LocalizedChatString("ProfileAlia"), accessory: .arrow)

    private lazy var doNotDisturbRow = ChatSettingToggleRowView(title: LocalizedChatString("ProfileMessageDoNotDisturb"))

    private lazy var pinRow = ChatSettingToggleRowView(title: LocalizedChatString("ProfileStickyonTop"))

    private lazy var backgroundRow = ChatSettingRowView(title: LocalizedChatString("ChatBackgroundSetting"), accessory: .arrow)

    private lazy var blacklistRow = ChatSettingToggleRowView(title: LocalizedChatString("ProfileBlocked"))

    private var conversationID: String {
        return ChatUtil.getC2CConversationID(userID)
    }

    private var displayName: String {
        return nick.isEmpty ? userID : nick
    }

    public init(
        userID: String,
        config: C2CChatSettingConfigProtocol = C2CChatSettingConfig(),
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil
    ) {
        self.userID = userID
        self.contactStore = ContactStore.shared
        self.conversationStore = ConversationListStore.create()
        self.config = config
        self.onSendMessageClick = onSendMessageClick
        self.onContactDelete = onContactDelete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("ProfileContactInfo"))
        constructViewHierarchy()
        applyCustomItems()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        subscribeStores()
        fetchInitialInfo()
        chatBackgroundURI = ChatBackgroundStore.shared.imageURI(forConversationID: conversationID)
        refreshUI()
    }

    // MARK: - Actions

    private func constructViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        headerView.addSubview(avatarView)
        headerTextStack.addArrangedSubview(nameLabel)
        headerTextStack.addArrangedSubview(userIDLabel)
        headerTextStack.addArrangedSubview(signatureLabel)
        headerView.addSubview(headerTextStack)

        var sections: [(UIView, Bool)] = [
            (headerView, config.isShowHeader),
            (remarkRow, config.isShowRemark),
        ]
        if let switchSection = makeSwitchSection() {
            sections.append((switchSection, true))
        }
        sections.append((backgroundRow, config.isShowChatBackground))
        sections.append((blacklistRow, config.isShowBlacklist))
        if let actionSection = makeActionSection() {
            sections.append((actionSection, true))
        }

        var isFirstVisible = true
        for (sectionView, isVisible) in sections where isVisible {
            if !isFirstVisible {
                stackView.addArrangedSubview(makeChatSettingSectionSpacer())
            }
            stackView.addArrangedSubview(sectionView)
            isFirstVisible = false
        }
    }

    private func makeSwitchSection() -> UIStackView? {
        var rows: [UIView] = []
        if config.isShowDoNotDisturb {
            rows.append(doNotDisturbRow)
        }
        if config.isShowPin {
            rows.append(pinRow)
        }
        guard !rows.isEmpty else { return nil }
        var arranged: [UIView] = []
        for (index, row) in rows.enumerated() {
            if index > 0 {
                arranged.append(makeChatSettingRowDivider())
            }
            arranged.append(row)
        }
        return makeSectionContainer(arrangedSubviews: arranged)
    }

    private func makeSectionContainer(arrangedSubviews: [UIView]) -> UIStackView {
        let section = UIStackView(arrangedSubviews: arrangedSubviews)
        section.axis = .vertical
        section.spacing = 0
        section.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        return section
    }

    private func makeActionRow(titleKey: String, textColor: UIColor, action: Selector) -> ChatSettingActionRowView {
        let row = ChatSettingActionRowView(title: LocalizedChatString(titleKey), textColor: textColor)
        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    private func makeActionSection() -> UIStackView? {
        let colors = TUIChatKitTheme.colors
        var rows: [UIView] = []
        if config.isShowSendMessage {
            rows.append(makeActionRow(titleKey: "ProfileSendMessages", textColor: colors.textColorLink, action: #selector(handleSendMessageTapped)))
        }
        if config.isShowVoiceCall {
            rows.append(makeActionRow(titleKey: "MoreVoiceCall", textColor: colors.textColorLink, action: #selector(handleVoiceCallTapped)))
        }
        if config.isShowVideoCall {
            rows.append(makeActionRow(titleKey: "MoreVideoCall", textColor: colors.textColorLink, action: #selector(handleVideoCallTapped)))
        }
        if config.isShowClearHistory {
            rows.append(makeActionRow(titleKey: "ClearAllChatHistory", textColor: colors.textColorError, action: #selector(handleClearHistoryTapped)))
        }
        if config.isShowDeleteFriend {
            rows.append(makeActionRow(titleKey: "ProfileDeleteFirend", textColor: colors.textColorError, action: #selector(handleDeleteFriendTapped)))
        }
        guard !rows.isEmpty else { return nil }
        var arranged: [UIView] = []
        for (index, row) in rows.enumerated() {
            if index > 0 {
                arranged.append(makeChatSettingRowDivider())
            }
            arranged.append(row)
        }
        return makeSectionContainer(arrangedSubviews: arranged)
    }

    private func applyCustomItems() {
        guard let customizer = config.itemCustomizer else { return }
        let editor = ChatSettingItemEditor<C2CChatSettingSection>()
        customizer(editor)
        var lastInsertedByAnchor: [UIView] = []
        for (section, row) in editor.customRows {
            guard let anchor = anchorView(for: section) else {
                stackView.addArrangedSubview(row)
                continue
            }
            let base = lastInsertedByAnchor.first(where: { $0 === anchor }) ?? anchor
            if let index = stackView.arrangedSubviews.firstIndex(of: base) {
                stackView.insertArrangedSubview(row, at: index + 1)
            } else {
                stackView.addArrangedSubview(row)
            }
            lastInsertedByAnchor.removeAll { $0 === anchor }
            lastInsertedByAnchor.append(row)
        }
    }

    private func anchorView(for section: C2CChatSettingSection) -> UIView? {
        switch section {
        case .header: return config.isShowHeader ? headerView : nil
        case .remark: return config.isShowRemark ? remarkRow : nil
        case .switches: return stackView.arrangedSubviews.first { $0 is UIStackView && ($0 as? UIStackView)?.arrangedSubviews.contains(where: { $0 === doNotDisturbRow || $0 === pinRow }) == true }
        case .background: return config.isShowChatBackground ? backgroundRow : nil
        case .blacklist: return config.isShowBlacklist ? blacklistRow : nil
        case .actions: return stackView.arrangedSubviews.last
        case .end: return nil
        }
    }

    private func activateConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.headerHorizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.headerAvatarSize.size)
        }
        headerTextStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.headerSpacing)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.headerHorizontalPadding)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Self.headerVerticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.headerVerticalPadding)
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorTopBar
        scrollView.backgroundColor = colors.bgColorTopBar
        stackView.axis = .vertical
        stackView.spacing = 0
        headerView.backgroundColor = colors.bgColorOperate
        headerTextStack.axis = .vertical
        headerTextStack.spacing = 0
        nameLabel.font = FontScheme.body4Regular
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        userIDLabel.font = .systemFont(ofSize: Self.headerSubFontSize)
        userIDLabel.textColor = colors.textColorTertiary
        userIDLabel.lineBreakMode = .byTruncatingTail
        signatureLabel.font = .systemFont(ofSize: Self.headerSubFontSize)
        signatureLabel.textColor = colors.textColorTertiary
        signatureLabel.lineBreakMode = .byTruncatingTail
        headerTextStack.setCustomSpacing(Self.headerIDTopSpacing, after: nameLabel)
        headerTextStack.setCustomSpacing(Self.headerSignatureTopSpacing, after: userIDLabel)
    }

    private func bindInteraction() {
        remarkRow.addTarget(self, action: #selector(handleRemarkTapped), for: .touchUpInside)
        backgroundRow.addTarget(self, action: #selector(handleBackgroundTapped), for: .touchUpInside)
        doNotDisturbRow.onToggle = { [weak self] value in self?.setDoNotDisturb(value) }
        pinRow.onToggle = { [weak self] value in self?.setPinned(value) }
        blacklistRow.onToggle = { [weak self] value in self?.setBlacklist(value) }
    }

    private func subscribeStores() {
        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friendList in
                guard let self = self else { return }
                if let contactInfo = friendList.first(where: { $0.userID == self.userID }) {
                    self.applyContactInfo(contactInfo)
                }
            }
            .store(in: &cancellables)
        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.blackList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blackList in
                guard let self = self else { return }
                self.isInBlacklist = blackList.contains(where: { $0.userID == self.userID })
                self.blacklistRow.setOn(self.isInBlacklist)
            }
            .store(in: &cancellables)
        conversationStore.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.conversationList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversationList in
                guard let self = self else { return }
                if let conversationInfo = conversationList.first(where: { $0.conversationID == self.conversationID }) {
                    self.applyConversationInfo(conversationInfo)
                }
            }
            .store(in: &cancellables)
    }

    private func fetchInitialInfo() {
        contactStore.loadFriends(completion: nil)
        contactStore.loadBlackList(completion: nil)
        contactStore.getContactInfo(
            userIDList: [userID],
            completion: C2CSettingContactInfoHandler(
                onSuccess: { [weak self] contactInfoList in
                    DispatchQueue.main.async {
                        if let contactInfo = contactInfoList.first {
                            self?.applyContactInfo(contactInfo)
                        }
                    }
                },
                onFailure: { _, _ in }
            )
        )
        conversationStore.getConversationInfo(
            conversationID: conversationID,
            completion: C2CSettingConversationInfoHandler(
                onSuccess: { [weak self] conversationInfo in
                    DispatchQueue.main.async {
                        self?.applyConversationInfo(conversationInfo)
                    }
                },
                onFailure: { _, _ in }
            )
        )
    }

    private func applyContactInfo(_ contactInfo: ContactInfo) {
        if let friendRemark = contactInfo.friendRemark {
            remark = friendRemark
        }
        if let nickname = contactInfo.nickname {
            nick = nickname
        }
        if let avatarURL = contactInfo.avatarURL {
            avatar = avatarURL
        }
        if let signature = contactInfo.aboutMe {
            aboutMe = signature
        }
        refreshUI()
    }

    private func applyConversationInfo(_ conversationInfo: ConversationInfo) {
        isNotDisturb = conversationInfo.receiveOption != .receive
        isPinned = conversationInfo.isPinned
        refreshUI()
    }

    private func refreshUI() {
        avatarView.configure(avatarURL: avatar, fallbackName: displayName)
        nameLabel.text = displayName
        userIDLabel.text = "\(LocalizedChatString("ProfileUserID")): \(userID)"
        signatureLabel.text = aboutMe.isEmpty ? nil : LocalizedChatString("ProfileSignaturePrefix") + aboutMe
        signatureLabel.isHidden = aboutMe.isEmpty
        remarkRow.update(value: remark.isEmpty ? displayName : remark, accessory: .arrow)
        doNotDisturbRow.setOn(isNotDisturb)
        pinRow.setOn(isPinned)
        blacklistRow.setOn(isInBlacklist)
        backgroundRow.update(
            value: chatBackgroundURI == nil
                ? LocalizedChatString("ChatBackgroundDefault")
                : LocalizedChatString("ChatBackgroundCustom"),
            accessory: .arrow
        )
    }

    @objc private func handleRemarkTapped() {
        let dialog = TextInputDialogViewController(
            title: LocalizedChatString("ProfileEditAlia"),
            initialText: remark
        ) { [weak self] text in
            self?.saveRemark(text)
        }
        present(dialog, animated: true)
    }

    @objc private func handleBackgroundTapped() {
        let picker = ChatBackgroundPickerViewController(conversationID: conversationID) { [weak self] uri in
            guard let self = self else { return }
            ChatBackgroundStore.shared.setImageURI(uri, forConversationID: self.conversationID)
            self.chatBackgroundURI = uri
            self.refreshUI()
        }
        present(picker, animated: true)
    }

    @objc private func handleSendMessageTapped() {
        onSendMessageClick?()
    }

    @objc private func handleVoiceCallTapped() {
        startCall(mediaType: .audio)
    }

    @objc private func handleVideoCallTapped() {
        startCall(mediaType: .video)
    }

    @objc private func handleClearHistoryTapped() {
        let alert = UIAlertController(
            title: LocalizedChatString("ClearContactHistoryTips"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("AlertConfirm"), style: .default) { [weak self] _ in
            self?.clearHistory()
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleDeleteFriendTapped() {
        let alert = UIAlertController(
            title: LocalizedChatString("DeleteFriendConfirmTips"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("AlertConfirm"), style: .destructive) { [weak self] _ in
            self?.deleteFriend()
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func startCall(mediaType: CallMediaType) {
        DataReport.reportInteractionMetrics(.chatInvokeCall)
        TUICallKit.createInstance().calls(
            userIdList: [userID],
            mediaType: mediaType,
            params: nil,
            completion: nil
        )
    }

    private func setDoNotDisturb(_ value: Bool) {
        let opt: ReceiveMessageOption = value ? .notNotify : .receive
        conversationStore.setReceiveMessageOpt(conversationID: conversationID, opt: opt, completion: nil)
    }

    private func setPinned(_ value: Bool) {
        conversationStore.pinConversation(conversationID: conversationID, pin: value, completion: nil)
    }

    private func setBlacklist(_ value: Bool) {
        if value {
            contactStore.addToBlacklist(userID: userID) { [weak self] result in
                if case .success = result {
                    self?.contactStore.loadBlackList(completion: nil)
                }
            }
        } else {
            contactStore.removeFromBlacklist(userID: userID) { [weak self] result in
                if case .success = result {
                    self?.contactStore.loadBlackList(completion: nil)
                }
            }
        }
    }

    private func saveRemark(_ text: String) {
        contactStore.setFriendRemark(userID: userID, remark: text, completion: nil)
    }

    private func deleteFriend() {
        contactStore.deleteFriend(userID: userID) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if case .success = result {
                    self.conversationStore.deleteConversation(conversationID: self.conversationID, completion: nil)
                }
                if let onContactDelete = self.onContactDelete {
                    onContactDelete()
                } else if let navigationController = self.navigationController {
                    navigationController.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            }
        }
    }

    private func clearHistory() {
        conversationStore.clearConversationMessages(conversationID: conversationID) { result in
            if case .success = result {
                DispatchQueue.main.async {
                    WindowToastManager.shared.show(LocalizedChatString("ClearAllChatHistory"), type: .success, duration: Self.toastDuration)
                }
            }
        }
    }
}

private final class C2CSettingContactInfoHandler: GetContactInfoCompletionHandler {
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

private final class C2CSettingConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessBlock: (ConversationInfo) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessBlock(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
