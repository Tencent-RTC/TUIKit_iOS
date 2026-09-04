import UIKit
import SnapKit
import AtomicXCore

final class MergedMessageDetailViewController: UIViewController, SystemNavigationBarPage {
    private let mergedMessage: MessageInfo

    private let config: MessageListConfigProtocol

    private let messageListStore: MessageListStore

    private let quoteResolveStore: MessageListStore

    private let conversationID: String

    private var messages: [MessageInfo] = []

    private var actionStore: MessageActionStore?

    private var pendingHighlightIndex: Int?

    private var mediaObservers: [NSObjectProtocol] = []

    private static let mediaDownloadNotificationName = Notification.Name(rawValue: "messageMediaDownload")

    private static let mediaDownloadProgressNotificationName = Notification.Name(rawValue: "messageMediaDownloadProgress")

    private static let estimatedRowHeight: CGFloat = 60

    private static let backIconPointSize: CGFloat = 18

    private static let downloadProgressComplete = 100

    private static let quoteToastDuration: TimeInterval = 3

    private static let quoteResolvePageCount = 20

    private static let highlightFallbackDelay: TimeInterval = 1.0

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.keyboardDismissMode = .onDrag
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = Self.estimatedRowHeight
        table.allowsSelection = false
        return table
    }()

    private lazy var loadingView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = FontScheme.caption2Regular
        label.textColor = TUIChatKitTheme.colors.textColorSecondary
        label.text = LocalizedChatString("RelayNoMessage")
        label.isHidden = true
        return label
    }()

    // MARK: - Init

    init(mergedMessage: MessageInfo, conversationID: String, config: MessageListConfigProtocol = ChatMessageListConfig(alignment: LanguageHelper.isRTL ? .right : .left)) {
        self.mergedMessage = mergedMessage
        self.conversationID = conversationID
        self.config = config
        self.messageListStore = MessageListStore.create(conversationID: "")
        self.quoteResolveStore = MessageListStore.create(conversationID: conversationID)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        registerCells()
        bindInteraction()
        observeMediaDownloadNotifications()
        loadMergedMessages()
    }

    deinit {
        mediaObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Cell Context

    private func setupNavigation() {
        title = Self.title(from: mergedMessage)
        navigationItem.leftBarButtonItem = BackBarButtonFactory.makeBackBarButtonItem(
            target: self,
            action: #selector(handleBack),
            tintColor: TUIChatKitTheme.colors.textColorPrimary
        )
    }

    @objc private func handleBack() {
        closePage()
    }

    private static func title(from message: MessageInfo) -> String {
        if case .merged(let payload) = message.messagePayload, !payload.title.isEmpty {
            return payload.title
        }
        return LocalizedChatString("RelayChatHistory")
    }

    private func constructViewHierarchy() {
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyLabel)
    }

    private func activateConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let listColor = TUIChatKitTheme.colors.listColorDefault
        view.backgroundColor = listColor
        tableView.backgroundColor = listColor
    }

    private func registerCells() {
        for identifier in MessageContentKind.allReuseIdentifiers {
            tableView.register(MessageBaseCell.self, forCellReuseIdentifier: identifier)
        }
        tableView.register(MessageCenteredTextCell.self,
                           forCellReuseIdentifier: MessageCellRegistry.systemTipReuseIdentifier)
        tableView.register(MessageCenteredTextCell.self,
                           forCellReuseIdentifier: MessageCellRegistry.revokedReuseIdentifier)
    }

    private func bindInteraction() {
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func loadMergedMessages() {
        loadingView.startAnimating()
        let store = MessageActionStore.create(message: mergedMessage)
        actionStore = store
        store.downloadMergedMessageList(completion: MergedDetailCompletionHandler(
            onSuccess: { [weak self] list in
                DispatchQueue.main.async { self?.applyMessages(list) }
            },
            onFailure: { [weak self] _, _ in
                DispatchQueue.main.async { self?.applyMessages([]) }
            }
        ))
    }

    private func applyMessages(_ list: [MessageInfo]) {
        loadingView.stopAnimating()
        messages = list.filter { $0.status != .revoked }
        tableView.reloadData()
        emptyLabel.isHidden = !messages.isEmpty
        resolveQuotesFromCloudIfNeeded()
    }

    private func resolveQuotesFromCloudIfNeeded() {
        let pending = messages.enumerated().compactMap { index, message -> (Int, MessageQuoteInfo)? in
            guard let quote = message.quoteInfo,
                  !quote.msgID.isEmpty,
                  quote.messagePayload == nil,
                  quote.timestamp > 0
            else { return nil }
            return (index, quote)
        }
        resolveNextQuote(pending: pending, position: 0)
    }

    private func resolveNextQuote(pending: [(Int, MessageQuoteInfo)], position: Int) {
        guard position < pending.count else { return }
        let (index, quote) = pending[position]
        var anchor = MessageInfo()
        anchor.timestamp = quote.timestamp
        var option = MessageLoadOption()
        option.cursor = anchor
        option.direction = .older
        option.pageCount = Self.quoteResolvePageCount
        quoteResolveStore.loadMessages(option: option) { [weak self] result in
            guard let self = self else { return }
            var found: MessageInfo? = nil
            if case .success = result {
                found = self.quoteResolveStore.state.value.messageList.first { $0.msgID == quote.msgID }
            }
            DispatchQueue.main.async {
                self.applyResolvedQuote(found: found, at: index, partialQuote: quote)
                self.resolveNextQuote(pending: pending, position: position + 1)
            }
        }
    }

    private func applyResolvedQuote(found: MessageInfo?, at index: Int, partialQuote: MessageQuoteInfo) {
        guard index < messages.count, var quote = messages[index].quoteInfo, quote.messagePayload == nil else { return }
        if let found = found {
            quote.status = found.status
            quote.sender = found.from
            quote.messageType = found.messageType
            quote.messagePayload = found.messagePayload
        } else {
            quote.status = .deleted
        }
        messages[index].quoteInfo = quote
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    private func isLeft(for message: MessageInfo) -> Bool {
        switch config.alignment {
        case .left: return true
        case .right: return false
        case .twoSided: return !message.isSentBySelf
        }
    }

    private func makeContext(for message: MessageInfo) -> MessageContentContext {
        return MessageContentContext(
            config: config,
            isLeft: isLeft(for: message),
            isSelf: message.isSentBySelf,
            showsReadReceipt: false,
            isGroupChat: true,
            detailTimeText: detailTimeString(for: message),
            messageListStore: messageListStore,
            onMediaTap: { [weak self] tapped in self?.presentImageViewer(for: tapped) },
            onMergedMessageTap: { [weak self] tapped in
                guard tapped.status != .violation else { return }
                self?.openInnerMergedDetail(tapped)
            }
        )
    }

    private func detailTimeString(for message: MessageInfo) -> String? {
        guard let date = Self.date(from: message.timestamp) else { return nil }
        return DateHelper.convertDateToMessageTimeStr(date)
    }

    private func openInnerMergedDetail(_ message: MessageInfo) {
        let detail = MergedMessageDetailViewController(mergedMessage: message, conversationID: conversationID, config: config)
        navigationController?.pushViewController(detail, animated: true)
    }

    private func presentImageViewer(for message: MessageInfo) {

        let mediaMessages = messages.filter { $0.messageType == .image || $0.messageType == .video }
        let provider = ImageViewerDataProvider(mediaMessages: mediaMessages, currentMessage: message)
        provider.loadInitial { [weak self] elements, index in
            guard let self = self else { return }
            let viewer = ImageViewerController(elements: elements, initialIndex: index, provider: provider)
            self.present(viewer, animated: true)
        }
    }

    private func observeMediaDownloadNotifications() {
        let center = NotificationCenter.default
        let progressObserver = center.addObserver(
            forName: Self.mediaDownloadProgressNotificationName, object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleMediaDownloadProgress(notification)
        }
        let finishedObserver = center.addObserver(
            forName: Self.mediaDownloadNotificationName, object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleMediaDownloadFinished(notification)
        }
        mediaObservers = [progressObserver, finishedObserver]
    }

    private func handleMediaDownloadProgress(_ notification: Notification) {
        guard let data = notification.userInfo?["data"],
              let messageID = Self.stringField("messageID", from: data), !messageID.isEmpty,
              let progress = Self.intField("downloadMediaProgress", from: data),
              let index = messages.firstIndex(where: { $0.msgID == messageID }) else { return }
        var message = messages[index]
        guard message.downloadMediaProgress != progress else { return }
        message.downloadMediaProgress = progress
        messages[index] = message
        updateVisibleCellProgress(message, at: index)
    }

    private func handleMediaDownloadFinished(_ notification: Notification) {
        guard let data = notification.userInfo?["data"],
              let messageID = Self.stringField("messageID", from: data), !messageID.isEmpty,
              let payload = Self.payloadField("messagePayload", from: data),
              let index = messages.firstIndex(where: { $0.msgID == messageID }) else { return }
        var message = messages[index]
        message.messagePayload = payload
        message.downloadMediaProgress = Self.downloadProgressComplete
        messages[index] = message
        updateVisibleCellProgress(message, at: index)
    }

    private func updateVisibleCellProgress(_ message: MessageInfo, at index: Int) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MessageBaseCell else { return }
        cell.updateMediaProgressIfNeeded(message)
    }

    private static func stringField(_ label: String, from data: Any) -> String? {
        return Mirror(reflecting: data).children.first(where: { $0.label == label })?.value as? String
    }

    private static func intField(_ label: String, from data: Any) -> Int? {
        return Mirror(reflecting: data).children.first(where: { $0.label == label })?.value as? Int
    }

    private static func payloadField(_ label: String, from data: Any) -> MessagePayload? {
        return Mirror(reflecting: data).children.first(where: { $0.label == label })?.value as? MessagePayload
    }

    private func handleQuotePreviewTap(_ hostMessage: MessageInfo) {
        guard let quoteInfo = hostMessage.quoteInfo else { return }
        guard !isQuotedOriginalUnreachable(quoteInfo),
              let index = indexOfLoadedQuotedMessage(quoteInfo) else {
            showQuoteUnreachableToast()
            return
        }
        if isRowFullyVisible(index) {
            playHighlight(at: index)
        } else {
            scrollAndHighlight(at: index)
        }
    }

    private func isQuotedOriginalUnreachable(_ quoteInfo: MessageQuoteInfo) -> Bool {
        if quoteInfo.status == .revoked { return true }
        if quoteInfo.status == .deleted, quoteInfo.messagePayload == nil { return true }
        return false
    }

    private func indexOfLoadedQuotedMessage(_ quoteInfo: MessageQuoteInfo) -> Int? {
        if !quoteInfo.msgID.isEmpty,
           let index = messages.firstIndex(where: { $0.msgID == quoteInfo.msgID }) {
            return index
        }
        guard quoteInfo.sequence > 0 else { return nil }
        return messages.firstIndex { $0.sequence == quoteInfo.sequence }
    }

    private func showQuoteUnreachableToast() {
        WindowToastManager.shared.show(
            LocalizedChatString("ReplyMessageNotFoundOriginMessage"),
            type: .info,
            duration: Self.quoteToastDuration
        )
    }

    private func isRowFullyVisible(_ index: Int) -> Bool {
        let indexPath = IndexPath(row: index, section: 0)
        guard let visible = tableView.indexPathsForVisibleRows, visible.contains(indexPath) else { return false }
        let rect = tableView.rectForRow(at: indexPath)
        let viewport = CGRect(x: 0, y: tableView.contentOffset.y,
                              width: tableView.bounds.width, height: tableView.bounds.height)
        return viewport.contains(rect)
    }

    private func scrollAndHighlight(at index: Int) {
        guard index >= 0, index < messages.count else { return }
        pendingHighlightIndex = index
        let indexPath = IndexPath(row: index, section: 0)
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.highlightFallbackDelay) { [weak self] in
            self?.playPendingHighlightIfNeeded(at: index)
        }
    }

    private func playPendingHighlightIfNeeded(at index: Int) {
        guard pendingHighlightIndex == index else { return }
        pendingHighlightIndex = nil
        playHighlight(at: index)
    }

    private func playHighlight(at index: Int) {
        guard index >= 0, index < messages.count,
              let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MessageBaseCell else { return }
        cell.playHighlightAnimation()
    }

    private static func date(from timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

// MARK: - UITableViewDataSource

extension MergedMessageDetailViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let kind = MessageCellRegistry.shared.renderKind(for: message)
        switch kind {
        case .systemTip, .revoked:
            return centeredTextCell(for: message, kind: kind, timeString: nil, at: indexPath)
        case .bubble(let contentKind):
            return bubbleCell(for: message, contentKind: contentKind, timeString: nil, at: indexPath)
        case .custom:
            return bubbleCell(for: message, contentKind: .unsupported, timeString: nil, at: indexPath)
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
        let text = MessageCellRegistry.shared.centeredText(for: message, kind: kind, config: config)
        cell.configure(text: text, timeString: timeString, showTime: config.isShowTimeMessage)
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
            isMultiSelectMode: false,
            isSelected: false,
            auxiliaryTextState: .hidden
        )
        cell.onQuotePreviewTap = { [weak self] host in
            self?.handleQuotePreviewTap(host)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MergedMessageDetailViewController: UITableViewDelegate {

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard let index = pendingHighlightIndex else { return }
        playPendingHighlightIfNeeded(at: index)
    }
}

// MARK: - Completion Handler

private final class MergedDetailCompletionHandler: MergedMessageListCompletionHandler {
    private let onSuccessHandler: ([MessageInfo]) -> Void

    private let onFailureHandler: (Int, String) -> Void

    init(onSuccess: @escaping ([MessageInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessHandler = onSuccess
        self.onFailureHandler = onFailure
    }

    func onSuccess(messageList: [MessageInfo]) {
        onSuccessHandler(messageList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureHandler(code, desc)
    }
}
