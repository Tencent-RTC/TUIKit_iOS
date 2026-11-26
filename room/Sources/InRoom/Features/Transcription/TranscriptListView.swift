import UIKit
import SnapKit
import Combine
import AtomicXCore

final class TranscriptListView: UIView {

    private let roomID: String
    private let searchField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIView()
    private let emptyLabel = UILabel()
    private let jumpButton = UIButton(type: .custom)
    private var storeCancellables = Set<AnyCancellable>()
    private var messages: [TranscriberMessage] = []
    private var displayedMessages: [TranscriberMessage] = []
    private var searchWords = ""

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        subscribe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        storeCancellables.removeAll()
    }

    private func setupViews() {
        let titleLabel = UILabel()
        titleLabel.text = RoomKitResources.localizedString("roomkit_caption_entry")
        titleLabel.textColor = .roomKitFgPrimary
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        let header = UIStackView(arrangedSubviews: [titleLabel])
        header.layoutMargins = UIEdgeInsets(top: 4, left: 16, bottom: 12, right: 16)
        header.isLayoutMarginsRelativeArrangement = true

        let searchIcon = UIImageView(
            frame: CGRect(x: 12, y: 9, width: 14, height: 14)
        )
        searchIcon.image = RoomKitResources.image(named:"roomkit_icon_search")?.withRenderingMode(.alwaysTemplate)
        searchIcon.tintColor = .roomKitFgTertiary
        searchIcon.contentMode = .scaleAspectFit
        let searchIconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        searchIconContainer.isUserInteractionEnabled = false
        searchIconContainer.addSubview(searchIcon)
        searchField.leftView = searchIconContainer
        searchField.leftViewMode = .always
        let copyButton = makeToolbarButton("roomkit_icon_copy", action: #selector(copyTranscript))
        let settingsButton = makeToolbarButton("roomkit_icon_settings", action: #selector(openSettings))
        let toolbar = UIStackView(arrangedSubviews: [searchField, copyButton, settingsButton])
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 4
        toolbar.setCustomSpacing(0, after: copyButton)
        toolbar.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 10)
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.snp.makeConstraints { $0.height.equalTo(44) }
        searchField.snp.makeConstraints { $0.height.equalTo(32) }
        copyButton.snp.makeConstraints { $0.size.equalTo(32) }
        settingsButton.snp.makeConstraints { $0.size.equalTo(32) }

        let emptyImage = UIImageView(image: RoomKitResources.image(named:"roomkit_icon_caption")?.withRenderingMode(.alwaysTemplate))
        emptyImage.tintColor = .roomKitFgTertiary
        emptyImage.contentMode = .scaleAspectFit
        emptyImage.alpha = 0.5
        emptyLabel.text = RoomKitResources.localizedString("roomkit_transcription_empty_hint")
        emptyLabel.textColor = .roomKitFgTertiary
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        let emptyStack = UIStackView(arrangedSubviews: [emptyImage, emptyLabel])
        emptyStack.axis = .vertical
        emptyStack.spacing = 8
        emptyStack.alignment = .center
        emptyView.addSubview(emptyStack)
        emptyStack.snp.makeConstraints { $0.center.equalToSuperview() }
        emptyImage.snp.makeConstraints { $0.size.equalTo(26) }

        tableView.register(TranscriptCell.self, forCellReuseIdentifier: "TranscriptCell")
        jumpButton.setImage(RoomKitResources.image(named:"roomkit_icon_arrow_down")?.withRenderingMode(.alwaysTemplate), for: .normal)
        jumpButton.tintColor = .roomKitAccent

        let root = UIStackView(arrangedSubviews: [header, toolbar, tableView])
        root.axis = .vertical
        addSubview(root)
        addSubview(emptyView)
        addSubview(jumpButton)
        root.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupConstraints() {
        emptyView.snp.makeConstraints {
            $0.edges.equalTo(tableView)
        }
        jumpButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-10)
            $0.bottom.equalToSuperview().offset(-10)
            $0.size.equalTo(48)
        }
    }

    private func setupStyles() {
        backgroundColor = .roomKitBgSurface
        searchField.font = .systemFont(ofSize: 13)
        searchField.textColor = .roomKitFgPrimary
        searchField.attributedPlaceholder = NSAttributedString(
            string: RoomKitResources.localizedString("roomkit_caption_search_native"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.roomKitFgTertiary,
            ]
        )
        searchField.backgroundColor = .roomKitBgSurface
        searchField.layer.cornerRadius = 16
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = UIColor.roomKitBorder.cgColor
        searchField.tintColor = .roomKitAccent
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 4, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.keyboardDismissMode = .onDrag
        jumpButton.backgroundColor = .roomKitAccentSoft
        jumpButton.layer.cornerRadius = 24
        emptyView.backgroundColor = .roomKitBgSurface
        emptyView.isHidden = true
        jumpButton.isHidden = true
    }

    private func setupBindings() {
        tableView.dataSource = self
        tableView.delegate = self
        searchField.addTarget(self, action: #selector(updateSearch), for: .editingChanged)
        jumpButton.addTarget(self, action: #selector(scrollToLatest), for: .touchUpInside)
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard)),
        ]
        searchField.inputAccessoryView = toolbar
    }

    private func subscribe() {
        AITranscriberStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(keyPath: \TranscriberState.realtimeMessageList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.updateMessages(messages)
            }
            .store(in: &storeCancellables)
    }

    private func makeToolbarButton(_ icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(RoomKitResources.image(named:icon)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.imageView?.snp.makeConstraints { $0.size.equalTo(16) }
        button.tintColor = .roomKitFgSecondary
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateMessages(_ messages: [TranscriberMessage]) {
        self.messages = messages
        updateData()
    }

    private func updateData(scrollToTop: Bool = false) {
        let nextMessages = messages.filter { matches($0) }
        let hasSameStructure = nextMessages.map(\.segmentId) == displayedMessages.map(\.segmentId)
        displayedMessages = nextMessages
        let isAtBottom = tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.height - 1
        let isEmpty = displayedMessages.isEmpty
        emptyView.isHidden = !isEmpty
        emptyLabel.text = RoomKitResources.localizedString(
            searchWords.isEmpty ? "roomkit_transcription_empty_hint" : "roomkit_transcription_no_match"
        )
        jumpButton.isHidden = displayedMessages.isEmpty || searchWords.isEmpty
        if hasSameStructure {
            updateVisibleCells()
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        } else {
            tableView.reloadData()
        }
        if scrollToTop, !searchWords.isEmpty, !displayedMessages.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        } else if isAtBottom, searchWords.isEmpty, !displayedMessages.isEmpty {
            tableView.layoutIfNeeded()
            scrollToLatest()
        }
    }

    private func updateVisibleCells() {
        for case let cell as TranscriptCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell), indexPath.row < displayedMessages.count else { continue }
            cell.bind(message: displayedMessages[indexPath.row], highlighted: highlighted)
        }
    }

    private func matches(_ message: TranscriberMessage) -> Bool {
        guard !searchWords.isEmpty else { return true }
        let name = message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName
        let translation = message.translationTexts.values.first ?? ""
        return name.range(of: searchWords, options: .caseInsensitive) != nil
            || message.sourceText.range(of: searchWords, options: .caseInsensitive) != nil
            || translation.range(of: searchWords, options: .caseInsensitive) != nil
    }

    private func highlighted(_ text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        guard !searchWords.isEmpty, !text.isEmpty else { return attributed }
        let pattern = NSRegularExpression.escapedPattern(for: searchWords)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return attributed }
        let range = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match else { return }
            attributed.addAttribute(.backgroundColor, value: UIColor.roomKitAccentBorder, range: match.range)
        }
        return attributed
    }

    @objc private func updateSearch() {
        searchWords = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateData(scrollToTop: true)
    }

    @objc private func copyTranscript() {
        let text = displayedMessages.map { message in
            let name = message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName
            let translation = message.translationTexts.values.first ?? ""
            return "\(captionTime(message.timestamp)) \(name)\n\(message.sourceText)" + (translation.isEmpty ? "" : "\n\(translation)")
        }.joined(separator: "\n\n")
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        RoomToast.show(RoomKitResources.localizedString("roomkit_caption_copied"))
    }

    @objc private func openSettings() {
        let content = TranscriptSettingsView(roomID: roomID)
        let popup = RoomPopup()
        popup.onDismiss = { [weak popup] _ in
            popup?.removeFromSuperview()
        }
        popup.contentView.addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(UIScreen.main.bounds.height * 0.60)
        }
        popup.show(in: self)
    }

    @objc private func scrollToLatest() {
        guard !displayedMessages.isEmpty else { return }
        tableView.scrollToRow(at: IndexPath(row: displayedMessages.count - 1, section: 0), at: .bottom, animated: true)
    }

    @objc private func dismissKeyboard() {
        searchField.resignFirstResponder()
    }

}

extension TranscriptListView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedMessages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TranscriptCell", for: indexPath) as! TranscriptCell
        let message = displayedMessages[indexPath.row]
        cell.bind(message: message, highlighted: highlighted)
        return cell
    }
}

private final class TranscriptCell: UITableViewCell {

    private let avatar = RoomAvatar()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let headerStack = UIStackView()
    private let rowStack = UIStackView()
    private let bubbleView = UIView()
    private let sourceLabel = TypewriterLabel()
    private let sourceLoading = RoomLoadingDotsView()
    private let translationLabel = TypewriterLabel()
    private let translationLoading = RoomLoadingDotsView()
    private let translationStack = UIStackView()
    private let translationDivider = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(
        message: TranscriberMessage,
        highlighted: @escaping (String) -> NSAttributedString
    ) {
        avatar.text = message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName
        nameLabel.text = avatar.text
        timeLabel.text = captionTime(message.timestamp)
        sourceLabel.formatText = highlighted
        translationLabel.formatText = highlighted
        let isTranscribing = !message.isCompleted
        sourceLabel.updateText(contentId: message.segmentId, text: message.sourceText, isStreaming: isTranscribing)
        sourceLoading.isHidden = !isTranscribing
        let translation = message.translationTexts.values.first ?? ""
        let showTranslation = !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        translationDivider.isHidden = !showTranslation
        translationStack.isHidden = !showTranslation
        translationLabel.updateText(
            contentId: message.segmentId,
            text: translation,
            isStreaming: showTranslation && isTranscribing
        )
        translationLoading.isHidden = !showTranslation || !isTranscribing
    }

    private func setupViews() {
        headerStack.addArrangedSubview(nameLabel)
        headerStack.addArrangedSubview(timeLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .center

        let sourceSpacer = UIView()
        sourceSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sourceSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let sourceStack = UIStackView(arrangedSubviews: [sourceLabel, sourceLoading, sourceSpacer])
        sourceStack.axis = .horizontal
        sourceStack.alignment = .bottom
        sourceStack.spacing = 4
        sourceLoading.snp.makeConstraints { $0.height.equalTo(15) }
        let translationSpacer = UIView()
        translationSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        translationSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        translationStack.addArrangedSubview(translationLabel)
        translationStack.addArrangedSubview(translationLoading)
        translationStack.addArrangedSubview(translationSpacer)
        translationStack.axis = .horizontal
        translationStack.alignment = .bottom
        translationStack.spacing = 4
        translationLoading.snp.makeConstraints { $0.height.equalTo(13) }
        translationDivider.backgroundColor = .roomKitBorder
        translationDivider.snp.makeConstraints { $0.height.equalTo(1) }
        let contentStack = UIStackView(arrangedSubviews: [sourceStack, translationDivider, translationStack])
        contentStack.axis = .vertical
        contentStack.spacing = 10
        bubbleView.addSubview(contentStack)
        contentStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)) }

        rowStack.axis = .vertical
        rowStack.spacing = 4
        rowStack.addArrangedSubview(headerStack)
        rowStack.addArrangedSubview(bubbleView)
        headerStack.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        headerStack.isLayoutMarginsRelativeArrangement = true
        contentView.addSubview(avatar)
        contentView.addSubview(rowStack)
    }

    private func setupConstraints() {
        avatar.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview()
            $0.size.equalTo(32)
        }
        headerStack.snp.makeConstraints { $0.height.equalTo(20) }
        rowStack.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(56)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalToSuperview().offset(-10)
            $0.top.equalToSuperview()
        }
    }

    private func setupStyles() {
        selectionStyle = .none
        backgroundColor = .clear
        nameLabel.textColor = .roomKitFgSecondary
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = .roomKitFgTertiary
        timeLabel.font = .systemFont(ofSize: 12)
        sourceLabel.font = .systemFont(ofSize: 15)
        sourceLabel.textColor = .roomKitFgPrimary
        sourceLabel.numberOfLines = 0
        translationLabel.font = .systemFont(ofSize: 13)
        translationLabel.textColor = .roomKitFgSecondary
        translationLabel.numberOfLines = 0
        bubbleView.backgroundColor = .roomKitBgHover
        bubbleView.layer.cornerRadius = 12
        sourceLoading.dotColor = .roomKitFgTertiary
        translationLoading.dotColor = .roomKitFgTertiary
    }
}

private func captionTime(_ timestamp: Int64) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000))
}
