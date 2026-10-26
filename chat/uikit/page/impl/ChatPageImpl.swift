import Foundation
import AtomicXCore
import Combine
import SnapKit
import UIKit

internal final class ChatPageImpl: PageImplementation {
    private static let navBarHeight: CGFloat = 48

    private static let navHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let backButtonSize: CGFloat = 28

    private static let moreButtonSize: CGFloat = 24

    private static let backIconSlotWidth: CGFloat = 16

    private static let unreadBadgeSize: CGFloat = 22

    private static let unreadBadgeLeadingGap: CGFloat = 2

    private static let unreadBadgeHorizontalPadding: CGFloat = 6

    private static let failureBarSideInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let failureBarBottomSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let failureBarHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let failureBarVerticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let failureBarMinHeight: CGFloat = 40

    private static let failureBarIconSize: CGFloat = 16

    private static let failureBarIconTextGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let failureBarMaxTextWidth: CGFloat = 340

    private static let failureBarDisplayDuration: TimeInterval = 3

    private static let failureBarFadeDuration: TimeInterval = 0.25

    private static let dividerHeight: CGFloat = 0.5

    private static let titleCenterXPriority = UILayoutPriority(rawValue: 750)

    private static let failureBarCornerRadius: CGFloat = 6

    private static let failureBarMaxLineCount: Int = 3

    private static let backIconFallbackPointSize: CGFloat = 18

    private static let unreadBadgeMaxCount: Int = 99

    private static let titleFontSize: CGFloat = 17

    private static let moreIconPointSize: CGFloat = 20

    private let conversation: ConversationInfo

    private let locateMessage: MessageInfo?

    private let onBack: (() -> Void)?

    private let onUserClick: ((String) -> Void)?

    private let onMoreClick: (() -> Void)?

    private let isShowMoreButton: Bool

    private let showsNavigationBar: Bool

    private let navigationBar = UIView()

    private let backButton = ExpandedHitButton(type: .system)

    private let unreadBadgeView = UIView()

    private let unreadBadgeLabel = UILabel()

    private let titleLabel = UILabel()

    private let moreButton = UIButton(type: .system)

    private let cancelMultiSelectButton = UIButton(type: .system)

    private let divider = UIView()

    private let sendFailureBar = UIView()

    private let sendFailureIconView = UIImageView()

    private let sendFailureLabel = UILabel()

    private var sendFailureHideWorkItem: DispatchWorkItem?

    private let conversationListStore = ConversationListStore.create()

    private var unreadCancellable: AnyCancellable?

    private var isInMultiSelectMode = false

    private var latestUnreadTotal: Int64 = 0

    private let messageInputConfig: MessageInputConfigProtocol

    private let messageListConfig: ChatMessageListConfig

    /// 机器人（@RBT#）会话的回复状态控制器，非机器人会话为 nil。
    private var chatbotController: ChatbotConversationController?

    private var typingCancellable: AnyCancellable?

    private lazy var messageListView: MessageListView = {
        let view = MessageListView(
            conversationID: conversation.id,

            config: messageListConfig,
            locateMessage: locateMessage,
            chatbotController: chatbotController,
            onUserClick: { [weak self] userID in
                // 机器人账号没有资料页，点击不跳转，对齐 Android ChatPageView 的过滤
                if !ChatbotConversationPolicy.isChatbotID(userID) {
                    self?.onUserClick?(userID)
                }
            },
            onMultiSelectModeChange: { [weak self] isMultiSelect in
                self?.updateInputVisibility(multiSelect: isMultiSelect)
            }
        )
        return view
    }()

    private var createdMessageInputView: MessageInputView?

    private lazy var messageInputView: MessageInputView = {
        let view = MessageInputView(
            conversationID: conversation.id,
            config: messageInputConfig,
            chatbotController: chatbotController
        )
        view.onSendFailure = { [weak self] reason in
            self?.showSendFailure(reason)
        }
        createdMessageInputView = view
        return view
    }()

    private var inputCollapseConstraint: NSLayoutConstraint?

    internal var topBannerView: UIView? {
        didSet {
            guard oldValue !== topBannerView else { return }
            oldValue?.removeFromSuperview()
            updateTopBannerLayout()
        }
    }

    // MARK: - Init

    internal init(
        conversation: ConversationInfo,
        locateMessage: MessageInfo? = nil,
        messageListConfig: ChatMessageListConfig = ChatMessageListConfig(isShowRightAvatar: true),
        messageInputConfig: ChatMessageInputConfig = ChatMessageInputConfig(),
        isShowMoreButton: Bool = true,
        showsNavigationBar: Bool = true,
        onBack: (() -> Void)? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMoreClick: (() -> Void)? = nil
    ) {
        self.conversation = conversation
        self.locateMessage = locateMessage
        self.showsNavigationBar = showsNavigationBar
        var listConfig = messageListConfig
        listConfig.excludeCustomMessagesByBusinessID(MessageInputView.typingMessageBusinessID)
        var effectiveInputConfig: MessageInputConfigProtocol = messageInputConfig
        // 机器人会话：创建回复状态控制器，并套用机器人专用的输入配置，
        // 对齐 Android ChatPageView.setup 的 setupWithChatbot 路径
        if ChatbotConversationPolicy.isChatbotConversation(conversation.id) {
            NSLog("[ChatbotPlaceholderDiag] ChatPage wiring chatbotController, conversation=\(conversation.id)")
            chatbotController = ChatbotConversationControllers.acquire(conversation.id)
            effectiveInputConfig = ChatbotMessageInputConfig(base: effectiveInputConfig)
        }
        self.messageListConfig = listConfig
        self.messageInputConfig = effectiveInputConfig
        self.onBack = onBack
        self.onUserClick = onUserClick
        self.onMoreClick = onMoreClick
        self.isShowMoreButton = isShowMoreButton
        super.init()
    }

    deinit {
        unreadCancellable?.cancel()
        sendFailureHideWorkItem?.cancel()
        typingCancellable?.cancel()
        createdMessageInputView?.invalidateTypingIndicator()
        if let controller = chatbotController {
            ChatbotConversationControllers.release(conversation.id, controller: controller)
        }
        NotificationCenter.default.removeObserver(self, name: ChatBackgroundStore.didChangeNotification, object: nil)
    }

    // MARK: - Lifecycle

    internal func viewDidLoad() {
        TUIChatKitLayoutDirection.install()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        bindUnreadBadge()
        bindChatBackground()
        updateTopBannerLayout()
    }

    internal func viewDidLayoutSubviews() {
        messageInputView.bottomSafeAreaInset = view.safeAreaInsets.bottom
    }

    internal func viewWillAppear(_ animated: Bool) {
        messageListView.hostVisibilityDidChange(true)
    }

    internal func viewWillDisappear(_ animated: Bool) {
        messageListView.hostVisibilityDidChange(false)
        createdMessageInputView?.cancelVoiceRecording()
    }

    // MARK: - Actions

    private func constructViewHierarchy() {
        if showsNavigationBar {
            view.addSubview(navigationBar)
            navigationBar.addSubview(backButton)
            navigationBar.addSubview(unreadBadgeView)
            unreadBadgeView.addSubview(unreadBadgeLabel)
            navigationBar.addSubview(titleLabel)
            navigationBar.addSubview(moreButton)
            navigationBar.addSubview(cancelMultiSelectButton)
            view.addSubview(divider)
        }
        view.addSubview(messageListView)
        view.addSubview(messageInputView)
        view.addSubview(sendFailureBar)
        sendFailureBar.addSubview(sendFailureIconView)
        sendFailureBar.addSubview(sendFailureLabel)
    }

    private func activateConstraints() {
        guard showsNavigationBar else {
            activateConstraintsWithoutNavigationBar()
            activateInputAndFailureConstraints()
            return
        }
        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.navBarHeight)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.navHorizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.backButtonSize)
        }
        unreadBadgeView.snp.makeConstraints { make in

            make.leading.equalTo(backButton.snp.leading).offset(Self.backIconSlotWidth + Self.unreadBadgeLeadingGap)
            make.centerY.equalToSuperview()
            make.height.equalTo(Self.unreadBadgeSize)
            make.width.greaterThanOrEqualTo(Self.unreadBadgeSize)
        }
        unreadBadgeLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Self.unreadBadgeHorizontalPadding)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview().priority(Self.titleCenterXPriority)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing).offset(Self.navHorizontalInset)
            make.trailing.lessThanOrEqualTo(moreButton.snp.leading).offset(-Self.navHorizontalInset)
        }
        moreButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.navHorizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.moreButtonSize)
        }
        cancelMultiSelectButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.navHorizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalTo(Self.backButtonSize)
        }
        divider.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
        messageListView.snp.makeConstraints { make in
            make.top.equalTo(divider.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(messageInputView.snp.top)
        }

        activateInputAndFailureConstraints()
    }

    private func activateConstraintsWithoutNavigationBar() {
        messageListView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(messageInputView.snp.top)
        }
    }

    private func activateInputAndFailureConstraints() {
        messageInputView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        inputCollapseConstraint = messageInputView.heightAnchor.constraint(equalToConstant: 0)

        sendFailureBar.snp.makeConstraints { make in
            make.bottom.equalTo(messageInputView.snp.top).offset(-Self.failureBarBottomSpacing)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Self.failureBarSideInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.failureBarSideInset)
            make.height.greaterThanOrEqualTo(Self.failureBarMinHeight)
        }
        sendFailureIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.failureBarHorizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.failureBarIconSize)
        }
        sendFailureLabel.snp.makeConstraints { make in
            make.leading.equalTo(sendFailureIconView.snp.trailing).offset(Self.failureBarIconTextGap)
            make.trailing.equalToSuperview().offset(-Self.failureBarHorizontalPadding)
            make.top.equalToSuperview().offset(Self.failureBarVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.failureBarVerticalPadding)
            make.width.lessThanOrEqualTo(Self.failureBarMaxTextWidth)
        }
    }

    private func bindInteraction() {
        backButton.addTarget(self, action: #selector(handleBackTapped), for: .touchUpInside)
        cancelMultiSelectButton.addTarget(self, action: #selector(handleCancelMultiSelectTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(handleMoreTapped), for: .touchUpInside)
        bindTypingIndicator()
    }

    private func updateTopBannerLayout() {
        guard isViewLoaded else { return }
        if let banner = topBannerView {
            view.insertSubview(banner, belowSubview: sendFailureBar)
            banner.snp.makeConstraints { make in
                if showsNavigationBar {
                    make.top.equalTo(divider.snp.bottom)
                } else {
                    make.top.equalTo(view.safeAreaLayoutGuide)
                }
                make.leading.trailing.equalToSuperview()
            }
            messageListView.snp.remakeConstraints { make in
                make.top.equalTo(banner.snp.bottom)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(messageInputView.snp.top)
            }
        } else {
            messageListView.snp.remakeConstraints { make in
                if showsNavigationBar {
                    make.top.equalTo(divider.snp.bottom)
                } else {
                    make.top.equalTo(view.safeAreaLayoutGuide)
                }
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(messageInputView.snp.top)
            }
        }
    }

    private func bindTypingIndicator() {
        guard let typingPublisher = messageInputView.typingPublisher else { return }
        messageInputView.onTypingContentChanged = { [weak self] hasContent in
            self?.messageInputView.sendTypingStatus(hasContent: hasContent)
        }
        guard messageListConfig.enableTyping else { return }
        typingCancellable = typingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isTyping in
                guard let self = self else { return }
                if isTyping {
                    self.titleLabel.text = LocalizedChatString("Typing")
                } else {
                    self.titleLabel.text = self.conversation.title ?? self.conversation.conversationID
                }
            }
    }

    private func bindChatBackground() {
        applyChatBackground()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChatBackgroundChanged(_:)),
            name: ChatBackgroundStore.didChangeNotification,
            object: nil
        )
    }

    private func applyChatBackground() {
        let uri = ChatBackgroundStore.shared.imageURI(forConversationID: conversation.id)
        messageListView.applyChatBackgroundImage(uri: uri)
    }

    @objc private func handleChatBackgroundChanged(_ notification: Notification) {
        guard let changedID = notification.userInfo?[ChatBackgroundStore.conversationIDUserInfoKey] as? String,
              changedID == conversation.id else { return }
        applyChatBackground()
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorOperate

        sendFailureBar.backgroundColor = colors.bgColorOperate
        sendFailureBar.layer.cornerRadius = Self.failureBarCornerRadius
        sendFailureBar.layer.masksToBounds = true
        sendFailureBar.alpha = 0
        sendFailureBar.isHidden = true
        sendFailureBar.isUserInteractionEnabled = false

        sendFailureIconView.image = AtomicXChatResources.image(named: "message_toast_error")
        sendFailureIconView.contentMode = .scaleAspectFit

        sendFailureLabel.font = FontScheme.caption2Regular
        sendFailureLabel.textColor = colors.textColorPrimary
        sendFailureLabel.numberOfLines = Self.failureBarMaxLineCount
        sendFailureLabel.textAlignment = .natural

        if let backImage = AtomicXChatResources.image(named: "contact_info_back") {
            backButton.setImage(backImage.withRenderingMode(.alwaysTemplate), for: .normal)
        } else {
            backButton.setImage(
                UIImage(systemName: "chevron.left")?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.backIconFallbackPointSize, weight: .semibold)),
                for: .normal
            )
        }
        backButton.tintColor = colors.textColorPrimary
        backButton.contentHorizontalAlignment = .leading

        unreadBadgeView.backgroundColor = colors.buttonColorOff
        unreadBadgeView.layer.cornerRadius = Self.unreadBadgeSize / 2
        unreadBadgeView.clipsToBounds = true
        unreadBadgeView.isHidden = true
        unreadBadgeLabel.textColor = colors.textColorButton
        unreadBadgeLabel.font = FontScheme.caption3Regular
        unreadBadgeLabel.textAlignment = .center

        titleLabel.text = conversation.title ?? conversation.conversationID
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textAlignment = .center

        moreButton.setImage(
            UIImage(systemName: "ellipsis")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.moreIconPointSize, weight: .semibold)),
            for: .normal
        )
        moreButton.tintColor = colors.textColorSecondary
        moreButton.isHidden = !isShowMoreButton

        cancelMultiSelectButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelMultiSelectButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelMultiSelectButton.titleLabel?.font = FontScheme.caption1Regular
        cancelMultiSelectButton.contentHorizontalAlignment = .leading
        cancelMultiSelectButton.isHidden = true

        divider.backgroundColor = colors.strokeColorPrimary
        messageInputView.backgroundColor = colors.bgColorOperate
    }

    private func showSendFailure(_ reason: String) {
        guard !reason.isEmpty else { return }
        sendFailureHideWorkItem?.cancel()
        sendFailureLabel.text = reason
        sendFailureBar.isHidden = false
        UIView.animate(withDuration: Self.failureBarFadeDuration) {
            self.sendFailureBar.alpha = 1
        }

        let hideWorkItem = DispatchWorkItem { [weak self] in
            self?.hideSendFailure()
        }
        sendFailureHideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.failureBarDisplayDuration,
            execute: hideWorkItem
        )
    }

    private func hideSendFailure() {
        UIView.animate(
            withDuration: Self.failureBarFadeDuration,
            animations: { self.sendFailureBar.alpha = 0 },
            completion: { [weak self] _ in
                guard self?.sendFailureBar.alpha == 0 else { return }
                self?.sendFailureBar.isHidden = true
                self?.sendFailureLabel.text = nil
            }
        )
    }

    private func bindUnreadBadge() {
        unreadCancellable = conversationListStore.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] total in
                self?.updateUnreadBadge(total)
            }
    }

    private func updateUnreadBadge(_ total: Int64) {
        latestUnreadTotal = total
        let count = Int(total)
        if count > 0 {
            unreadBadgeLabel.text = count > Self.unreadBadgeMaxCount ? "99+" : "\(count)"
            unreadBadgeView.isHidden = isInMultiSelectMode
        } else {
            unreadBadgeView.isHidden = true
        }
    }

    private func updateInputVisibility(multiSelect: Bool) {
        isInMultiSelectMode = multiSelect
        if multiSelect {
            messageInputView.endEditing(true)
        }
        messageInputView.isHidden = multiSelect
        inputCollapseConstraint?.isActive = multiSelect
        backButton.isHidden = multiSelect
        moreButton.isHidden = multiSelect || !isShowMoreButton
        cancelMultiSelectButton.isHidden = !multiSelect
        updateUnreadBadge(latestUnreadTotal)
    }

    @objc private func handleBackTapped() {
        onBack?()
    }

    @objc private func handleCancelMultiSelectTapped() {
        messageListView.exitMultiSelectMode()
    }

    @objc private func handleMoreTapped() {
        onMoreClick?()
    }
}
