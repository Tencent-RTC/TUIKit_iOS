import UIKit
import Combine
import SnapKit
import Kingfisher
import AtomicXCore

final class MessageListViewImpl: RTCBaseView {
    var onMultiSelectModeChange: ((Bool) -> Void)?

    private static let loadMoreThreshold: CGFloat = 240

    private static let nearBottomThreshold: CGFloat = 80

    private static let forwardSeparateCountLimit = 30

    private static let estimatedRowHeight: CGFloat = 60

    private static let listenBarTrailingInset = CGFloat(SpacingScheme.smallSpacing)

    private static let listenBarCenterYRatio: CGFloat = 0.8

    private static let listenBarMinTopMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let listenBarBottomMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let listenBarMaxWidth: CGFloat = 320

    private static let tongueTrailingInset = CGFloat(SpacingScheme.bubbleSpacing)

    private static let tongueBottomInset = CGFloat(SpacingScheme.bubbleSpacing)

    private static let loadingIndicatorMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let loadingIndicatorSize: CGFloat = 24

    private static let toastShortDuration: TimeInterval = 2

    private static let toastLongDuration: TimeInterval = 3

    private static let highlightAnimationDelay: TimeInterval = 0.15

    private static let highlightArmTimeout: TimeInterval = 2.0

    private static let scrollOffsetTolerance: CGFloat = 1

    private static let glueOffsetTolerance: CGFloat = 0.5

    private static let reactionBarFadeDuration: TimeInterval = 0.2

    private static let mentionLocateMaxLoadCount = 20

    private static let latestFullyVisibleThreshold: CGFloat = 4

    private static let jumpScrollFallbackDelay: TimeInterval = 1.0

    private static let jumpRecenterTolerance = CGFloat(SpacingScheme.smallSpacing)

    private let onUserClick: ((String) -> Void)?

    private let viewModel: MessageListViewModel

    private var messages: [MessageInfo] = []

    private var cancellables = Set<AnyCancellable>()

    private var hasPerformedInitialScroll = false

    private var userHasInteracted = false

    private var isUserScrollSession = false

    private var deferredPrependMessages: [MessageInfo]?

    private var pendingInitialScroll = false

    private var scrollToLatestAfterReload = false

    private var lastTableBoundsHeight: CGFloat = 0

    private var isLoadingOlder = false {
        didSet { updateLoadingIndicators() }
    }

    private var isLoadingNewer = false {
        didSet { updateLoadingIndicators() }
    }

    private var pendingHighlightMsgID: String?

    private var pendingHighlightPlayed = false

    private var pendingInitialLocateMsgID: String?

    private var pendingScrollToQuoteInfo: MessageQuoteInfo?

    private var isJumpScrolling: Bool = false

    private let floatingEntryController = MessageListFloatingEntryStateController()

    private var pendingFloatingScrollToMsgID: String?

    private var pendingMentionSequence: Int64?

    private static let unreadClearDebounceInterval: TimeInterval = 0.3

    private var isHostVisible = false

    private var isAppActive = true

    private var isResumedAndShown = false

    private var hasPendingDebouncedUnreadClear = false

    private var debounceUnreadClearWorkItem: DispatchWorkItem?

    private var activeBackgroundImage: UIImage?

    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true
        return imageView
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.keyboardDismissMode = .onDrag
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = Self.estimatedRowHeight
        table.allowsSelection = true
        return table
    }()

    private lazy var tongueView: MessageTongueView = {
        let view = MessageTongueView()
        view.isHidden = true
        return view
    }()

    private lazy var topLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = TUIChatKitTheme.colors.textColorSecondary
        return indicator
    }()

    private lazy var bottomLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = TUIChatKitTheme.colors.textColorSecondary
        return indicator
    }()

    private lazy var multiSelectBar: MessageListMultiSelectBar = {
        let bar = MessageListMultiSelectBar()
        bar.isHidden = true
        return bar
    }()

    private lazy var listenPlaybackBar: ListenPlaybackBar = {
        let bar = ListenPlaybackBar()
        bar.isHidden = true
        return bar
    }()

    private let listenController = ListenFromHereController()

    // MARK: - Init

    init(conversationID: String,
                config: (MessageListConfigProtocol & MessageActionConfigProtocol) = ChatMessageListConfig(),
                locateMessage: MessageInfo? = nil,
                onUserClick: ((String) -> Void)? = nil) {
        self.onUserClick = onUserClick
        self.viewModel = MessageListViewModel(
            conversationID: conversationID,
            config: config,
            locateMessage: locateMessage
        )
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - RTCBaseView Lifecycle

    public override func constructViewHierarchy() {
        LanguageHelper.applyLayoutDirection(to: self)
        addSubview(backgroundImageView)
        addSubview(tableView)
        addSubview(topLoadingIndicator)
        addSubview(bottomLoadingIndicator)
        addSubview(tongueView)
        addSubview(multiSelectBar)
        addSubview(listenPlaybackBar)
    }

    public override func activateConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        listenPlaybackBar.snp.makeConstraints { make in

            make.trailing.equalToSuperview().offset(-Self.listenBarTrailingInset)
            make.centerY.equalToSuperview().multipliedBy(Self.listenBarCenterYRatio)
            make.top.greaterThanOrEqualTo(safeAreaLayoutGuide).offset(Self.listenBarMinTopMargin)
            make.bottom.lessThanOrEqualTo(multiSelectBar.snp.top).offset(-Self.listenBarBottomMargin)
            make.width.lessThanOrEqualTo(Self.listenBarMaxWidth)
        }
        tongueView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.tongueTrailingInset)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-Self.tongueBottomInset)
        }
        topLoadingIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide).offset(Self.loadingIndicatorMargin)
            make.width.height.equalTo(Self.loadingIndicatorSize)
        }
        bottomLoadingIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-Self.loadingIndicatorMargin)
            make.width.height.equalTo(Self.loadingIndicatorSize)
        }
        multiSelectBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()

            make.bottom.equalToSuperview()
        }
    }

    public override func bindInteraction() {
        hasPerformedInitialScroll = false
        pendingInitialScroll = false
        userHasInteracted = false
        isUserScrollSession = false
        deferredPrependMessages = nil
        listenController.stop()
        tableView.dataSource = self
        tableView.delegate = self
        tongueView.addTarget(self, action: #selector(handleTongueTap), for: .touchUpInside)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTableViewTap))
        tapGesture.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tapGesture)
        bindMultiSelectBar()
        registerCells()
        subscribeViewModel()
        subscribeInputInteract()
        requestInitialMentionEntry()
        if let locateMsgID = viewModel.locateMessage?.msgID, !locateMsgID.isEmpty {
            pendingInitialLocateMsgID = locateMsgID
        }
        viewModel.fetchInitialMessages()
    }

    public override func setupViewStyle() {
        applyBackgroundState()
    }

    // MARK: - Unread Clear (对齐 Android 清除未读数逻辑)

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshResumedAndShown()
    }

    func hostVisibilityDidChange(_ isVisible: Bool) {
        isHostVisible = isVisible
        refreshResumedAndShown()
    }

    private func refreshResumedAndShown() {
        let active = isHostVisible && isAppActive && window != nil
        guard active != isResumedAndShown else { return }
        isResumedAndShown = active
        if active {
            cancelDebouncedUnreadClear()
            viewModel.syncConversationAsRead()
        } else {
            flushDebouncedUnreadClear()
        }
    }

    private func scheduleDebouncedUnreadClear() {
        guard isResumedAndShown else { return }
        hasPendingDebouncedUnreadClear = true
        debounceUnreadClearWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hasPendingDebouncedUnreadClear = false
            if self.isResumedAndShown {
                self.viewModel.clearConversationUnreadCount()
            }
        }
        debounceUnreadClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.unreadClearDebounceInterval, execute: workItem)
    }

    private func flushDebouncedUnreadClear() {
        debounceUnreadClearWorkItem?.cancel()
        debounceUnreadClearWorkItem = nil
        guard hasPendingDebouncedUnreadClear else { return }
        hasPendingDebouncedUnreadClear = false
        viewModel.clearConversationUnreadCount()
    }

    private func cancelDebouncedUnreadClear() {
        debounceUnreadClearWorkItem?.cancel()
        debounceUnreadClearWorkItem = nil
        hasPendingDebouncedUnreadClear = false
    }

    // MARK: - Chat Background

    func applyChatBackgroundImage(uri: String?) {
        guard let uri, let url = URL(string: uri) else {
            activeBackgroundImage = nil
            showDefaultListBackground()
            return
        }
        backgroundImageView.kf.setImage(with: url) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let imageResult):
                self.activeBackgroundImage = imageResult.image
                self.applyBackgroundState()
            case .failure:
                self.activeBackgroundImage = nil
                self.showDefaultListBackground()
            }
        }
    }

    // MARK: - Multi-Select Bar (多选底部操作栏，对齐声明式 MultiSelectBottomBar)

    func exitMultiSelectMode() {
        viewModel.exitMultiSelectMode()
    }

    // MARK: - List Update & Scroll Management

    override func layoutSubviews() {
        super.layoutSubviews()
        configBackgroundGradientLayer?.frame = bounds
        glueContentToBottomForBoundsChange()
        performInitialScrollToBottomIfNeeded()
    }

    // MARK: - Forward (转发)

    private func showDefaultListBackground() {
        backgroundImageView.kf.cancelDownloadTask()
        backgroundImageView.isHidden = true
        backgroundImageView.image = nil
        applyOpaqueListBackground()
    }

    private func applyBackgroundState() {
        if let image = activeBackgroundImage {
            backgroundImageView.image = image
            backgroundImageView.isHidden = false
            backgroundColor = .clear
            tableView.backgroundColor = .clear
        } else {
            applyOpaqueListBackground()
        }
    }

    private func applyOpaqueListBackground() {
        if let configuredBackground = viewModel.config.background {
            applyConfiguredListBackground(configuredBackground)
            return
        }
        removeConfigBackgroundGradientLayer()
        let listColor = TUIChatKitTheme.colors.bgColorOperate
        backgroundColor = listColor
        tableView.backgroundColor = listColor
    }

    private var configBackgroundGradientLayer: CAGradientLayer?

    private func removeConfigBackgroundGradientLayer() {
        configBackgroundGradientLayer?.removeFromSuperlayer()
        configBackgroundGradientLayer = nil
    }

    private func applyConfiguredListBackground(_ configuredBackground: MessageListBackground) {
        removeConfigBackgroundGradientLayer()
        switch configuredBackground {
        case .color(let color):
            backgroundColor = color
            tableView.backgroundColor = color
        case .gradient(let colors, let startPoint, let endPoint):
            let gradient = CAGradientLayer()
            gradient.colors = colors.map { $0.cgColor }
            gradient.startPoint = startPoint
            gradient.endPoint = endPoint
            gradient.frame = bounds
            layer.insertSublayer(gradient, at: 0)
            configBackgroundGradientLayer = gradient
            backgroundColor = .clear
            tableView.backgroundColor = .clear
        case .image(let image):
            backgroundImageView.image = image
            backgroundImageView.isHidden = false
            backgroundColor = .clear
            tableView.backgroundColor = .clear
        }
    }

    private func updateLoadingIndicators() {
        if isLoadingOlder {
            topLoadingIndicator.startAnimating()
        } else {
            topLoadingIndicator.stopAnimating()
        }
        if isLoadingNewer {
            bottomLoadingIndicator.startAnimating()
        } else {
            bottomLoadingIndicator.stopAnimating()
        }
    }

    private func registerCells() {
        for identifier in MessageContentKind.allReuseIdentifiers {
            tableView.register(MessageBaseCell.self, forCellReuseIdentifier: identifier)
        }
        for identifier in MessageCellRegistry.shared.customReuseIdentifiers {
            tableView.register(MessageBaseCell.self, forCellReuseIdentifier: identifier)
        }
        tableView.register(MessageCenteredTextCell.self, forCellReuseIdentifier: MessageCellRegistry.systemTipReuseIdentifier)
        tableView.register(MessageCenteredTextCell.self, forCellReuseIdentifier: MessageCellRegistry.revokedReuseIdentifier)
    }

    private func subscribeViewModel() {
        viewModel.$messageList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in self?.applyMessageList(list) }
            .store(in: &cancellables)

        viewModel.$isMultiSelectMode
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] isMultiSelect in self?.applyMultiSelectMode(isMultiSelect) }
            .store(in: &cancellables)

        viewModel.$selectedMessageIDs
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] ids in
                self?.updateVisibleCellsMultiSelectState()
                self?.multiSelectBar.configure(selectedCount: ids.count)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("enterMultiSelectMode"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let initialMessage = notification.userInfo?["initialMessage"] as? MessageInfo
                self?.viewModel.enterMultiSelectMode(initialMessageID: initialMessage?.msgID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("showForwardTargetSelector"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleShowForwardTargetSelector(from: notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("listenFromHereNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleListenFromHere(from: notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: MessageInputView.voiceRecordStartNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.listenController.stop()
            }
            .store(in: &cancellables)

        listenPlaybackBar.onClose = { [weak self] in
            self?.listenController.stop()
        }
        listenController.onStateChange = { [weak self] state in
            guard let self else { return }
            if state.isActive {
                self.listenPlaybackBar.render(loading: state.isLoading, text: state.currentText)
                self.listenPlaybackBar.isHidden = false
            } else {
                self.listenPlaybackBar.collapse()
                self.listenPlaybackBar.isHidden = true
            }
        }

        NotificationCenter.default.publisher(for: NSNotification.Name("deleteMessageNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let message = notification.userInfo?["message"] as? MessageInfo else { return }
                self?.handleSingleMessageDelete(message)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("convertVoiceToText"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let message = notification.userInfo?["message"] as? MessageInfo else { return }
                self?.viewModel.convertVoiceToText(message)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("translateTextMessage"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let message = notification.userInfo?["message"] as? MessageInfo else { return }
                self?.viewModel.translateTextMessage(message)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("messageReactionToggle"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let message = notification.userInfo?["message"] as? MessageInfo,
                      let reactionID = notification.userInfo?["reactionID"] as? String else { return }
                self?.viewModel.toggleReaction(message: message, reactionID: reactionID)
            }
            .store(in: &cancellables)

        viewModel.$processingAuxiliaryTextIDs
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] _ in self?.updateVisibleCellsAuxiliaryTextState() }
            .store(in: &cancellables)

        viewModel.$hiddenAuxiliaryTextIDs
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] _ in self?.updateVisibleCellsAuxiliaryTextState() }
            .store(in: &cancellables)

        viewModel.messageEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                if case .onReceiveNewMessage(let message) = event {
                    self.scheduleDebouncedUnreadClear()
                    self.floatingEntryController.onNewMessage(
                        message,
                        isLatestCompletelyVisible: self.isLatestMessageCompletelyVisible()
                    )
                    self.refreshTongue()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isAppActive = false
                self.refreshResumedAndShown()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isAppActive = true
                self.refreshResumedAndShown()
            }
            .store(in: &cancellables)
    }

    private func subscribeInputInteract() {
        NotificationCenter.default.publisher(for: MessageInputView.inputInteractNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.hasPerformedInitialScroll else { return }
                self.handleBackToLatest()
                DispatchQueue.main.async {
                    self.updateFloatingEntryForScroll()
                }
            }
            .store(in: &cancellables)
    }

    private func requestInitialMentionEntry() {
        guard viewModel.isGroupChat else { return }
        viewModel.fetchGroupAtInfoList { [weak self] atInfoList in
            guard let self = self else { return }
            let target = MessageListFloatingEntryPolicy.findOldestMentionTarget(atInfoList)
            self.floatingEntryController.onInitialMentionTarget(
                target,
                visibility: target.map { self.mentionTargetVisibility($0) } ?? .unknown
            )
            self.refreshTongue()
            if target != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.updateFloatingEntryForScroll()
                }
            }
        }
    }

    private func bindMultiSelectBar() {
        multiSelectBar.onDelete = { [weak self] in self?.handleMultiSelectDelete() }
        multiSelectBar.onForwardSeparate = { [weak self] in self?.handleMultiSelectForward(type: .separate) }
        multiSelectBar.onForwardMerge = { [weak self] in self?.handleMultiSelectForward(type: .merged) }
    }

    private func applyMultiSelectMode(_ isMultiSelect: Bool) {
        UIView.performWithoutAnimation {
            multiSelectBar.isHidden = !isMultiSelect
            if isMultiSelect {
                multiSelectBar.configure(selectedCount: viewModel.selectedMessageIDs.count)
            }
            updateVisibleCellsMultiSelectState()
            onMultiSelectModeChange?(isMultiSelect)
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateLayoutForMultiSelectMode(isMultiSelect)
        }
    }

    private func updateLayoutForMultiSelectMode(_ isMultiSelect: Bool) {
        UIView.performWithoutAnimation {
            tableView.contentInset.bottom = isMultiSelect ? multiSelectBar.frame.height : 0
            if isMultiSelect {
                revealMultiSelectAnchorAboveBar()
            }
        }
    }

    private func revealMultiSelectAnchorAboveBar() {
        guard let anchorID = viewModel.multiSelectAnchorMessageID,
              let index = messages.firstIndex(where: { $0.msgID == anchorID }) else { return }
        let rowRect = tableView.rectForRow(at: IndexPath(row: index, section: 0))
        let visibleBottomY = tableView.contentOffset.y + tableView.bounds.height - tableView.contentInset.bottom
        guard rowRect.maxY > visibleBottomY else { return }
        let targetOffsetY = rowRect.maxY - tableView.bounds.height + tableView.contentInset.bottom
        let minOffsetY = -tableView.contentInset.top
        let maxOffsetY = max(minOffsetY, tableView.contentSize.height + tableView.contentInset.bottom - tableView.bounds.height)
        let clampedOffsetY = min(max(targetOffsetY, minOffsetY), maxOffsetY)
        guard clampedOffsetY > tableView.contentOffset.y else { return }
        tableView.setContentOffset(CGPoint(x: 0, y: clampedOffsetY), animated: false)
    }

    private func handleSingleMessageDelete(_ message: MessageInfo) {
        let alert = UIAlertController(
            title: LocalizedChatString("ConfirmDeleteMessage"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedChatString("Confirm"), style: .destructive) { [weak self] _ in
            self?.viewModel.deleteMessages([message])
        })
        findViewController()?.present(alert, animated: true)
    }

    private func handleMultiSelectDelete() {
        let selected = viewModel.getSelectedMessages()
        guard !selected.isEmpty else { return }
        let alert = UIAlertController(
            title: LocalizedChatString("ConfirmDeleteMessage"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedChatString("Confirm"), style: .destructive) { [weak self] _ in
            self?.viewModel.deleteMessages(selected) {
                self?.viewModel.exitMultiSelectMode()
            }
        })
        findViewController()?.present(alert, animated: true)
    }

    private func handleMultiSelectForward(type: MessageForwardType) {
        let selected = viewModel.getSelectedMessages()
        guard !selected.isEmpty else { return }
        if selected.contains(where: { $0.status != .sendSuccess }) {
            WindowToastManager.shared.show(
                LocalizedChatString("RelayUnsupportForward"),
                type: .error,
                duration: Self.toastShortDuration
            )
            return
        }
        if type == .separate && selected.count > Self.forwardSeparateCountLimit {
            WindowToastManager.shared.show(
                LocalizedChatString("RelayOneByOnyOverLimit"),
                type: .error,
                duration: Self.toastShortDuration
            )
            return
        }
        let selector = ForwardTargetSelectorViewController { [weak self] conversationIDs in
            self?.performForward(messages: selected, conversationIDs: conversationIDs, type: type)
        }
        findViewController()?.navigationController?.pushViewController(selector, animated: true)
    }

    private func applyMessageList(_ list: [MessageInfo]) {

        let exclusionMatchers = viewModel.config.messageExclusionMatchers
        let list = list.filter { message in
            if exclusionMatchers.contains(where: { $0(message) }) { return false }
            guard message.messageType == .custom,
                  let callModel = CallMessageParser.parse(message) else { return true }
            return !callModel.isExcludeFromHistory
        }
        let oldMessages = messages

        if let progressMsgIDs = mediaProgressOnlyChangedMsgIDs(old: oldMessages, new: list) {
            messages = list
            updateVisibleCellsMediaProgress(msgIDs: progressMsgIDs)
            return
        }

        if let reactionMsgIDs = reactionOnlyChangedMsgIDs(old: oldMessages, new: list) {
            messages = list
            updateVisibleCellsReaction(msgIDs: reactionMsgIDs)
            return
        }
        let anchor = topAnchor(using: oldMessages)
        let prepended = isPrepend(old: oldMessages, new: list)
        let wasLatestCompletelyVisible = isLatestMessageCompletelyVisible()
        let oldLatestMsgID = oldMessages.last?.msgID ?? ""
        let newLatestMsgID = list.last?.msgID ?? ""
        let latestMessageChanged = !oldLatestMsgID.isEmpty && !newLatestMsgID.isEmpty && oldLatestMsgID != newLatestMsgID

        let hasPendingJump = pendingScrollToQuoteInfo != nil || pendingFloatingScrollToMsgID != nil || pendingMentionSequence != nil

        if prepended, isUserScrollSession, !hasPendingJump, !scrollToLatestAfterReload {
            deferredPrependMessages = list
            return
        }
        deferredPrependMessages = nil

        messages = list
        tableView.reloadData()
        tableView.layoutIfNeeded()

        if scrollToLatestAfterReload {
            scrollToLatestAfterReload = false
            scrollToBottom(animated: false)
        } else if hasPendingJump {

        } else if !userHasInteracted {

            if let locateMsgID = pendingInitialLocateMsgID,
               let locateIndex = messages.firstIndex(where: { $0.msgID == locateMsgID }),
               tableView.bounds.height > 0 {
                pendingInitialLocateMsgID = nil
                hasPerformedInitialScroll = true
                userHasInteracted = true
                let indexPath = IndexPath(row: locateIndex, section: 0)
                tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                armPendingHighlight(locateMsgID)
                performHighlightReload(msgID: locateMsgID, at: indexPath, delay: Self.highlightAnimationDelay)
            } else if !messages.isEmpty {
                if tableView.bounds.height > 0 {
                    scrollToBottom(animated: false)
                    hasPerformedInitialScroll = true
                } else {
                    pendingInitialScroll = true
                    setNeedsLayout()
                    DispatchQueue.main.async { [weak self] in
                        self?.performInitialScrollToBottomIfNeeded()
                    }
                }
            }
        } else if prepended, let anchor = anchor {
            restore(anchor: anchor)
        } else if latestMessageChanged, !isUserScrollSession, !isLoadingNewer {
            let isOwnLatestMessage = list.last?.isSentBySelf == true
            if isOwnLatestMessage || wasLatestCompletelyVisible {
                scrollToBottom(animated: true)
            }
        }
        isLoadingOlder = false
        isLoadingNewer = false

        performPendingQuoteScrollIfNeeded()
        performPendingFloatingScrollIfNeeded()
        performPendingMentionScrollIfNeeded()
        updateFloatingEntryForScroll()
        DispatchQueue.main.async { [weak self] in
            self?.syncVisibleMessageReadReceipts()
        }
    }

    private func syncVisibleMessageReadReceipts() {
        guard let indexPaths = tableView.indexPathsForVisibleRows, !indexPaths.isEmpty else { return }
        let visibleMessages = indexPaths.compactMap { indexPath -> MessageInfo? in
            guard indexPath.row < messages.count else { return nil }
            return messages[indexPath.row]
        }
        viewModel.sendReadReceipts(for: visibleMessages)
    }

    private func performPendingMentionScrollIfNeeded() {
        guard let sequence = pendingMentionSequence,
              let index = messages.firstIndex(where: { $0.sequence == sequence }) else { return }
        pendingMentionSequence = nil
        let msgID = messages[index].msgID
        DispatchQueue.main.async { [weak self] in
            self?.scrollAndHighlight(msgID: msgID, at: index)
        }
    }

    private func performPendingQuoteScrollIfNeeded() {
        guard let quoteInfo = pendingScrollToQuoteInfo else {
            return
        }
        guard let index = indexOfLoadedQuoteTarget(quoteInfo) else {
            return
        }
        pendingScrollToQuoteInfo = nil
        let msgID = messages[index].msgID
        DispatchQueue.main.async { [weak self] in
            self?.scrollAndHighlight(msgID: msgID, at: index)
        }
    }

    private func performPendingFloatingScrollIfNeeded() {
        guard let msgID = pendingFloatingScrollToMsgID,
              let index = messages.firstIndex(where: { $0.msgID == msgID }) else { return }
        pendingFloatingScrollToMsgID = nil
        DispatchQueue.main.async { [weak self] in
            self?.scrollAndHighlight(msgID: msgID, at: index)
        }
    }

    private func isPrepend(old: [MessageInfo], new: [MessageInfo]) -> Bool {
        guard !old.isEmpty, new.count > old.count else { return false }
        return old.first?.msgID != new.first?.msgID
    }

    private func topAnchor(using currentMessages: [MessageInfo]) -> (msgID: String, delta: CGFloat)? {
        guard let indexPath = tableView.indexPathsForVisibleRows?.first,
              indexPath.row < currentMessages.count else { return nil }
        let msgID = currentMessages[indexPath.row].msgID
        guard !msgID.isEmpty else { return nil }
        let rect = tableView.rectForRow(at: indexPath)
        return (msgID, rect.minY - tableView.contentOffset.y)
    }

    private func restore(anchor: (msgID: String, delta: CGFloat)) {
        guard let index = messages.firstIndex(where: { $0.msgID == anchor.msgID }) else { return }
        let rect = tableView.rectForRow(at: IndexPath(row: index, section: 0))
        var offset = tableView.contentOffset
        offset.y = max(rect.minY - anchor.delta, 0)
        tableView.setContentOffset(offset, animated: false)
    }

    private func isNearBottom() -> Bool {
        let distanceFromBottom = tableView.contentSize.height - (tableView.contentOffset.y + tableView.bounds.height)
        return distanceFromBottom <= Self.nearBottomThreshold
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let lastIndex = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: lastIndex, at: .bottom, animated: false)
    }

    private func glueContentToBottomForBoundsChange() {
        let newHeight = tableView.bounds.height
        let oldHeight = lastTableBoundsHeight
        lastTableBoundsHeight = newHeight
        guard oldHeight > 0, newHeight > 0, newHeight != oldHeight, !messages.isEmpty else { return }
        let wasAtBottom = tableView.contentOffset.y + oldHeight >= tableView.contentSize.height - Self.nearBottomThreshold
        guard wasAtBottom else { return }
        let delta = newHeight - oldHeight
        let minOffset = -tableView.adjustedContentInset.top
        let maxOffset = max(minOffset, tableView.contentSize.height - newHeight + tableView.adjustedContentInset.bottom)
        let glued = min(max(tableView.contentOffset.y - delta, minOffset), maxOffset)
        if abs(glued - tableView.contentOffset.y) > Self.glueOffsetTolerance {
            tableView.setContentOffset(CGPoint(x: 0, y: glued), animated: false)
        }
    }

    private func performInitialScrollToBottomIfNeeded() {
        guard pendingInitialScroll, !hasPerformedInitialScroll,
              !messages.isEmpty, tableView.bounds.height > 0 else { return }
        scrollToBottom(animated: false)
        hasPerformedInitialScroll = true
        pendingInitialScroll = false
        updateFloatingEntryForScroll()
    }

    private func updateVisibleCellsMultiSelectState() {
        for case let cell as MessageBaseCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell),
                  indexPath.row < messages.count else { continue }
            let message = messages[indexPath.row]
            cell.updateMultiSelectState(
                isMultiSelectMode: viewModel.isMultiSelectMode,
                isSelected: viewModel.isSelected(message)
            )
        }
    }

    private func updateVisibleCellsAuxiliaryTextState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                for case let cell as MessageBaseCell in self.tableView.visibleCells {
                    guard let indexPath = self.tableView.indexPath(for: cell),
                          indexPath.row < self.messages.count else { continue }
                    let message = self.messages[indexPath.row]
                    let state = self.viewModel.auxiliaryTextState(for: message)
                    cell.updateAuxiliaryTextState(state: state)
                }
                self.tableView.endUpdates()
                self.tableView.layoutIfNeeded()
            }
        }
    }

    private func mediaProgressOnlyChangedMsgIDs(old: [MessageInfo], new: [MessageInfo]) -> Set<String>? {
        guard !new.isEmpty, old.count == new.count else { return nil }
        var changed: Set<String> = []
        for (o, n) in zip(old, new) {
            guard o.msgID == n.msgID, o.status == n.status else { return nil }
            if o.uploadMediaProgress != n.uploadMediaProgress || o.downloadMediaProgress != n.downloadMediaProgress {
                changed.insert(n.msgID)
            }
        }
        return changed.isEmpty ? nil : changed
    }

    private func updateVisibleCellsMediaProgress(msgIDs: Set<String>) {
        for case let cell as MessageBaseCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell),
                  indexPath.row < messages.count else { continue }
            let message = messages[indexPath.row]
            guard msgIDs.contains(message.msgID) else { continue }
            cell.updateMediaProgressIfNeeded(message)
        }
    }

    private func reactionOnlyChangedMsgIDs(old: [MessageInfo], new: [MessageInfo]) -> Set<String>? {
        guard !new.isEmpty, old.count == new.count else { return nil }
        var changed: Set<String> = []
        for (o, n) in zip(old, new) {
            guard o.msgID == n.msgID else { return nil }
            if !reactionListsEqual(o.reactionList, n.reactionList) {
                changed.insert(n.msgID)
            }
        }
        return changed.isEmpty ? nil : changed
    }

    private func reactionListsEqual(_ a: [MessageReaction], _ b: [MessageReaction]) -> Bool {
        guard a.count == b.count else { return false }
        for (ra, rb) in zip(a, b) {
            if ra.reactionID != rb.reactionID
                || ra.totalUserCount != rb.totalUserCount
                || ra.reactedByMyself != rb.reactedByMyself {
                return false
            }
        }
        return true
    }

    private func updateVisibleCellsReaction(msgIDs: Set<String>) {
        guard !msgIDs.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let wasNearBottom = self.isNearBottom()

            var newlyShownReactionBars: [MessageReactionBarView] = []
            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                for case let cell as MessageBaseCell in self.tableView.visibleCells {
                    guard let indexPath = self.tableView.indexPath(for: cell),
                          indexPath.row < self.messages.count else { continue }
                    let message = self.messages[indexPath.row]
                    guard msgIDs.contains(message.msgID) else { continue }
                    let wasHidden = cell.reactionBar.isHidden
                    cell.updateReaction(message: message)
                    if wasHidden, !cell.reactionBar.isHidden {
                        cell.reactionBar.alpha = 0
                        newlyShownReactionBars.append(cell.reactionBar)
                    }
                }
                self.tableView.endUpdates()
                self.tableView.layoutIfNeeded()
            }
            if wasNearBottom, !self.isUserScrollSession {
                self.scrollToBottom(animated: false)
            }
            guard !newlyShownReactionBars.isEmpty else { return }
            UIView.animate(withDuration: Self.reactionBarFadeDuration) {
                for bar in newlyShownReactionBars {
                    bar.alpha = 1
                }
            }
        }
    }

    private func isLeft(for message: MessageInfo) -> Bool {
        switch viewModel.config.alignment {
        case .left: return true
        case .right: return false
        case .twoSided: return !message.isSentBySelf
        }
    }

    private func makeContext(for message: MessageInfo) -> MessageContentContext {
        return MessageContentContext(
            config: viewModel.config,
            isLeft: isLeft(for: message),
            isSelf: message.isSentBySelf,
            isGroupChat: viewModel.isGroupChat,
            isMultiSelectMode: viewModel.isMultiSelectMode,
            messageListStore: viewModel.messageListStore,
            onMediaTap: { [weak self] tapped in self?.presentImageViewer(for: tapped) },
            onMergedMessageTap: { [weak self] tapped in
                guard tapped.status != .violation else { return }
                self?.openMergedDetail(tapped)
            }
        )
    }

    private func openMergedDetail(_ message: MessageInfo) {
        let detail = MergedMessageDetailViewController(mergedMessage: message, conversationID: viewModel.conversationID)
        findViewController()?.navigationController?.pushViewController(detail, animated: true)
    }

    private func presentImageViewer(for message: MessageInfo) {
        let provider = ImageViewerDataProvider(conversationID: viewModel.conversationID, currentMessage: message)
        provider.loadInitial { [weak self] elements, index in
            guard let self = self, !elements.isEmpty else { return }
            let viewer = ImageViewerController(elements: elements, initialIndex: index, provider: provider)
            self.findViewController()?.present(viewer, animated: true)
        }
    }

    private func presentReactionDetail(for message: MessageInfo) {
        guard !message.reactionList.isEmpty else { return }
        let detail = ReactionDetailViewController(
            message: message,
            currentUserID: viewModel.currentUserID
        )
        findViewController()?.present(detail, animated: true)
    }

    private func presentReadReceiptDetail(message: MessageInfo) {
        let detail = MessageReadReceiptViewController(
            message: message,
            actionStore: MessageActionStore.create(message: message),
            onUserClick: { [weak self] userID in self?.onUserClick?(userID) }
        )
        findViewController()?.navigationController?.pushViewController(detail, animated: true)
    }

    private func handleBubbleLongPress(_ message: MessageInfo, bubbleFrameInWindow: CGRect) {
        NSLog("[LongPressDebug] list handler, isMultiSelectMode=\(viewModel.isMultiSelectMode)")
        guard !viewModel.isMultiSelectMode else { return }

        let latestMessage = messages.first(where: { $0.msgID == message.msgID }) ?? message
        MessageActionMenuController.shared.show(
            for: latestMessage,
            bubbleFrameInWindow: bubbleFrameInWindow,
            config: viewModel.config,
            auxiliaryHiddenIDs: viewModel.hiddenAuxiliaryTextIDs
        )
    }

    private func handleQuotePreviewTap(_ hostMessage: MessageInfo) {
        guard let quoteInfo = hostMessage.quoteInfo else { return }
        if viewModel.isQuotedOriginalUnreachable(quoteInfo) {
            showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
            return
        }
        if let index = indexOfLoadedQuoteTarget(quoteInfo) {
            let msgID = messages[index].msgID
            if isRowFullyVisible(index) {
                highlightOnly(msgID: msgID, at: index)
                return
            }
            floatingEntryController.onQuoteNavigated(returnMessage: hostMessage)
            refreshTongue()
            scrollAndHighlight(msgID: msgID, at: index)
            return
        }
        if let rawMessage = rawQuoteTargetMessage(quoteInfo), isMessageExcludedFromDisplay(rawMessage) {
            showQuoteToast(LocalizedChatString("QuoteOriginalFiltered"))
            return
        }
        let hasUsableAnchor = viewModel.isGroupChat ? quoteInfo.sequence > 0 : quoteInfo.timestamp > 0
        guard hasUsableAnchor else { return }
        pendingScrollToQuoteInfo = quoteInfo
        viewModel.loadMessagesAroundMessage(quoteCursorMessage(quoteInfo)) { [weak self] in
            self?.handleQuoteAroundLoadCompleted(quoteInfo, hostMessage: hostMessage)
        }
    }

    private func indexOfLoadedQuoteTarget(_ quoteInfo: MessageQuoteInfo) -> Int? {
        if !quoteInfo.msgID.isEmpty,
           let index = messages.firstIndex(where: { $0.msgID == quoteInfo.msgID }) {
            return index
        }
        guard quoteInfo.sequence > 0 else { return nil }
        return messages.firstIndex(where: { $0.sequence == quoteInfo.sequence })
    }

    private func rawQuoteTargetMessage(_ quoteInfo: MessageQuoteInfo) -> MessageInfo? {
        if !quoteInfo.msgID.isEmpty,
           let message = viewModel.messageList.first(where: { $0.msgID == quoteInfo.msgID }) {
            return message
        }
        guard quoteInfo.sequence > 0 else { return nil }
        return viewModel.messageList.first(where: { $0.sequence == quoteInfo.sequence })
    }

    private func quoteCursorMessage(_ quoteInfo: MessageQuoteInfo) -> MessageInfo {
        var cursor = MessageInfo()
        cursor.msgID = quoteInfo.msgID
        if viewModel.isGroupChat {
            cursor.sequence = quoteInfo.sequence
            cursor.timestamp = quoteInfo.timestamp
        } else {
            cursor.timestamp = quoteInfo.timestamp
        }
        return cursor
    }

    private func handleQuoteAroundLoadCompleted(_ quoteInfo: MessageQuoteInfo, hostMessage: MessageInfo) {
        guard let rawMessage = rawQuoteTargetMessage(quoteInfo) else {
            pendingScrollToQuoteInfo = nil
            showQuoteToast(LocalizedChatString("ReplyMessageNotFoundOriginMessage"))
            return
        }
        if isMessageExcludedFromDisplay(rawMessage) {
            pendingScrollToQuoteInfo = nil
            showQuoteToast(LocalizedChatString("QuoteOriginalFiltered"))
            return
        }
        floatingEntryController.onQuoteNavigated(returnMessage: hostMessage)
        refreshTongue()
        performPendingQuoteScrollIfNeeded()
    }

    private func showQuoteToast(_ text: String) {
        WindowToastManager.shared.show(text, type: .info, duration: Self.toastLongDuration)
    }

    private func isMessageExcludedFromDisplay(_ message: MessageInfo) -> Bool {
        if viewModel.config.messageExclusionMatchers.contains(where: { $0(message) }) { return true }
        guard message.messageType == .custom,
              let callModel = CallMessageParser.parse(message) else { return false }
        return callModel.isExcludeFromHistory
    }

    private func updateFloatingEntryForScroll() {
        floatingEntryController.onMentionTargetVisibilityChanged(currentMentionTargetVisibility())
        floatingEntryController.onScroll(
            distanceFromLatest: distanceFromLatestMessage(),
            viewportHeight: tableView.bounds.height,
            isLatestCompletelyVisible: isLatestMessageCompletelyVisible(),
            isReturnMessageCompletelyVisible: isBackToQuoteReturnMessageCompletelyVisible()
        )
        refreshTongue()
    }

    private func refreshTongue() {
        guard let entry = floatingEntryController.currentEntry() else {
            tongueView.isHidden = true
            return
        }
        tongueView.configure(entry: entry)
        tongueView.isHidden = false
    }

    private func distanceFromLatestMessage() -> CGFloat {
        if isLatestMessageCompletelyVisible() { return 0 }
        return max(tableView.contentSize.height - (tableView.contentOffset.y + tableView.bounds.height), 0)
    }

    private func isLatestMessageCompletelyVisible() -> Bool {
        guard !messages.isEmpty else { return true }
        let distanceFromBottom = tableView.contentSize.height - (tableView.contentOffset.y + tableView.bounds.height)
        return distanceFromBottom <= Self.latestFullyVisibleThreshold
    }

    private func currentMentionTargetVisibility() -> MessageListMentionTargetVisibility {
        guard let target = floatingEntryController.currentMentionTarget() else { return .unknown }
        return mentionTargetVisibility(target)
    }

    private func mentionTargetVisibility(_ target: MessageListMentionTarget) -> MessageListMentionTargetVisibility {
        guard let index = messages.firstIndex(where: { $0.sequence == target.sequence }) else {
            return messages.isEmpty ? .unknown : .hidden
        }
        return isRowVisible(index) ? .visible : .hidden
    }

    private func isRowVisible(_ index: Int) -> Bool {
        let indexPath = IndexPath(row: index, section: 0)
        return tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
    }

    private func isBackToQuoteReturnMessageCompletelyVisible() -> Bool {
        guard let msgID = floatingEntryController.currentBackToQuoteReturnMessage()?.msgID, !msgID.isEmpty,
              let index = messages.firstIndex(where: { $0.msgID == msgID }) else {
            return false
        }
        return isRowFullyVisible(index)
    }

    private func isRowFullyVisible(_ index: Int) -> Bool {
        let indexPath = IndexPath(row: index, section: 0)
        guard let visible = tableView.indexPathsForVisibleRows, visible.contains(indexPath) else { return false }
        let rect = tableView.rectForRow(at: indexPath)
        let viewport = CGRect(x: 0, y: tableView.contentOffset.y,
                              width: tableView.bounds.width, height: tableView.bounds.height)
        return viewport.contains(rect)
    }

    @objc private func handleTableViewTap() {
        window?.endEditing(true)

        NotificationCenter.default.post(name: MessageListView.blankAreaClickNotification, object: nil)

        listenPlaybackBar.collapse()
    }

    @objc private func handleTongueTap() {
        guard let entry = floatingEntryController.currentEntry() else { return }
        floatingEntryController.consume(entry)
        refreshTongue()
        switch entry {
        case .backToLatest:
            handleBackToLatest()
        case .newMessages(_, let firstMessage):
            handleNewMessages(firstMessage: firstMessage)
        case .mention(let target):
            handleMention(target)
        case .backToQuote(let returnMessage):
            handleBackToQuote(returnMessage)
        }
    }

    private func handleBackToLatest() {
        if viewModel.hasMoreNewerMessage {
            scrollToLatestAfterReload = true
            viewModel.reloadLatestMessages { [weak self] success in
                if !success {
                    self?.scrollToLatestAfterReload = false
                }
            }
        } else {
            scrollToBottom(animated: true)
        }
    }

    private func handleNewMessages(firstMessage: MessageInfo) {
        let msgID = firstMessage.msgID
        guard !msgID.isEmpty else { return }
        if let index = messages.firstIndex(where: { $0.msgID == msgID }) {
            scrollAndHighlight(msgID: msgID, at: index)
        } else {
            pendingFloatingScrollToMsgID = msgID
            viewModel.loadMessagesAroundMessage(firstMessage)
        }
    }

    private func handleMention(_ target: MessageListMentionTarget) {
        if let index = messages.firstIndex(where: { $0.sequence == target.sequence }) {
            scrollAndHighlight(msgID: messages[index].msgID, at: index)
            updateFloatingEntryForScroll()
            return
        }
        pendingMentionSequence = target.sequence
        viewModel.loadOlderMessagesUntilSequence(target.sequence, maxLoadCount: Self.mentionLocateMaxLoadCount) { [weak self] in
            guard let self = self else { return }
            if let sequence = self.pendingMentionSequence,
               !self.messages.contains(where: { $0.sequence == sequence }) {
                self.pendingMentionSequence = nil
            }
            self.updateFloatingEntryForScroll()
        }
    }

    private func handleBackToQuote(_ returnMessage: MessageInfo) {
        let msgID = returnMessage.msgID
        guard !msgID.isEmpty else { return }
        if let index = messages.firstIndex(where: { $0.msgID == msgID }) {
            scrollAndHighlight(msgID: msgID, at: index)
            updateFloatingEntryForScroll()
        } else {
            pendingFloatingScrollToMsgID = msgID
            viewModel.loadMessagesAroundMessage(returnMessage)
        }
    }

    private func armPendingHighlight(_ msgID: String) {
        pendingHighlightMsgID = msgID
        pendingHighlightPlayed = false
    }

    private func performHighlightReload(msgID: String, at indexPath: IndexPath, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.pendingHighlightMsgID == msgID else { return }
            self.tryPlayPendingHighlight(msgID: msgID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + Self.highlightArmTimeout) { [weak self] in
            guard let self = self, self.pendingHighlightMsgID == msgID else { return }
            self.pendingHighlightMsgID = nil
            self.pendingHighlightPlayed = false
        }
    }

    private func tryPlayPendingHighlight(msgID: String) {
        guard pendingHighlightMsgID == msgID, !pendingHighlightPlayed,
              let index = messages.firstIndex(where: { $0.msgID == msgID }),
              let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MessageBaseCell else { return }
        pendingHighlightPlayed = true
        cell.playHighlightAnimation()
    }

    private func highlightOnly(msgID: String, at index: Int) {
        guard index >= 0, index < messages.count else { return }
        armPendingHighlight(msgID)
        let indexPath = IndexPath(row: index, section: 0)
        performHighlightReload(msgID: msgID, at: indexPath, delay: Self.highlightAnimationDelay)
    }

    private func scrollAndHighlight(msgID: String, at index: Int) {
        guard index >= 0, index < messages.count else {
            return
        }
        userHasInteracted = true
        hasPerformedInitialScroll = true
        pendingInitialScroll = false
        armPendingHighlight(msgID)
        isJumpScrolling = true
        let indexPath = IndexPath(row: index, section: 0)
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.recenterJumpTargetIfNeeded(msgID: msgID, indexPath: indexPath)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.jumpScrollFallbackDelay) { [weak self] in
            guard let self = self, self.isJumpScrolling else { return }
            self.finishJumpScrollIfNeeded(msgID: msgID)
        }
    }

    private func recenterJumpTargetIfNeeded(msgID: String, indexPath: IndexPath) {
        guard isJumpScrolling, pendingHighlightMsgID == msgID else { return }
        defer { finishJumpScrollIfNeeded(msgID: msgID) }
        guard tableView.cellForRow(at: indexPath) != nil else { return }
        let frame = tableView.rectForRow(at: indexPath)
        let inset = tableView.adjustedContentInset
        let viewportHeight = tableView.bounds.height - inset.top - inset.bottom
        guard viewportHeight > 0, frame.height > 0, frame.height < viewportHeight else { return }
        let targetY = frame.midY - inset.top - viewportHeight / 2
        let minY = -inset.top
        let maxY = max(minY, tableView.contentSize.height - viewportHeight + inset.bottom)
        let clampedY = min(max(targetY, minY), maxY)
        let tolerance = max(frame.height / 2, Self.jumpRecenterTolerance)
        guard abs(tableView.contentOffset.y - clampedY) > tolerance else { return }
        tableView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
    }

    private func finishJumpScrollIfNeeded(msgID: String) {
        isJumpScrolling = false
        guard let index = messages.firstIndex(where: { $0.msgID == msgID }), index < messages.count else {
            return
        }
        performHighlightReload(msgID: msgID, at: IndexPath(row: index, section: 0), delay: 0)
    }

    private func requestResend(_ message: MessageInfo) {
        let alert = UIAlertController(
            title: LocalizedChatString("TipsConfirmResendMessage"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedChatString("Confirm"), style: .default) { [weak self] _ in
            self?.viewModel.resendMessage(message)
        })
        findViewController()?.present(alert, animated: true)
    }

    private func postMentionNotification(for message: MessageInfo) {
        guard viewModel.isGroupChat else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("mentionUserNotification"),
            object: nil,
            userInfo: [
                "userID": message.from.userID,
                "nickname": message.from.nickname ?? ""
            ]
        )
    }

    private func handleAuxiliaryTextLongPress(message: MessageInfo, text: String, anchorFrame: CGRect) {
        guard !viewModel.isMultiSelectMode else { return }
        let copyAction = MessageActionMenuAction(
            ID: MessageActionIDs.copy,
            iconName: "message_copy",
            systemIconFallback: "doc.on.doc",
            label: LocalizedChatString("Copy")
        ) { _, _ in
            UIPasteboard.general.string = text
            WindowToastManager.shared.show(LocalizedChatString("Copied"), type: .success, duration: Self.toastShortDuration)
        }
        let forwardAction = MessageActionMenuAction(
            ID: MessageActionIDs.forward,
            iconName: "message_forward",
            systemIconFallback: "arrowshape.turn.up.right",
            label: LocalizedChatString("Forward")
        ) { [weak self] _, _ in
            self?.handleForwardAuxiliaryText(text)
        }
        MessageActionMenuController.shared.showAuxiliaryMenu(
            actions: [copyAction, forwardAction],
            message: message,
            anchorFrameInWindow: anchorFrame
        )
    }

    private func handleForwardAuxiliaryText(_ text: String) {
        let selector = ForwardTargetSelectorViewController { [weak self] conversationIDs in
            guard let self = self else { return }
            for conversationID in conversationIDs {
                let inputStore = MessageInputStore.create(conversationID: conversationID)
                let payload = TextSendMessagePayload(text: text)
                inputStore.sendMessage(payload: .text(payload), option: SendMessageOption(), completion: nil)
            }
        }
        findViewController()?.navigationController?.pushViewController(selector, animated: true)
    }

    private func handleListenFromHere(from notification: Notification) {
        guard let message = notification.userInfo?["message"] as? MessageInfo,
              let startIndex = messages.firstIndex(where: { $0.msgID == message.msgID }) else { return }

        let range = Array(messages[startIndex...])
        let plan = ListenPlanBuilder.build(messages: range)
        listenController.start(plan: plan)
    }

    private func handleShowForwardTargetSelector(from notification: Notification) {
        guard let messages = notification.userInfo?["messages"] as? [MessageInfo], !messages.isEmpty else { return }
        let selector = ForwardTargetSelectorViewController { [weak self] conversationIDs in
            self?.performForward(messages: messages, conversationIDs: conversationIDs)
        }
        findViewController()?.navigationController?.pushViewController(selector, animated: true)
    }

    private func performForward(messages: [MessageInfo], conversationIDs: [String], type: MessageForwardType = .separate) {
        let enableReadReceipt = AppBuilderConfig.shared.enableReadReceipt
        let preparedMessages = messages.map { message -> MessageInfo in
            var copy = message
            copy.needReadReceipt = enableReadReceipt
            return copy
        }
        for conversationID in conversationIDs {
            var option = ForwardMessageOption()
            option.forwardType = type
            var sendOption = SendMessageOption()
            sendOption.needReadReceipt = enableReadReceipt
            option.sendMessageOption = sendOption
            if type == .merged {
                option.mergedForwardInfo = viewModel.makeMergedForwardInfo(messages: preparedMessages)
            }
            viewModel.forwardMessages(preparedMessages, option: option, toConversationID: conversationID) { success in
                if !success {
                    WindowToastManager.shared.error(LocalizedChatString("RelayUnsupportForward"))
                }
            }
        }
        if viewModel.isMultiSelectMode {
            viewModel.exitMultiSelectMode()
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            responder = next
        }
        return nil
    }
}

// MARK: - UITableViewDataSource

extension MessageListViewImpl: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let kind = MessageCellRegistry.shared.renderKind(for: message)
        let timeString = viewModel.messageTimeString(at: indexPath.row)

        switch kind {
        case .systemTip, .revoked:
            return centeredTextCell(for: message, kind: kind, timeString: timeString, at: indexPath)
        case .bubble(let contentKind):
            return bubbleCell(for: message, contentKind: contentKind, timeString: timeString, at: indexPath)
        case .custom(let businessID):
            return bubbleCell(for: message, contentKind: .custom(businessID), timeString: timeString, at: indexPath)
        }
    }

    private func centeredTextCell(for message: MessageInfo,
                                  kind: MessageRenderKind,
                                  timeString: String?,
                                  at indexPath: IndexPath) -> UITableViewCell {
        let identifier = MessageCellRegistry.shared.reuseIdentifier(for: kind)
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? MessageCenteredTextCell else {
            return UITableViewCell()
        }
        let text = MessageCellRegistry.shared.centeredText(for: message, kind: kind, config: viewModel.config)
        cell.configure(text: text, timeString: timeString, showTime: viewModel.config.isShowTimeMessage)
        return cell
    }

    private func bubbleCell(for message: MessageInfo,
                            contentKind: MessageContentKind,
                            timeString: String?,
                            at indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: contentKind.reuseIdentifier, for: indexPath) as? MessageBaseCell else {
            return UITableViewCell()
        }
        cell.configure(
            message: message,
            contentKind: contentKind,
            timeString: timeString,
            context: makeContext(for: message),
            isMultiSelectMode: viewModel.isMultiSelectMode,
            isSelected: viewModel.isSelected(message),
            auxiliaryTextState: viewModel.auxiliaryTextState(for: message)
        )
        cell.onAvatarTap = { [weak self] tapped in self?.onUserClick?(tapped.from.userID) }
        cell.onAvatarLongPress = { [weak self] longPressed in self?.postMentionNotification(for: longPressed) }
        cell.onResendRequested = { [weak self] failed in self?.requestResend(failed) }
        cell.onQuotePreviewTap = { [weak self] host in self?.handleQuotePreviewTap(host) }
        cell.onBubbleLongPress = { [weak self] pressed, frameInWindow in
            self?.handleBubbleLongPress(pressed, bubbleFrameInWindow: frameInWindow)
        }
        cell.onReactionBarTap = { [weak self] tapped in self?.presentReactionDetail(for: tapped) }
        cell.onAuxiliaryTextLongPress = { [weak self] msg, text, anchorFrame in
            self?.handleAuxiliaryTextLongPress(message: msg, text: text, anchorFrame: anchorFrame)
        }
        cell.onReadReceiptTap = { [weak self] tapped in self?.presentReadReceiptDetail(message: tapped) }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MessageListViewImpl: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard viewModel.isMultiSelectMode, indexPath.row < messages.count else { return }
        viewModel.toggleSelection(messages[indexPath.row])
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        userHasInteracted = true
        isUserScrollSession = true
        pendingInitialScroll = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard hasPerformedInitialScroll else { return }

        let suppressPagination = isJumpScrolling || pendingScrollToQuoteInfo != nil || pendingFloatingScrollToMsgID != nil || pendingMentionSequence != nil
        if scrollView.contentOffset.y <= Self.loadMoreThreshold,
           viewModel.hasMoreOlderMessage, !isLoadingOlder, !suppressPagination {
            isLoadingOlder = true
            viewModel.loadOlderMessages()
        }
        let distanceFromBottom = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height)
        if distanceFromBottom <= Self.loadMoreThreshold,
           viewModel.hasMoreNewerMessage, !isLoadingNewer, !suppressPagination {
            isLoadingNewer = true
            viewModel.loadNewerMessages()
        }
        updateFloatingEntryForScroll()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard isJumpScrolling, let msgID = pendingHighlightMsgID, !msgID.isEmpty else { return }
        finishJumpScrollIfNeeded(msgID: msgID)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isUserScrollSession = false
            applyDeferredPrependIfNeeded()
            syncVisibleMessageReadReceipts()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrollSession = false
        applyDeferredPrependIfNeeded()
        syncVisibleMessageReadReceipts()
    }

    private func applyDeferredPrependIfNeeded() {
        guard !isUserScrollSession, let list = deferredPrependMessages else { return }
        applyMessageList(list)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let msgID = pendingHighlightMsgID,
              indexPath.row < messages.count,
              messages[indexPath.row].msgID == msgID,
              let messageCell = cell as? MessageBaseCell else { return }
        pendingHighlightPlayed = true
        messageCell.playHighlightAnimation()
    }
}
