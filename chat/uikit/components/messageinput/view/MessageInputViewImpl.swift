import Foundation
import UIKit
import Combine
import SnapKit
import AtomicXCore

final class MessageInputViewImpl: UIView {
    var onIntrinsicContentSizeInvalidated: (() -> Void)?

    var onAnimateSuperviewLayout: (() -> Void)?

    var bottomSafeAreaInset: CGFloat = 0 {
        didSet {
            guard bottomSafeAreaInset != oldValue else { return }

            if didAttachEmojiPicker {
                emojiPickerView.bottomSafeAreaInset = bottomSafeAreaInset
            }
            if didAttachMorePanel {
                morePanel.bottomSafeAreaInset = bottomSafeAreaInset
            }
            syncBottomAreaHeight()
        }
    }

    override var intrinsicContentSize: CGSize {
        let inputRowHeight = Self.inputRowVerticalPadding + currentInputContainerHeight + Self.inputRowVerticalPadding
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: (topDivider.isHidden ? 0 : Self.topDividerHeight) + currentQuoteBarHeight + inputRowHeight + currentBottomAreaHeight
        )
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicContentSizeInvalidated?()
    }

    private let viewModel: MessageInputViewModel

    private let typingController: TypingIndicatorController?

    var typingPublisher: AnyPublisher<Bool, Never>? {
        return typingController?.typingPublisher
    }

    func sendTypingStatus(hasContent: Bool) {
        typingController?.sendTypingStatus(hasContent: hasContent)
    }

    func invalidateTypingIndicator() {
        typingController?.invalidate()
    }

    private let config: MessageInputConfigProtocol

    var onTypingContentChanged: ((Bool) -> Void)?

    var onSendFailure: ((String) -> Void)?

    private let topDivider = UIView()

    private let inputRow = UIView()

    private let audioButton = MessageInputAppearanceButton(type: .system)

    private let inputContainer = UIView()

    private let messageTextView = MessageInputTextView()

    private let voiceLabel = UILabel()

    private let emojiButton = MessageInputAppearanceButton(type: .system)

    private let moreButton = MessageInputAppearanceButton(type: .system)

    private let moreButtonRedDot = UIView()

    private let sendButton = MessageInputAppearanceButton(type: .system)

    /// 机器人流式回复期间的停止按钮（替换发送/更多键），对齐 Android btnChatbotStop。
    private let chatbotStopButton = MessageInputAppearanceButton(type: .system)

    private let chatbotController: ChatbotConversationController?

    private var chatbotStateCancellable: AnyCancellable?

    private let bottomContainer = UIView()

    private let emojiPanelContainer = UIView()

    private let morePanelContainer = UIView()

    private lazy var emojiPickerView: EmojiPickerView = {
        let picker = EmojiPickerView()
        picker.onEmojiSelected = { [weak self] emoji in self?.handleEmojiSelected(emoji) }
        picker.onCustomEmojiSelected = { [weak self] group, emoji in self?.handleCustomEmojiSelected(group: group, emoji: emoji) }
        picker.onDelete = { [weak self] in self?.deleteLastCharacter() }
        picker.onSend = { [weak self] in self?.requestSendText() }
        return picker
    }()

    private var didAttachEmojiPicker = false

    private lazy var morePanel: MessageInputMorePanel = {
        let panel = MessageInputMorePanel(config: viewModel.config)
        panel.delegate = self
        panel.onRedDotDismissed = { [weak self] in
            self?.updateMoreButtonRedDotVisibility()
        }
        return panel
    }()

    private var didAttachMorePanel = false

    private var createdMediaCoordinator: MessageInputMediaCoordinator?

    private lazy var mediaCoordinator: MessageInputMediaCoordinator = {
        let coordinator = MessageInputMediaCoordinator(presentingView: self, viewModel: viewModel)
        createdMediaCoordinator = coordinator
        return coordinator
    }()

    private let quotePreviewBar = MessageInputQuotePreviewBar()

    private var currentQuotedMessage: MessageInfo?

    private var inputContainerHeightConstraint: Constraint?

    private var bottomAreaHeightConstraint: Constraint?

    private var quotePreviewBarHeightConstraint: Constraint?

    private var currentInputContainerHeight: CGFloat = MessageInputViewImpl.defaultInputContainerHeight

    private var currentEmojiPanelHeight: CGFloat = 0

    private var currentMorePanelHeight: CGFloat = 0

    private var currentKeyboardHeight: CGFloat = 0

    private var currentQuoteBarHeight: CGFloat = 0

    private var mentionList: [MentionInfo] = []

    private var draftSaveWorkItem: DispatchWorkItem?

    private var isLoadingDraft = false

    private var didLoadDraft = false

    private var isEmojiPanelShown = false

    private var isMorePanelShown = false

    private var isLongPressingAudio = false

    private var isTextInputLongPressArmed = false

    private lazy var textInputLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleTextInputLongPress(_:)))

    private lazy var textInputTap: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTextInputTap(_:)))
        tap.cancelsTouchesInView = false
        return tap
    }()

    private var isVoiceInputMode = false

    private static let emojiPanelHeight: CGFloat = 280

    private static let morePanelHeight: CGFloat = 242

    private static let quotePreviewBarHeight: CGFloat = 48

    private static let inputRowVerticalPadding: CGFloat = 11

    private static let topDividerHeight: CGFloat = 0.5

    private static let defaultInputContainerHeight: CGFloat = 34

    private static let inputRowHorizontalInset: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let inputRowButtonSize: CGFloat = 28

    private static let redDotSize: CGFloat = 8

    private static let textViewHorizontalInset: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let textViewMaxLines: Int = 6

    private static let voiceLongPressMinimumDuration: TimeInterval = 0.2

    private static let inputContainerCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let sendButtonCornerRadius: CGFloat = 14

    private static let sendButtonIconPointSize: CGFloat = 14

    private static let draftSaveDebounceInterval: TimeInterval = 0.8

    private static let draftKeyboardFocusDelay: TimeInterval = 0.15

    private static let draftLoadingResetDelay: TimeInterval = 0.2

    private static let layoutAnimationDuration: TimeInterval = 0.2

    private var currentBottomAreaHeight: CGFloat {
        if currentKeyboardHeight > 0 {
            return currentKeyboardHeight
        }
        return currentEmojiPanelHeight + currentMorePanelHeight + bottomSafeAreaInset
    }

    // MARK: - Init

    init(conversationID: String,
         config: MessageInputConfigProtocol = ChatMessageInputConfig(),
         chatbotController: ChatbotConversationController? = nil) {
        let viewModel = MessageInputViewModel(conversationID: conversationID, config: config)
        self.viewModel = viewModel
        self.config = viewModel.config
        self.chatbotController = chatbotController
        if config.enableTyping, conversationID.hasPrefix(Self.c2cConversationPrefix) {
            let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID
            typingController = TypingIndicatorController(conversationID: conversationID, currentUserID: currentUserID)
        } else {
            typingController = nil
        }
        super.init(frame: .zero)
        viewModel.onSendFailure = { [weak self] reason in
            self?.onSendFailure?(reason)
        }
        if let chatbotController {
            viewModel.onTextMessageSent = { [weak chatbotController] in
                chatbotController?.onTextMessageSent()
            }
        }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        bindChatbotState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Four-Step Lifecycle

    deinit {
        createdMediaCoordinator?.cancelVoiceRecording()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Window Lifecycle (对齐声明式 onAppear/onDisappear 草稿逻辑)

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            if !didLoadDraft {
                didLoadDraft = true
                loadDraft()
            }
        } else {
            cancelVoiceRecording()
            saveDraftImmediately()
        }
    }

    @objc func cancelVoiceRecording() {
        isLongPressingAudio = false
        isTextInputLongPressArmed = false
        createdMediaCoordinator?.cancelVoiceRecording()
    }

    // MARK: - Quote (引用)

    private func constructViewHierarchy() {
        addSubview(topDivider)
        addSubview(quotePreviewBar)
        addSubview(inputRow)
        if config.isShowAudioRecorder {
            inputRow.addSubview(audioButton)
        }
        inputRow.addSubview(inputContainer)
        inputContainer.addSubview(messageTextView)
        inputContainer.addSubview(voiceLabel)
        if config.isShowEmoji {
            inputRow.addSubview(emojiButton)
        }
        inputRow.addSubview(moreButton)
        moreButton.addSubview(moreButtonRedDot)
        inputRow.addSubview(sendButton)
        inputRow.addSubview(chatbotStopButton)
        addSubview(bottomContainer)
        bottomContainer.addSubview(emojiPanelContainer)
        bottomContainer.addSubview(morePanelContainer)
    }

    private func activateConstraints() {
        topDivider.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.topDividerHeight)
        }

        quotePreviewBar.snp.makeConstraints { make in
            make.top.equalTo(inputRow.snp.bottom)
            make.leading.trailing.equalToSuperview()
            quotePreviewBarHeightConstraint = make.height.equalTo(0).constraint
        }

        inputRow.snp.makeConstraints { make in
            make.top.equalTo(topDivider.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        var leftAnchor = inputRow.snp.leading
        var leftInset: CGFloat = Self.inputRowHorizontalInset
        if config.isShowAudioRecorder {
            audioButton.snp.makeConstraints { make in
                make.leading.equalTo(leftAnchor).offset(leftInset)
                make.centerY.equalTo(inputContainer)
                let size = MessageInputAppearanceApplier.buttonSize(config.appearance?.audioRecordButton, fallback: Self.inputRowButtonSize)
                make.width.equalTo(size.width)
                make.height.equalTo(size.height)
            }
            leftAnchor = audioButton.snp.trailing
            leftInset = Self.inputRowHorizontalInset
        }

        moreButtonRedDot.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.width.height.equalTo(Self.redDotSize)
        }
        layoutActionButtons(showSend: false, showMore: config.isShowMore, showStop: false)
        var rightAnchor = moreButton.snp.leading
        var rightInset: CGFloat = -Self.inputRowHorizontalInset

        if config.isShowEmoji {
            emojiButton.snp.makeConstraints { make in
                make.trailing.equalTo(rightAnchor).offset(rightInset)
                make.centerY.equalTo(inputContainer)
                let size = MessageInputAppearanceApplier.buttonSize(config.appearance?.emojiButton, fallback: Self.inputRowButtonSize)
                make.width.equalTo(size.width)
                make.height.equalTo(size.height)
            }
            rightAnchor = emojiButton.snp.leading
            rightInset = -Self.inputRowHorizontalInset
        }

        inputContainer.snp.makeConstraints { make in
            make.leading.equalTo(leftAnchor).offset(leftInset)
            make.trailing.equalTo(rightAnchor).offset(rightInset)
            make.top.equalToSuperview().offset(Self.inputRowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.inputRowVerticalPadding)
            inputContainerHeightConstraint = make.height.equalTo(Self.defaultInputContainerHeight).constraint
        }

        messageTextView.snp.makeConstraints { make in
            let padding = MessageInputAppearanceApplier.padding(config.appearance?.field?.horizontalPadding, fallback: Self.textViewHorizontalInset)
            make.leading.equalToSuperview().offset(padding)
            make.trailing.equalToSuperview().offset(-padding)
            make.top.bottom.equalToSuperview()
        }

        voiceLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bottomContainer.snp.makeConstraints { make in
            make.top.equalTo(quotePreviewBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
            bottomAreaHeightConstraint = make.height.equalTo(0).constraint
        }

        emojiPanelContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        morePanelContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func bindInteraction() {
        messageTextView.isGroupChat = viewModel.isGroupChat
        messageTextView.enableMention = config.enableMention
        messageTextView.maxLines = Self.textViewMaxLines
        messageTextView.placeholderText = config.appearance?.field?.hintText
            ?? LocalizedChatString(config.enableLongPressToTalk ? "SendMessage" : "SendMessageTextOnly")
        messageTextView.applyAppearance(config.appearance?.field)

        messageTextView.onSend = { [weak self] in self?.sendText() }
        messageTextView.onHeightChanged = { [weak self] height in
            guard let self = self else { return }
            let minimumHeight = MessageInputAppearanceApplier.dimension(self.config.appearance?.field?.minHeight, fallback: Self.defaultInputContainerHeight)
            let resolvedHeight = max(height, minimumHeight)
            self.inputContainerHeightConstraint?.update(offset: resolvedHeight)
            self.currentInputContainerHeight = resolvedHeight
            self.invalidateIntrinsicContentSize()
        }
        messageTextView.onContentChanged = { [weak self] _ in
            self?.handleContentChanged()
            self?.updateSendButtonVisibility()
        }
        messageTextView.onUserTextChanged = { [weak self] hasContent in
            self?.onTypingContentChanged?(hasContent)
        }
        messageTextView.onAtTriggered = { [weak self] position in
            guard let self = self, self.viewModel.isGroupChat, self.config.enableMention else { return }
            self.presentMentionPicker(atPosition: position)
        }
        messageTextView.mentionToDeleteAtPosition = { [weak self] position in
            self?.findMentionToDelete(at: position)
        }
        messageTextView.onMentionDeleted = { [weak self] startIndex in
            self?.mentionList.removeAll { $0.startIndex == startIndex }
        }

        moreButton.addTarget(self, action: #selector(handleMoreTapped), for: .touchUpInside)
        emojiButton.addTarget(self, action: #selector(handleEmojiTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(handleSendTapped), for: .touchUpInside)
        chatbotStopButton.addTarget(self, action: #selector(handleChatbotStopTapped), for: .touchUpInside)

        audioButton.addTarget(self, action: #selector(handleAudioTapped), for: .touchUpInside)

        let voiceLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleAudioLongPress(_:)))
        voiceLongPress.minimumPressDuration = Self.voiceLongPressMinimumDuration
        voiceLongPress.isEnabled = config.enableLongPressToTalk
        voiceLabel.addGestureRecognizer(voiceLongPress)
        voiceLabel.isUserInteractionEnabled = true
        let voiceTap = UITapGestureRecognizer(target: self, action: #selector(handleAudioTapped))
        voiceLabel.addGestureRecognizer(voiceTap)

        textInputLongPress.isEnabled = config.enableLongPressToTalk
        textInputLongPress.delegate = self
        messageTextView.addGestureRecognizer(textInputLongPress)
        textInputTap.require(toFail: textInputLongPress)
        textInputTap.delegate = self
        messageTextView.addGestureRecognizer(textInputTap)
        messageTextView.shouldBlockFirstResponder = { [weak self] in
            return self?.isTextInputLongPressArmed == true
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextViewDidChange),
            name: UITextView.textDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMentionUserNotification(_:)),
            name: NSNotification.Name("mentionUserNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQuoteMessageNotification(_:)),
            name: NSNotification.Name("quoteMessageNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMessageListBlankAreaClick),
            name: MessageListView.blankAreaClickNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelVoiceRecording),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        quotePreviewBar.onClose = { [weak self] in
            self?.clearQuote()
        }
    }

    private func setupViewStyle() {
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        topDivider.backgroundColor = colors.strokeColorPrimary
        inputRow.backgroundColor = colors.bgColorOperate

        inputContainer.backgroundColor = colors.bgColorInput
        inputContainer.layer.cornerRadius = Self.inputContainerCornerRadius
        inputContainer.layer.masksToBounds = true

        bottomContainer.backgroundColor = colors.bgColorOperate
        bottomContainer.clipsToBounds = true
        emojiPanelContainer.backgroundColor = colors.bgColorOperate
        emojiPanelContainer.clipsToBounds = true
        emojiPanelContainer.isHidden = true
        morePanelContainer.backgroundColor = colors.bgColorOperate
        morePanelContainer.clipsToBounds = true
        morePanelContainer.isHidden = true

        configureIconButton(audioButton, imageName: "input_audio")
        configureIconButton(emojiButton, imageName: "input_emoji")
        configureIconButton(moreButton, imageName: "input_more")
        configureSendButton()

        configureVoiceLabel()
        sendButton.isHidden = true

        moreButtonRedDot.backgroundColor = colors.textColorError
        moreButtonRedDot.layer.cornerRadius = Self.redDotSize / 2
        moreButtonRedDot.isUserInteractionEnabled = false
        moreButtonRedDot.isHidden = true
        if config.isShowMore {
            updateMoreButtonRedDotVisibility()
        }

        chatbotStopButton.backgroundColor = colors.buttonColorPrimaryDefault
        chatbotStopButton.layer.cornerRadius = Self.sendButtonCornerRadius
        chatbotStopButton.layer.masksToBounds = true
        let stopImage = UIImage(systemName: "stop.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.sendButtonIconPointSize, weight: .bold))
            .withRenderingMode(.alwaysTemplate)
        chatbotStopButton.setImage(stopImage, for: .normal)
        chatbotStopButton.tintColor = colors.textColorButton
        chatbotStopButton.isHidden = true
        applyInputAppearance()
        updateSendButtonVisibility()
    }

    private func applyInputAppearance() {
        let appearance = config.appearance
        let colors = TUIChatKitTheme.colors
        MessageInputAppearanceApplier.apply(fill: appearance?.fill, to: self, defaultColor: colors.bgColorOperate)
        inputRow.backgroundColor = .clear
        topDivider.isHidden = appearance?.showTopDivider == false
        topDivider.snp.updateConstraints { make in
            make.height.equalTo(topDivider.isHidden ? 0 : Self.topDividerHeight)
        }
        inputContainer.layer.cornerRadius = MessageInputAppearanceApplier.cornerRadius(
            appearance?.field?.cornerRadius, fallback: Self.inputContainerCornerRadius,
            size: CGSize(width: currentInputContainerHeight, height: currentInputContainerHeight)
        )
        MessageInputAppearanceApplier.apply(fill: appearance?.field?.fill, to: inputContainer, defaultColor: colors.bgColorInput)
        voiceLabel.textColor = appearance?.field?.textColor ?? colors.textColorPrimary
        if let height = appearance?.field?.minHeight, height.isFinite, height > currentInputContainerHeight {
            currentInputContainerHeight = height
            inputContainerHeightConstraint?.update(offset: height)
        }
    }

    private func applyButtonAppearances() {
        let colors = TUIChatKitTheme.colors
        let appearance = config.appearance
        let buttons: [(MessageInputAppearanceButton, MessageInputButtonAppearance?, Bool, String)] = [
            (audioButton, appearance?.audioRecordButton, isVoiceInputMode, isVoiceInputMode ? "input_keyboard" : "input_audio"),
            (emojiButton, appearance?.emojiButton, isEmojiPanelShown, isEmojiPanelShown ? "input_keyboard" : "input_emoji"),
            (moreButton, appearance?.moreButton, isMorePanelShown, "input_more")
        ]
        for (button, style, active, imageName) in buttons {
            MessageInputAppearanceApplier.applyButton(button, appearance: style, active: active,
                defaultImage: AtomicXChatResources.image(named: imageName), defaultTint: colors.textColorSecondary,
                defaultFill: .clear, defaultCornerRadius: 0,
                size: MessageInputAppearanceApplier.buttonSize(style, fallback: Self.inputRowButtonSize))
        }
        let defaultImage = UIImage(systemName: "arrow.up")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.sendButtonIconPointSize, weight: .bold))
        MessageInputAppearanceApplier.applyButton(sendButton, appearance: appearance?.sendButton, active: false,
            defaultImage: defaultImage, defaultTint: colors.textColorButton, defaultFill: colors.buttonColorPrimaryDefault,
            defaultCornerRadius: Self.sendButtonCornerRadius,
            size: MessageInputAppearanceApplier.buttonSize(appearance?.sendButton, fallback: Self.inputRowButtonSize, supportsTitle: true),
            supportsTitle: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if config.appearance?.field?.cornerRadius == MessageInputButtonAppearance.cornerRadiusPill {
            inputContainer.layer.cornerRadius = min(inputContainer.bounds.width, inputContainer.bounds.height) / 2
        }
        MessageInputAppearanceApplier.update(self)
        MessageInputAppearanceApplier.update(inputContainer)
    }

    /// Mirrors the panel's remaining dots onto the more button. Reading
    /// `morePanel` here also builds its actions up front, which is what lets the
    /// button carry a dot before the panel has ever been opened.
    private func updateMoreButtonRedDotVisibility() {
        moreButtonRedDot.isHidden = !morePanel.hasVisibleRedDot
    }

    /// 订阅机器人回复状态：流式输出期间把发送/更多键换成停止键，对齐 Android bindChatbotState。
    ///
    /// 只有真有一条能打断的流式回复在跑时才切换（canInterrupt）。等待态不切换：那条路径上
    /// 用户看到的是列表里的「正在输入」气泡，输入栏是好的，点了必须真能发出去。
    private func bindChatbotState() {
        guard let controller = chatbotController else { return }
        chatbotStateCancellable = controller.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSendButtonVisibility()
            }
    }

    @objc private func handleChatbotStopTapped() {
        chatbotController?.sendInterrupt(completion: nil)
    }

    private func configureIconButton(_ button: UIButton, imageName: String) {
        let image = AtomicXChatResources.image(named: imageName)?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = TUIChatKitTheme.colors.textColorSecondary
        button.imageView?.contentMode = .scaleAspectFit
    }

    private func configureSendButton() {
        let colors = TUIChatKitTheme.colors
        sendButton.backgroundColor = colors.buttonColorPrimaryDefault
        sendButton.layer.cornerRadius = Self.sendButtonCornerRadius
        sendButton.layer.masksToBounds = true
        let arrowImage = UIImage(systemName: "arrow.up")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.sendButtonIconPointSize, weight: .bold))
            .withRenderingMode(.alwaysTemplate)
        sendButton.setImage(arrowImage, for: .normal)
        sendButton.tintColor = colors.textColorButton
    }

    private func configureVoiceLabel() {
        let colors = TUIChatKitTheme.colors
        voiceLabel.text = LocalizedChatString("InputHoldToTalk")
        voiceLabel.font = FontScheme.caption1Regular
        voiceLabel.textAlignment = .center
        voiceLabel.textColor = colors.textColorPrimary
        voiceLabel.backgroundColor = .clear
        voiceLabel.isHidden = true
    }

    private func setEmojiPanelContent(_ contentView: UIView?) {
        emojiPanelContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let contentView = contentView else { return }
        emojiPanelContainer.addSubview(contentView)
        contentView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    private func showKeyboard() {
        messageTextView.becomeFirstResponder()
    }

    private func insertEmoji(_ emojiString: NSAttributedString, emojiName: String) {
        messageTextView.insertEmoji(emojiString, emojiName: emojiName)
    }

    private func deleteLastCharacter() {
        messageTextView.deleteLastCharacter()
    }

    private func requestSendText() {
        sendText()
    }

    private func appendMention(userID: String, displayName: String) {
        let displayTextLength = messageTextView.attributedContent?.length ?? 0
        let mentionText = "@\(displayName) "
        let mention = MentionInfo(
            userID: userID,
            displayName: displayName,
            startIndex: displayTextLength,
            length: mentionText.count
        )
        let attributed = EmojiManager.shared.createAttributedStringWithTextAndStyle(
            text: mentionText,
            withFont: FontScheme.caption1Regular,
            textColor: TUIChatKitTheme.colors.textColorPrimary
        )
        mentionList.append(mention)
        messageTextView.appendText(attributed)
        messageTextView.becomeFirstResponder()
    }

    private func insertMentions(_ mentions: [MentionInfo], atPosition: Int) {
        guard !mentions.isEmpty else { return }
        let adjustedPosition = messageTextView.convertDisplayPositionToTextPosition(atPosition)
        var currentText = messageTextView.extractSendText()
        if currentText.isEmpty { currentText = "@" }

        let atIndex = currentText.index(currentText.startIndex, offsetBy: min(adjustedPosition, currentText.count))
        let afterAtIndex = currentText.index(after: atIndex)

        var combinedMentionText = ""
        var newMentions: [MentionInfo] = []
        var currentOffset = adjustedPosition
        for mention in mentions {
            var newMention = mention
            newMention.startIndex = currentOffset
            combinedMentionText += mention.mentionText
            newMentions.append(newMention)
            currentOffset += mention.mentionText.count
        }

        currentText.replaceSubrange(atIndex..<afterAtIndex, with: combinedMentionText)

        let insertedLength = combinedMentionText.count - 1
        for i in 0..<mentionList.count where mentionList[i].startIndex > adjustedPosition {
            mentionList[i].startIndex += insertedLength
        }
        mentionList.append(contentsOf: newMentions)

        let newAttributedString = EmojiManager.shared.createAttributedStringWithTextAndStyle(
            text: currentText,
            withFont: FontScheme.caption1Regular,
            textColor: TUIChatKitTheme.colors.textColorPrimary
        )
        messageTextView.setContent(newAttributedString)
    }

    private func sendText() {
        let text = messageTextView.extractSendText()
        guard !text.isEmpty else { return }
        // 有可打断的流式回复在跑时拦住发送，对齐 Android canSend 门控
        guard chatbotController?.canInterrupt != true else { return }

        var convertedMentions: [MentionInfo] = []
        for mention in mentionList {
            let convertedStartIndex = messageTextView.convertDisplayPositionToTextPosition(mention.startIndex)
            convertedMentions.append(MentionInfo(
                userID: mention.userID,
                displayName: mention.displayName,
                startIndex: convertedStartIndex,
                length: mention.length
            ))
        }

        viewModel.sendTextMessage(text, mentionList: convertedMentions, quotedMessage: currentQuotedMessage)
        viewModel.clearDraft()
        mentionList.removeAll()
        clearQuote()
        messageTextView.clear()
        updateSendButtonVisibility()
    }

    private func findMentionToDelete(at position: Int) -> (startIndex: Int, length: Int)? {
        for mention in mentionList where position > mention.startIndex && position < mention.endIndex {
            return (mention.startIndex, mention.length)
        }
        return nil
    }

    private func presentMentionPicker(atPosition: Int) {
        let groupID = viewModel.groupID
        guard viewModel.isGroupChat, !groupID.isEmpty else { return }
        let picker = MentionMemberPickerViewController(
            groupID: groupID,
            atPosition: atPosition
        ) { [weak self] mentions, position in
            self?.insertMentions(mentions, atPosition: position)
            self?.messageTextView.becomeFirstResponder()
        }
        findViewController()?.present(picker, animated: true)
    }

    @objc private func handleMentionUserNotification(_ notification: Notification) {
        guard viewModel.isGroupChat, config.enableMention else { return }
        guard let userInfo = notification.userInfo,
              userInfo["conversationID"] as? String == viewModel.conversationID,
              let userID = userInfo["userID"] as? String,
              let nickname = userInfo["nickname"] as? String else { return }
        appendMention(userID: userID, displayName: nickname)
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

    private func handleContentChanged() {
        guard !isLoadingDraft else { return }
        saveDraftWithDebounce()
    }

    private func saveDraftWithDebounce() {
        draftSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.saveDraftImmediately() }
        draftSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.draftSaveDebounceInterval, execute: workItem)
    }

    private func saveDraftImmediately() {
        viewModel.saveDraft(messageTextView.extractSendText())
    }

    private func loadDraft() {
        viewModel.loadDraft { [weak self] draft in
            guard let self = self, let draft = draft, !draft.isEmpty else { return }
            self.isLoadingDraft = true
            let attributed = EmojiManager.shared.createAttributedStringFromEmojiCodes(from: draft)
            self.messageTextView.setContent(attributed)
            self.updateSendButtonVisibility()
            self.focusKeyboardAfterTransition()
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.draftLoadingResetDelay) {
                self.isLoadingDraft = false
            }
        }
    }

    private func focusKeyboardAfterTransition() {
        let focus = { [weak self] in
            _ = self?.messageTextView.becomeFirstResponder()
        }
        guard let coordinator = findViewController()?.transitionCoordinator else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.draftKeyboardFocusDelay, execute: focus)
            return
        }
        coordinator.animate(alongsideTransition: nil, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.draftKeyboardFocusDelay, execute: focus)
        })
    }

    private func showEmojiPanel() {

        if isVoiceInputMode {
            switchToTextMode()
        }
        attachBuiltInEmojiPickerIfNeeded()
        if didAttachEmojiPicker {
            emojiPickerView.reloadRecentEmojis()
        }

        hideMorePanel(silent: true)

        currentKeyboardHeight = 0
        isEmojiPanelShown = true
        currentEmojiPanelHeight = Self.emojiPanelHeight
        emojiPanelContainer.isHidden = false
        syncBottomAreaHeight()
        endEditing(true)
        emojiButton.setImage(
            AtomicXChatResources.image(named: "input_keyboard")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        syncPlaceholderSuppression()
        postInputInteract()
        animateLayout()
    }

    private func hideEmojiPanel(silent: Bool = false) {
        guard isEmojiPanelShown else { return }
        isEmojiPanelShown = false
        currentEmojiPanelHeight = 0
        emojiPanelContainer.isHidden = true
        emojiButton.setImage(
            AtomicXChatResources.image(named: "input_emoji")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        syncPlaceholderSuppression()
        if !silent {
            syncBottomAreaHeight()
            animateLayout()
        }
    }

    private func attachBuiltInEmojiPickerIfNeeded() {
        guard !didAttachEmojiPicker, emojiPanelContainer.subviews.isEmpty else { return }
        didAttachEmojiPicker = true

        emojiPickerView.bottomSafeAreaInset = bottomSafeAreaInset
        setEmojiPanelContent(emojiPickerView)
    }

    private func showMorePanel() {

        if isVoiceInputMode {
            switchToTextMode()
        }
        attachMorePanelIfNeeded()

        hideEmojiPanel(silent: true)

        currentKeyboardHeight = 0
        isMorePanelShown = true
        currentMorePanelHeight = Self.morePanelHeight
        morePanelContainer.isHidden = false
        syncBottomAreaHeight()
        endEditing(true)
        syncPlaceholderSuppression()
        postInputInteract()
        animateLayout()
    }

    private func hideMorePanel(silent: Bool = false) {
        guard isMorePanelShown else { return }
        isMorePanelShown = false
        currentMorePanelHeight = 0
        morePanelContainer.isHidden = true
        syncPlaceholderSuppression()
        if !silent {
            syncBottomAreaHeight()
            animateLayout()
        }
    }

    private func syncPlaceholderSuppression() {
        messageTextView.suppressPlaceholderForPanel = isEmojiPanelShown || isMorePanelShown
        applyButtonAppearances()
    }

    private func syncBottomAreaHeight() {
        bottomAreaHeightConstraint?.update(offset: currentBottomAreaHeight)
        invalidateIntrinsicContentSize()
    }

    private func attachMorePanelIfNeeded() {
        guard !didAttachMorePanel else { return }
        didAttachMorePanel = true

        morePanel.bottomSafeAreaInset = bottomSafeAreaInset
        morePanelContainer.addSubview(morePanel)
        morePanel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func handleEmojiSelected(_ emoji: EmojiData) {
        let attributed = EmojiManager.shared.createAttributedStringFromEmojiData(emoji)
        messageTextView.insertEmoji(attributed, emojiName: emoji.name ?? "")
    }

    private func handleCustomEmojiSelected(group: EmojiGroup, emoji: EmojiData) {
        guard let groupIndex = EmojiConfig.shared.emojiGroups.firstIndex(where: { $0.id == group.id }),
              let key = emoji.name, !key.isEmpty else { return }
        viewModel.sendFaceMessage(groupIndex: groupIndex, faceData: key, quotedMessage: currentQuotedMessage)
        if currentQuotedMessage != nil {
            clearQuote()
        }
    }

    private func animateLayout() {
        UIView.animate(withDuration: Self.layoutAnimationDuration) {
            self.onAnimateSuperviewLayout?()
            self.layoutIfNeeded()
        }
    }

    private func updateSendButtonVisibility() {
        // 可打断的流式回复在跑：只出停止键，对齐 Android MessageInputActionVisibilityPolicy
        let showStop = chatbotController?.canInterrupt == true
        let hasText = !messageTextView.extractSendText().isEmpty
        let showSend = !showStop && config.isShowSendButton && !isVoiceInputMode
            && (hasText || config.keepSendButtonVisible)
        let showMore = !showStop && config.isShowMore && (config.keepSendButtonVisible || !showSend)
        sendButton.isHidden = !showSend
        sendButton.isEnabled = hasText
        moreButton.isHidden = !showMore
        chatbotStopButton.isHidden = !showStop
        layoutActionButtons(showSend: showSend, showMore: showMore, showStop: showStop)
        applyButtonAppearances()
    }

    private func layoutActionButtons(showSend: Bool, showMore: Bool, showStop: Bool) {
        let sendSize = MessageInputAppearanceApplier.buttonSize(config.appearance?.sendButton, fallback: Self.inputRowButtonSize, supportsTitle: true)
        let moreSize = MessageInputAppearanceApplier.buttonSize(config.appearance?.moreButton, fallback: Self.inputRowButtonSize)
        let sendWidth = showSend ? sendSize.width : 0
        let moreWidth = showMore ? moreSize.width : 0
        let gap = showSend && showMore ? Self.inputRowHorizontalInset : 0
        sendButton.snp.remakeConstraints { make in
            make.trailing.equalTo(inputRow).offset(-Self.inputRowHorizontalInset)
            make.centerY.equalTo(inputContainer)
            make.width.equalTo(sendWidth)
            make.height.equalTo(sendSize.height)
        }
        moreButton.snp.remakeConstraints { make in
            make.trailing.equalTo(sendButton.snp.leading).offset(-gap)
            make.centerY.equalTo(inputContainer)
            let stopWidth = showStop ? Self.inputRowButtonSize : 0
            make.width.equalTo(max(moreWidth, stopWidth))
            make.height.equalTo(moreSize.height)
        }
        chatbotStopButton.snp.remakeConstraints { make in
            make.trailing.equalTo(inputRow).offset(-Self.inputRowHorizontalInset)
            make.centerY.equalTo(inputContainer)
            make.width.height.equalTo(Self.inputRowButtonSize)
        }
    }

    private func postInputInteract() {
        NotificationCenter.default.post(name: MessageInputView.inputInteractNotification, object: nil)
    }

    @objc private func handleMessageListBlankAreaClick() {
        hideEmojiPanel()
        hideMorePanel()
    }

    @objc private func handleKeyboardWillShow(_ notification: Notification) {

        hideEmojiPanel(silent: true)
        hideMorePanel(silent: true)
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let bottomOnScreen: CGFloat
            if let window = window {
                bottomOnScreen = window.convert(convert(bounds, to: window), to: nil).maxY
            } else {
                bottomOnScreen = UIScreen.main.bounds.height
            }
            currentKeyboardHeight = max(bottomOnScreen - frame.origin.y, 0)
        }
        syncBottomAreaHeight()
        animateLayout()
        postInputInteract()
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        guard !isEmojiPanelShown, !isMorePanelShown else { return }
        currentKeyboardHeight = 0
        syncBottomAreaHeight()
    }

    @objc private func handleTextViewDidChange() {
        guard !isLoadingDraft else { return }
        postInputInteract()
    }

    @objc private func handleMoreTapped() {
        if isMorePanelShown {
            hideMorePanel()
        } else {
            showMorePanel()
        }
    }

    @objc private func handleEmojiTapped() {
        if isEmojiPanelShown {
            showKeyboard()
        } else {
            showEmojiPanel()
        }
    }

    @objc private func handleSendTapped() {
        sendText()
    }

    @objc private func handleAudioTapped() {
        if isVoiceInputMode {
            switchToTextMode()
        } else {
            switchToVoiceMode()
        }
    }

    private func switchToVoiceMode() {
        guard config.isShowAudioRecorder else { return }
        isVoiceInputMode = true
        messageTextView.isHidden = true
        voiceLabel.isHidden = false
        audioButton.setImage(
            AtomicXChatResources.image(named: "input_keyboard")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        endEditing(true)
        hideEmojiPanel()
        hideMorePanel()
        updateSendButtonVisibility()
        postInputInteract()
    }

    private func switchToTextMode() {
        isVoiceInputMode = false
        messageTextView.isHidden = false
        voiceLabel.isHidden = true
        audioButton.setImage(
            AtomicXChatResources.image(named: "input_audio")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        updateSendButtonVisibility()
        postInputInteract()
    }

    @objc private func handleAudioLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let window = window else {
            cancelVoiceRecording()
            return
        }
        switch gesture.state {
        case .began:
            guard !isLongPressingAudio else { return }
            hideEmojiPanel()
            hideMorePanel()
            messageTextView.resignFirstResponder()
            postInputInteract()
            isLongPressingAudio = mediaCoordinator.beginVoiceRecording(finger: gesture.location(in: window))
        case .changed:
            guard isLongPressingAudio else { return }
            mediaCoordinator.updateVoiceRecording(finger: gesture.location(in: window))
        case .ended:
            guard isLongPressingAudio else { return }
            isLongPressingAudio = false
            mediaCoordinator.endVoiceRecording(finger: gesture.location(in: window))
        case .cancelled, .failed:
            guard isLongPressingAudio else { return }
            cancelVoiceRecording()
        default:
            break
        }
    }

    @objc private func handleTextInputLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let window = window else {
            cancelVoiceRecording()
            return
        }
        switch gesture.state {
        case .began:
            guard !isLongPressingAudio, canArmVoiceRecordingFromTextInput() else { return }
            hideEmojiPanel()
            hideMorePanel()
            messageTextView.resignFirstResponder()
            postInputInteract()
            isLongPressingAudio = mediaCoordinator.beginVoiceRecording(finger: gesture.location(in: window))
        case .changed:
            guard isLongPressingAudio else { return }
            mediaCoordinator.updateVoiceRecording(finger: gesture.location(in: window))
        case .ended:
            isTextInputLongPressArmed = false
            guard isLongPressingAudio else { return }
            isLongPressingAudio = false
            mediaCoordinator.endVoiceRecording(finger: gesture.location(in: window))
        case .cancelled, .failed:
            isTextInputLongPressArmed = false
            guard isLongPressingAudio else { return }
            cancelVoiceRecording()
        default:
            break
        }
    }

    @objc private func handleTextInputTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        isTextInputLongPressArmed = false
        guard !isLongPressingAudio, !isVoiceInputMode else { return }
        messageTextView.becomeFirstResponder()
    }

    private func canArmVoiceRecordingFromTextInput() -> Bool {
        return config.isShowAudioRecorder
            && !isVoiceInputMode
            && !isEmojiPanelShown
            && !isMorePanelShown
            && messageTextView.attributedContent == nil
    }

    @objc private func handleQuoteMessageNotification(_ notification: Notification) {
        guard notification.userInfo?["conversationID"] as? String == viewModel.conversationID,
              let message = notification.userInfo?["message"] as? MessageInfo else { return }
        setQuoteMessage(message)
    }

    private func setQuoteMessage(_ message: MessageInfo) {
        if isVoiceInputMode {
            switchToTextMode()
        }
        currentQuotedMessage = message
        let senderName = message.from.nickname ?? message.from.userID
        let summary = MessageInputQuoteSummaryFormatter.format(message: message)
        quotePreviewBar.configure(senderName: senderName, summary: summary)
        showQuoteBar()
        messageTextView.becomeFirstResponder()
        postInputInteract()
    }

    private func clearQuote() {
        currentQuotedMessage = nil
        hideQuoteBar()
    }

    private func showQuoteBar() {
        guard currentQuoteBarHeight == 0 else { return }
        quotePreviewBarHeightConstraint?.update(offset: Self.quotePreviewBarHeight)
        currentQuoteBarHeight = Self.quotePreviewBarHeight
        quotePreviewBar.isHidden = false
        invalidateIntrinsicContentSize()
        animateLayout()
    }

    private func hideQuoteBar() {
        guard currentQuoteBarHeight != 0 else { return }
        quotePreviewBarHeightConstraint?.update(offset: 0)
        currentQuoteBarHeight = 0
        quotePreviewBar.isHidden = true
        invalidateIntrinsicContentSize()
        animateLayout()
    }
}

// MARK: - MessageInputMorePanelDelegate

extension MessageInputViewImpl: MessageInputMorePanelDelegate {
    private static let c2cConversationPrefix = "c2c_"

    func morePanelDidSelectAlbum() {
        hideMorePanel()
        AlbumPickerMediaSendCoordinator.shared.showAlbumPicker(
            conversationID: viewModel.conversationID,
            enableReadReceipt: config.enableReadReceipt
        )
    }

    func morePanelDidSelectCamera() {
        hideMorePanel()
        mediaCoordinator.showCamera(recordMode: .photoOnly)
    }

    func morePanelDidSelectVideo() {
        hideMorePanel()
        mediaCoordinator.showCamera(recordMode: .videoPhotoMix)
    }

    func morePanelDidSelectFile() {
        hideMorePanel()
        mediaCoordinator.showFilePicker()
    }

    func morePanelDidSelectVideoCall() {
        hideMorePanel()
        startCall(mediaType: .video)
    }

    func morePanelDidSelectAudioCall() {
        hideMorePanel()
        startCall(mediaType: .audio)
    }

    private func startCall(mediaType: ChatCallEventPublisher.MediaType) {
        if !viewModel.isGroupChat, let targetUserID = c2cTargetUserID() {
            DataReport.reportInteractionMetrics(.chatInvokeCall)
            ChatCallEventPublisher.publishStartCall(participantIDs: [targetUserID], mediaType: mediaType)
            return
        }
        presentGroupCallMemberPicker(mediaType: mediaType)
    }

    private func c2cTargetUserID() -> String? {
        let conversationID = viewModel.conversationID
        guard conversationID.hasPrefix(Self.c2cConversationPrefix) else { return nil }
        let target = String(conversationID.dropFirst(Self.c2cConversationPrefix.count))
        return target.isEmpty ? nil : target
    }

    private func presentGroupCallMemberPicker(mediaType: ChatCallEventPublisher.MediaType) {
        let groupID = viewModel.groupID
        guard !groupID.isEmpty, let presenter = findViewController() else { return }
        let title = mediaType == .video ? LocalizedChatString("MoreVideoCall") : LocalizedChatString("MoreVoiceCall")
        let picker = GroupCallMemberPickerViewController(groupID: groupID, title: title) { userIDs in
            DataReport.reportInteractionMetrics(.chatInvokeCall)
            ChatCallEventPublisher.publishStartCall(participantIDs: userIDs, mediaType: mediaType, chatGroupID: groupID)
        }
        let navigationController = UINavigationController(rootViewController: picker)
        navigationController.isNavigationBarHidden = true
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true)
    }
}

extension MessageInputViewImpl: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == textInputLongPress || gestureRecognizer == textInputTap
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == textInputLongPress, canArmVoiceRecordingFromTextInput() {
            isTextInputLongPressArmed = true
        }
        return true
    }
}
