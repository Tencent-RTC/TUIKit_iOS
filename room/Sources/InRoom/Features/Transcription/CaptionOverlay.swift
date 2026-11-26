import UIKit
import SnapKit
import Combine
import AtomicXCore

private final class CaptionRowView: UIView {

    private(set) var speakerUserId: String?
    private(set) var segmentId: String?

    private let onTimeout: (CaptionRowView) -> Void
    private var boundMessage: TranscriberMessage?
    private var prefixText = ""
    private var fullText = ""
    private var hideWorkItem: DispatchWorkItem?
    private let avatar = RoomAvatar()
    private let nameLabel = UILabel()
    private let loading = RoomLoadingDotsView()
    private let sourceLabel = TypewriterLabel()
    private let translationLabel = TypewriterLabel()

    init(onTimeout: @escaping (CaptionRowView) -> Void) {
        self.onTimeout = onTimeout
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(message: TranscriberMessage) {
        if isBound(message) { return }
        hideWorkItem?.cancel()
        let userId = message.speakerUserId
        if speakerUserId == nil {
            speakerUserId = userId
            segmentId = message.segmentId
        } else if segmentId != message.segmentId {
            prefixText = fullText
            segmentId = message.segmentId
        }
        fullText = prefixText + message.sourceText
        let speakerName = message.speakerUserName.isEmpty ? userId : message.speakerUserName
        avatar.text = speakerName
        nameLabel.text = speakerName
        let isTranscribing = !message.isCompleted
        sourceLabel.updateText(contentId: userId, text: fullText, isStreaming: isTranscribing)
        let translatedText = message.translationTexts.values.first ?? ""
        let showTranslation = !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        translationLabel.isHidden = !showTranslation
        translationLabel.updateText(
            contentId: message.segmentId,
            text: translatedText,
            isStreaming: showTranslation && isTranscribing
        )
        loading.isHidden = !isTranscribing
        boundMessage = message
        if message.isCompleted { scheduleTimeout() }
    }

    func stopAnimations() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        sourceLabel.stopAnimations()
        translationLabel.stopAnimations()
        loading.isHidden = true
    }

    private func isBound(_ message: TranscriberMessage) -> Bool {
        guard let boundMessage else { return false }
        return boundMessage.segmentId == message.segmentId
            && boundMessage.speakerUserId == message.speakerUserId
            && boundMessage.speakerUserName == message.speakerUserName
            && boundMessage.sourceText == message.sourceText
            && boundMessage.translationTexts == message.translationTexts
            && boundMessage.timestamp == message.timestamp
            && boundMessage.isCompleted == message.isCompleted
    }

    private func scheduleTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.onTimeout(self)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func setupViews() {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [nameLabel, loading, spacer])
        header.axis = .horizontal
        header.spacing = 6
        header.alignment = .center
        header.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 28)
        header.isLayoutMarginsRelativeArrangement = true
        let content = UIStackView(arrangedSubviews: [header, sourceLabel, translationLabel])
        content.axis = .vertical
        content.spacing = 3
        let row = UIStackView(arrangedSubviews: [avatar, content])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 6
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupConstraints() {
        avatar.snp.makeConstraints { $0.size.equalTo(16) }
        loading.snp.makeConstraints { $0.size.equalTo(CGSize(width: 15, height: 12)) }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        loading.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupStyles() {
        nameLabel.textColor = .roomKitCaptionName
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.textColor = .roomKitFgOnMedia
        sourceLabel.font = .systemFont(ofSize: 16)
        sourceLabel.showCaret = true
        sourceLabel.showLastLineOnly = true
        translationLabel.textColor = .roomKitCaptionTranslation
        translationLabel.font = .systemFont(ofSize: 13)
        translationLabel.numberOfLines = 1
        translationLabel.lineBreakMode = .byTruncatingHead
    }
}

final class CaptionOverlay: UIView {

    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    private let roomID: String
    private let rowStack = UIStackView()
    private var rows: [CaptionRowView] = []
    private let closeButton = UIButton(type: .custom)
    private var storeCancellables = Set<AnyCancellable>()
    private var isTranscriptionRunning = false

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        subscribe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        storeCancellables.removeAll()
        rows.forEach { $0.stopAnimations() }
    }

    private func setupViews() {
        addSubview(rowStack)
        addSubview(closeButton)
        let tap = UITapGestureRecognizer(target: self, action: #selector(openTranscript))
        addGestureRecognizer(tap)
        closeButton.addTarget(self, action: #selector(closeTranscription), for: .touchUpInside)
    }

    private func setupConstraints() {
        rowStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalToSuperview().inset(11)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        closeButton.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-4)
            $0.trailing.equalToSuperview().offset(4)
            $0.size.equalTo(44)
        }
    }

    private func setupStyles() {
        backgroundColor = .roomKitCaptionOverlay
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.roomKitCaptionBorder.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 32
        layer.shadowOffset = .zero
        rowStack.axis = .vertical
        rowStack.spacing = 7
        let closeImage = RoomKitResources.image(named:"roomkit_icon_close")?.withRenderingMode(.alwaysTemplate)
        closeButton.setImage(closeImage, for: .normal)
        closeButton.tintColor = .roomKitFgOnMedia.withAlphaComponent(0.95)
        closeButton.accessibilityLabel = RoomKitResources.localizedString("roomkit_caption_close")
        isHidden = true
    }

    private func subscribe() {
        let state = AITranscriberStore.create(roomID: roomID).state
        state.subscribe(StatePublisherSelector(keyPath: \TranscriberState.realtimeMessageList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.showMessages(messages)
            }
            .store(in: &storeCancellables)
        state.subscribe(StatePublisherSelector(keyPath: \TranscriberState.isTranscriptionRunning))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isTranscriptionRunning = running
                self?.updateVisibility()
            }
            .store(in: &storeCancellables)
    }

    private func showMessages(_ messages: [TranscriberMessage]) {
        var seenUserIds = Set<String>()
        let latestBySpeaker = messages.reversed().filter { seenUserIds.insert($0.speakerUserId).inserted }
        let latestMessages = latestBySpeaker.filter { message in
            !message.isCompleted || rows.contains { $0.segmentId == message.segmentId }
        }.prefix(2).reversed()
        let latestUserIds = Set(latestMessages.map { $0.speakerUserId })
        rows.filter { row in
            guard let speakerUserId = row.speakerUserId else { return true }
            return !latestUserIds.contains(speakerUserId)
        }.forEach { removeRow($0) }
        for message in latestMessages {
            if let boundRow = rows.first(where: { $0.speakerUserId == message.speakerUserId }) {
                boundRow.bind(message: message)
                continue
            }
            let newRow = CaptionRowView { [weak self] row in
                self?.removeRow(row)
            }
            rows.append(newRow)
            rowStack.addArrangedSubview(newRow)
            newRow.bind(message: message)
        }
        updateVisibility()
    }

    private func removeRow(_ row: CaptionRowView) {
        row.stopAnimations()
        rows.removeAll { $0 === row }
        rowStack.removeArrangedSubview(row)
        row.removeFromSuperview()
        updateVisibility()
    }

    private func updateVisibility() {
        isHidden = !isTranscriptionRunning || rows.isEmpty
    }

    @objc private func openTranscript() {
        onOpen?()
    }

    @objc private func closeTranscription() {
        onClose?()
    }
}
