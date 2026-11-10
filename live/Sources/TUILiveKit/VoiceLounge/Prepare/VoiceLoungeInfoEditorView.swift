import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeInfoEditorView: UIView {
    var onRoomNameChanged: ((String) -> Void)?
    var onSelectTopic: (() -> Void)?

    private let avatarView = VoiceLoungeAvatarView()
    private static let roomNameByteLimit = 100
    private let roomNameInput = LiveTextInputView(
        limit: VoiceLoungeInfoEditorView.roomNameByteLimit, unit: .utf8Bytes, maximumLines: 2, minimumHeight: 27)
    private let roomNameContainer = UIView()
    private let topicButton = UIControl()
    private let topicIconView = UIImageView()
    private let topicLabel = LiveText.voiceLounge(.itemTitle, tone: .secondary)
    private let topicChevron = UIImageView()

    private var representedAvatarURL = ""
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

    deinit { Task { @MainActor [avatarView] in avatarView.cancelImageLoading() } }

    func bind(_ input: VoiceLoungeConfig, hostName: String, avatarURL: String) {
        if !roomNameInput.isFirstResponder {
            let name = input.roomName.isEmpty ? VoiceLoungeConfig.defaultRoomName(hostName: hostName) : input.roomName
            isBindingRoomName = true
            roomNameInput.setContent(name)
            isBindingRoomName = false
        }
        loadAvatar(avatarURL)
        bindTopic(input.topic)
    }

    func endRoomNameEditing() { roomNameInput.resignFirstResponder() }

    private func setupViews() {
        addSubview(avatarView)
        roomNameContainer.addSubview(roomNameInput)
        addSubview(roomNameContainer)
        topicButton.addSubview(topicIconView)
        topicButton.addSubview(topicLabel)
        topicButton.addSubview(topicChevron)
        addSubview(topicButton)
    }

    private func setupConstraints() {
        avatarView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(VoiceLoungeInfoEditorStyle.avatarSize)
        }
        roomNameContainer.snp.makeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalTo(334)
            make.height.greaterThanOrEqualTo(39)
        }
        roomNameInput.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.top.bottom.equalToSuperview().inset(6)
        }
        topicButton.snp.makeConstraints { make in
            make.top.equalTo(roomNameContainer.snp.bottom).offset(33)
            make.centerX.equalToSuperview()
            make.width.equalTo(262)
            make.height.equalTo(40)
            make.bottom.equalToSuperview()
        }
        topicIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
            make.size.equalTo(17)
        }
        topicChevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(15)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 6, height: 11))
        }
        topicLabel.snp.makeConstraints { make in
            make.leading.equalTo(topicIconView.snp.trailing).offset(8)
            make.trailing.equalTo(topicChevron.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    private func setupStyles() {
        roomNameContainer.backgroundColor = VoiceLoungeInfoEditorStyle.roomNameBackground
        roomNameContainer.layer.cornerRadius = 10
        roomNameContainer.layer.borderWidth = 1
        roomNameContainer.layer.borderColor = VoiceLoungeInfoEditorStyle.roomNameBorder.cgColor

        roomNameInput.textColor = VoiceLoungeInfoEditorStyle.roomNameText
        roomNameInput.font = VoiceLoungeInfoEditorStyle.roomNameFont
        roomNameInput.textAlignment = .center
        roomNameInput.returnKeyType = .done

        topicButton.backgroundColor = VoiceLoungeInfoEditorStyle.topicBackground
        topicButton.layer.cornerRadius = 12
        topicButton.layer.borderWidth = 1
        topicButton.layer.borderColor = VoiceLoungeInfoEditorStyle.topicBorder.cgColor

        topicIconView.image = LiveKitResources.image(named: "livekit_voiceprepare_topic")
        topicIconView.contentMode = .scaleAspectFit
        topicIconView.isUserInteractionEnabled = false

        topicLabel.numberOfLines = 1
        topicLabel.lineBreakMode = .byTruncatingTail
        topicLabel.isUserInteractionEnabled = false

        topicChevron.image = LiveKitResources.image(named: "livekit_living_status_chevron")?.withRenderingMode(
            .alwaysTemplate)
        topicChevron.contentMode = .scaleAspectFit
        topicChevron.tintColor = LiveTheme.Color.text(.tertiary)
        topicChevron.isUserInteractionEnabled = false

        bindTopic("")
    }

    private func setupBindings() {
        roomNameInput.onSubmit = { [weak self] in self?.roomNameInput.resignFirstResponder() }
        roomNameInput.onTextChanged = { [weak self] in
            guard let self, !isBindingRoomName else { return }
            onRoomNameChanged?(roomName)
        }
        roomNameInput.onLimitExceeded = { [weak self] in
            guard let self, window != nil else { return }
            LiveToast.show(.roomNameByteLimit(Self.roomNameByteLimit))
        }
        topicButton.addTarget(self, action: #selector(selectTopic), for: .touchUpInside)
    }

    private func bindTopic(_ topic: String) {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            topicLabel.text = .topicPlaceholder
            topicLabel.tone = .tertiary
        } else {
            topicLabel.text = .topicPicked(trimmed)
            topicLabel.tone = .secondary
        }
        topicButton.accessibilityLabel = topicLabel.text
    }

    private func loadAvatar(_ avatarURL: String) {
        guard representedAvatarURL != avatarURL else { return }
        representedAvatarURL = avatarURL
        avatarView.setAvatar(url: avatarURL)
    }
}

extension VoiceLoungeInfoEditorView { @objc private func selectTopic() { onSelectTopic?() } }

private final class VoiceLoungeAvatarView: UIView {
    private let shadowLayer = CALayer()
    private let glowLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowOpacity = 0.45
        shadowLayer.shadowOffset = CGSize(width: 0, height: 10)
        shadowLayer.shadowRadius = 14
        layer.addSublayer(shadowLayer)

        glowLayer.shadowColor = VoiceLoungeColor.prepareLight.cgColor
        glowLayer.shadowOpacity = 0.28
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 15
        layer.addSublayer(glowLayer)

        gradientLayer.colors = [
            VoiceLoungeInfoEditorStyle.avatarGradientTop.cgColor,
            VoiceLoungeInfoEditorStyle.avatarGradientBottom.cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.27)
        gradientLayer.endPoint = CGPoint(x: 0.73, y: 1)
        layer.addSublayer(gradientLayer)

        layer.borderWidth = 2
        layer.borderColor = VoiceLoungeInfoEditorStyle.avatarBorder.cgColor

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setAvatar(url: String) {
        let placeholder = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        imageView.kf.cancelDownloadTask()
        guard let avatarURL = URL(string: url), !url.isEmpty else {
            imageView.image = placeholder
            return
        }
        imageView.kf.setImage(with: avatarURL, placeholder: imageView.image ?? placeholder)
    }

    func cancelImageLoading() { imageView.kf.cancelDownloadTask() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.height / 2
        layer.cornerRadius = radius
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = radius

        let circle = UIBezierPath(ovalIn: bounds).cgPath
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = circle
        glowLayer.frame = bounds
        glowLayer.shadowPath = circle

        let inset = bounds.insetBy(dx: 2, dy: 2)
        imageView.frame = inset
        imageView.layer.cornerRadius = inset.height / 2
    }
}

private enum VoiceLoungeInfoEditorStyle {
    static let avatarSize: CGFloat = 96
    static let avatarBorder = VoiceLoungeColor.prepareMid.withAlphaComponent(0.55)
    static let avatarGradientTop = UIColor(red: 0.118, green: 0.125, blue: 0.161, alpha: 1)
    static let avatarGradientBottom = UIColor(red: 0.051, green: 0.055, blue: 0.078, alpha: 1)
    static let roomNameBackground = UIColor.white.withAlphaComponent(0.059)
    static let roomNameBorder = UIColor(white: 0.463, alpha: 1)
    static let roomNameText = UIColor.white.withAlphaComponent(0.45)
    static let roomNameFont = UIFont.systemFont(ofSize: 21, weight: .semibold)
    static let topicBackground = UIColor.white.withAlphaComponent(0.02)
    static let topicBorder = UIColor.white.withAlphaComponent(0.078)
}

private extension String {
    static func roomNameByteLimit(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.prepare.room_name_byte_limit", args)
    }
    static func topicPicked(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.prepare.topic_picked", args)
    }
    static var topicPlaceholder: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.topic_placeholder")
    }
}
