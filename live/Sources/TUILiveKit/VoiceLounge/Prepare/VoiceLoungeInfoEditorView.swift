import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeInfoEditorView: UIView {
    var onRoomNameChanged: ((String) -> Void)?
    var onSelectTopic: (() -> Void)?
    var onChangeCover: (() -> Void)?

    private static let roomNameByteLimit = 100
    private let coverButton = UIControl()
    private let coverClipView = UIView()
    private let coverImageView = UIImageView()
    private let coverHintLabel = UILabel()
    private let copyView = UIView()
    private let roomNameInput = LiveTextInputView(
        limit: VoiceLoungeInfoEditorView.roomNameByteLimit, unit: .utf8Bytes, maximumLines: 2,
        minimumHeight: InfoEditorStyle.nameLineHeight)
    private let editButton = UIControl()
    private let editIconView = UIImageView()
    private let underlineView = UIView()
    private let topicButton = UIControl()
    private let topicIconView = UIImageView()
    private let topicLabel = UILabel()
    private let topicArrowView = UIImageView()

    private var representedCoverURL = ""
    private var isCoverLoading = false
    private var isBindingRoomName = false

    var roomName: String { roomNameInput.text ?? "" }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { Task { @MainActor [coverImageView] in coverImageView.kf.cancelDownloadTask() } }

    func bind(_ input: VoiceLoungeConfig, hostName: String) {
        if !roomNameInput.isFirstResponder {
            let name = input.roomName.isEmpty ? VoiceLoungeConfig.defaultRoomName(hostName: hostName) : input.roomName
            isBindingRoomName = true
            roomNameInput.setContent(name)
            isBindingRoomName = false
        }
        loadCover(input.coverURL)
        bindTopic(input.topic)
    }

    func endRoomNameEditing() { roomNameInput.resignFirstResponder() }

    func setRoomName(_ name: String) {
        endRoomNameEditing()
        isBindingRoomName = true
        roomNameInput.setContent(name)
        isBindingRoomName = false
    }

    private func setupViews() {
        coverClipView.addSubview(coverImageView)
        coverClipView.addSubview(coverHintLabel)
        coverButton.addSubview(coverClipView)
        addSubview(coverButton)

        editButton.addSubview(editIconView)
        topicButton.addSubview(topicIconView)
        topicButton.addSubview(topicLabel)
        topicButton.addSubview(topicArrowView)
        copyView.addSubview(roomNameInput)
        copyView.addSubview(editButton)
        copyView.addSubview(underlineView)
        copyView.addSubview(topicButton)
        addSubview(copyView)
    }

    private func setupConstraints() {
        coverButton.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.size.equalTo(InfoEditorStyle.coverSize)
            make.bottom.lessThanOrEqualToSuperview()
            make.bottom.equalToSuperview().priority(.low)
        }
        coverClipView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        coverImageView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        coverHintLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(20)
        }
        copyView.snp.makeConstraints { make in
            make.leading.equalTo(coverButton.snp.trailing).offset(14)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(2)
            make.bottom.lessThanOrEqualToSuperview()
            make.bottom.equalToSuperview().priority(.low)
        }
        roomNameInput.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.leading.equalToSuperview()
            make.trailing.equalTo(editButton.snp.leading)
        }
        editButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalTo(roomNameInput)
            make.width.equalTo(InfoEditorStyle.editIconSize + 8)
            make.height.equalTo(InfoEditorStyle.nameLineHeight)
        }
        editIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(InfoEditorStyle.editIconSize)
        }
        underlineView.snp.makeConstraints { make in
            make.top.equalTo(roomNameInput.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        topicButton.snp.makeConstraints { make in
            make.top.equalTo(underlineView.snp.bottom).offset(8)
            make.leading.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.height.equalTo(28)
        }
        topicIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(17)
        }
        topicLabel.snp.makeConstraints { make in
            make.leading.equalTo(topicIconView.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(InfoEditorStyle.topicLabelMaxWidth)
        }
        topicArrowView.snp.makeConstraints { make in
            make.leading.equalTo(topicLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(13)
        }
    }

    private func setupStyles() {
        coverButton.layer.shadowColor = UIColor.black.cgColor
        coverButton.layer.shadowOpacity = 0.4
        coverButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        coverButton.layer.shadowRadius = 9
        coverButton.accessibilityLabel = .changeCover

        coverClipView.backgroundColor = InfoEditorStyle.coverBackground
        coverClipView.layer.cornerRadius = 12
        coverClipView.layer.borderWidth = 1
        coverClipView.layer.borderColor = InfoEditorStyle.coverBorder.cgColor
        coverClipView.clipsToBounds = true
        coverClipView.isUserInteractionEnabled = false

        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true

        coverHintLabel.attributedText = NSAttributedString(
            string: .changeCover, attributes: [.kern: 0.5, .font: InfoEditorStyle.coverHintFont])
        coverHintLabel.textColor = .white
        coverHintLabel.textAlignment = .center
        coverHintLabel.backgroundColor = InfoEditorStyle.coverHintBackground
        coverHintLabel.adjustsFontSizeToFitWidth = true
        coverHintLabel.minimumScaleFactor = 0.7

        roomNameInput.textColor = .white
        roomNameInput.font = InfoEditorStyle.nameFont
        roomNameInput.textAlignment = .left
        roomNameInput.returnKeyType = .done
        roomNameInput.tintColor = .white

        editIconView.image = LiveKitResources.image(named: "livekit_voiceprepare_edit")?.withRenderingMode(
            .alwaysTemplate)
        editIconView.tintColor = InfoEditorStyle.editTint
        editIconView.contentMode = .scaleAspectFit
        editButton.accessibilityLabel = .roomNameEdit

        underlineView.backgroundColor = InfoEditorStyle.underline
        underlineView.isUserInteractionEnabled = false

        topicButton.backgroundColor = InfoEditorStyle.topicBackground
        topicButton.layer.cornerRadius = 14
        topicButton.layer.borderWidth = 1
        topicButton.layer.borderColor = InfoEditorStyle.topicBorder.cgColor

        [topicIconView, topicArrowView].forEach { iconView in
            iconView.contentMode = .scaleAspectFit
            iconView.tintColor = InfoEditorStyle.topicText
            iconView.isUserInteractionEnabled = false
        }
        topicIconView.image = LiveKitResources.image(named: "livekit_voiceprepare_topic")?.withRenderingMode(
            .alwaysTemplate)
        topicArrowView.image = LiveKitResources.image(named: "livekit_voiceprepare_arrow")?.withRenderingMode(
            .alwaysTemplate)

        topicLabel.font = InfoEditorStyle.topicFont
        topicLabel.textColor = InfoEditorStyle.topicText
        topicLabel.numberOfLines = 1
        topicLabel.lineBreakMode = .byTruncatingTail
        topicLabel.isUserInteractionEnabled = false

        bindTopic("")
    }

    private func setupBindings() {
        coverButton.addTarget(self, action: #selector(changeCover), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editRoomName), for: .touchUpInside)
        topicButton.addTarget(self, action: #selector(selectTopic), for: .touchUpInside)
        roomNameInput.onSubmit = { [weak self] in self?.roomNameInput.resignFirstResponder() }
        roomNameInput.onTextChanged = { [weak self] in
            guard let self, !isBindingRoomName else { return }
            onRoomNameChanged?(roomName)
        }
        roomNameInput.onLimitExceeded = { [weak self] in
            guard let self, window != nil else { return }
            LiveToast.show(.roomNameByteLimit(Self.roomNameByteLimit))
        }
    }

    private func bindTopic(_ topic: String) {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        topicLabel.text = trimmed.isEmpty ? .topicPlaceholder : .topicPicked(trimmed)
        topicButton.accessibilityLabel = topicLabel.text
    }

    private func loadCover(_ coverURL: String) {
        if representedCoverURL == coverURL, isCoverLoading || coverImageView.image != nil { return }
        representedCoverURL = coverURL
        coverImageView.kf.cancelDownloadTask()
        isCoverLoading = true
        coverImageView.kf.setImage(with: URL(string: coverURL), placeholder: coverImageView.image) {
            [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            guard let self, representedCoverURL == coverURL else { return }
            isCoverLoading = false
        }
    }
}

extension VoiceLoungeInfoEditorView {
    @objc private func changeCover() { onChangeCover?() }

    @objc private func editRoomName() { roomNameInput.becomeFirstResponder() }

    @objc private func selectTopic() { onSelectTopic?() }
}

private enum InfoEditorStyle {
    static let coverSize: CGFloat = 68
    static let coverBackground = UIColor(red: 0.165, green: 0.184, blue: 0.271, alpha: 1)
    static let coverBorder = UIColor.white.withAlphaComponent(0.16)
    static let coverHintBackground = UIColor.black.withAlphaComponent(0.55)
    static let coverHintFont = UIFont.systemFont(ofSize: VoiceLoungeFont.size(10), weight: .semibold)
    static let nameFont = UIFont.systemFont(ofSize: VoiceLoungeFont.size(18), weight: .semibold)
    static let nameLineHeight: CGFloat = ceil(nameFont.lineHeight)
    static let editIconSize: CGFloat = 15
    static let editTint = UIColor.white.withAlphaComponent(0.7)
    static let underline = UIColor.white.withAlphaComponent(0.22)
    static let topicBackground = UIColor.white.withAlphaComponent(0.06)
    static let topicBorder = UIColor.white.withAlphaComponent(0.18)
    static let topicText = UIColor.white.withAlphaComponent(0.78)
    static let topicFont = UIFont.systemFont(ofSize: VoiceLoungeFont.size(12), weight: .medium)
    static let topicLabelMaxWidth: CGFloat = 160
}

private extension String {
    static var changeCover: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.change_cover") }
    static var roomNameEdit: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.room_name_edit") }
    static func roomNameByteLimit(_ limit: Int) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.prepare.room_name_byte_limit", limit)
    }
    static func topicPicked(_ topic: String) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.prepare.topic_picked", topic)
    }
    static var topicPlaceholder: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.topic_placeholder")
    }
}
