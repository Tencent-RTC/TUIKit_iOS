import UIKit
import Combine
import SnapKit
import AtomicXCore

final class MessageAudioContentView: UIView, MessageContentView {
    private static let horizontalInset = CGFloat(SpacingScheme.iconIconSpacing)

    private static let verticalInset = CGFloat(SpacingScheme.smallSpacing)

    private static let iconSize: CGFloat = 16

    private static let contentSpacing = CGFloat(SpacingScheme.iconTextSpacing)

    private static let maxDurationSeconds: Int = 60

    private static let absoluteMinWidth: CGFloat = 80

    private static let absoluteMaxWidth: CGFloat = 260

    private static let minWidthScreenRatio: CGFloat = 0.22

    private static let maxWidthScreenRatio: CGFloat = 0.55

    private static let dimmedContainerAlpha: CGFloat = 0.85

    private static let durationMaxLines = 1

    private var message: MessageInfo?

    private var isSelf = false

    private weak var messageListStore: MessageListStore?

    private var playingCancellable: AnyCancellable?

    private var currentPlayingMsgID: String?

    private var contentWidthConstraint: Constraint?

    private var contentStackLeading: Constraint?

    private var contentStackTrailing: Constraint?

    private let bubbleView = UIView()

    private let contentStack = UIStackView()

    private let voiceIconView = VoiceIconView()

    private let durationLabel = UILabel()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        subscribePlaybackState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        self.message = message
        self.isSelf = context.isSelf
        self.messageListStore = context.messageListStore

        let duration = Self.audioDuration(from: message)
        durationLabel.text = Self.formatDuration(duration)
        applyColors(isSelf: context.isSelf)
        applyAlignment(isSelf: context.isSelf)
        contentWidthConstraint?.update(offset: Self.computeWidth(duration: duration))
        updatePlaybackVisualState()
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(bubbleView)
        bubbleView.addSubview(contentStack)
        contentStack.addArrangedSubview(voiceIconView)
        contentStack.addArrangedSubview(durationLabel)
    }

    private func activateConstraints() {
        bubbleView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            contentWidthConstraint = make.width.equalTo(Self.absoluteMinWidth).constraint
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(bubbleView).offset(Self.verticalInset)
            make.bottom.equalTo(bubbleView).offset(-Self.verticalInset)
            contentStackLeading = make.leading.equalTo(bubbleView).offset(Self.horizontalInset).constraint
        }
        voiceIconView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.iconSize)
        }
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupViewStyle() {
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = Self.contentSpacing
        durationLabel.font = FontScheme.caption1Regular
        durationLabel.numberOfLines = Self.durationMaxLines
    }

    private func bindInteraction() {
        bubbleView.isUserInteractionEnabled = true
        bubbleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    private func subscribePlaybackState() {
        playingCancellable = ChatAudioPlaybackCoordinator.shared.playingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgID in
                self?.currentPlayingMsgID = msgID
                self?.updatePlaybackVisualState()
            }
    }

    private func applyColors(isSelf: Bool) {
        let colors = TUIChatKitTheme.colors
        let contentColor = isSelf ? colors.textColorAntiPrimary : colors.textColorPrimary
        durationLabel.textColor = contentColor
        voiceIconView.setColor(contentColor)
    }

    private func applyAlignment(isSelf: Bool) {
        contentStackLeading?.deactivate()
        contentStackTrailing?.deactivate()
        if isSelf {
            contentStackTrailing = contentStack.snp.prepareConstraints { make in
                make.trailing.equalTo(bubbleView).offset(-Self.horizontalInset)
            }.first
            contentStackTrailing?.activate()
        } else {
            contentStackLeading = contentStack.snp.prepareConstraints { make in
                make.leading.equalTo(bubbleView).offset(Self.horizontalInset)
            }.first
            contentStackLeading?.activate()
        }
    }

    private func updatePlaybackVisualState() {
        guard let message = message else { return }
        let isCurrent = currentPlayingMsgID == message.msgID
        let isPlaying = isCurrent && ChatAudioPlaybackCoordinator.shared.isPlaying(msgID: message.msgID)
        if isPlaying {
            voiceIconView.startAnimating()
        } else {
            voiceIconView.stopAnimating()
        }
        durationLabel.alpha = isCurrent ? 1.0 : Self.dimmedContainerAlpha
        let someonePlaying = currentPlayingMsgID != nil
        self.alpha = (isCurrent || !someonePlaying) ? 1.0 : Self.dimmedContainerAlpha
    }

    @objc private func handleTap() {
        guard let message = message else { return }
        guard case .audio(let payload) = message.messagePayload else { return }

        if let path = payload.audioPath,
           !path.isEmpty,
           FileManager.default.fileExists(atPath: path) {
            ChatAudioPlaybackCoordinator.shared.toggle(msgID: message.msgID, url: URL(fileURLWithPath: path))
            return
        }
        if let urlString = payload.audioURL,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            ChatAudioPlaybackCoordinator.shared.toggle(msgID: message.msgID, url: url)
            return
        }
        downloadThenPlay(message: message)
    }

    private func downloadThenPlay(message: MessageInfo) {
        MessageActionStore.create(message: message).downloadMedia(quality: nil) { [weak self] result in
            guard case .success = result else { return }
            DispatchQueue.main.async {
                self?.playAfterDownload(msgID: message.msgID)
            }
        }
    }

    private func playAfterDownload(msgID: String) {
        let latest = messageListStore?.state.value.messageList.first { $0.msgID == msgID }
        guard case .audio(let payload)? = latest?.messagePayload else { return }
        if let path = payload.audioPath,
           !path.isEmpty,
           FileManager.default.fileExists(atPath: path) {
            ChatAudioPlaybackCoordinator.shared.toggle(msgID: msgID, url: URL(fileURLWithPath: path))
        } else if let urlString = payload.audioURL,
                  !urlString.isEmpty,
                  let url = URL(string: urlString) {
            ChatAudioPlaybackCoordinator.shared.toggle(msgID: msgID, url: url)
        }
    }

    private static func audioDuration(from message: MessageInfo) -> Int {
        if case .audio(let payload) = message.messagePayload {
            return payload.audioDuration
        }
        return 0
    }

    private static func formatDuration(_ seconds: Int) -> String {
        return String(format: "%d\"", max(seconds, 0))
    }

    private static func computeWidth(duration: Int) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let minWidth = min(max(screenWidth * Self.minWidthScreenRatio, Self.absoluteMinWidth), Self.absoluteMaxWidth)
        let maxWidth = min(max(screenWidth * Self.maxWidthScreenRatio, minWidth), Self.absoluteMaxWidth)
        let clamped = min(max(CGFloat(duration), 1), CGFloat(Self.maxDurationSeconds))
        return minWidth + (maxWidth - minWidth) * (clamped / CGFloat(Self.maxDurationSeconds))
    }
}

private final class VoiceIconView: UIView {
    private let dotLayer = CAShapeLayer()

    private let arcInnerLayer = CAShapeLayer()

    private let arcOuterLayer = CAShapeLayer()

    private var shapeLayers: [CAShapeLayer] { [dotLayer, arcInnerLayer, arcOuterLayer] }

    private let viewportSize: CGFloat = 33.7525

    private let displaySize: CGFloat = 16

    private var scale: CGFloat { displaySize / viewportSize }

    private let dimmedAlpha: CGFloat = 76.0 / 255.0

    private let animationStepInterval: TimeInterval = 0.3

    private var animationTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        transform = isRTL ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }

    func setColor(_ color: UIColor) {
        for layer in shapeLayers {
            layer.fillColor = color.cgColor
        }
    }

    func startAnimating() {
        guard animationTimer == nil else { return }
        var step = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationStepInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for (index, layer) in self.shapeLayers.enumerated() {
                layer.opacity = index == step ? 1.0 : Float(self.dimmedAlpha)
            }
            step = (step + 1) % self.shapeLayers.count
        }
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        for layer in shapeLayers {
            layer.opacity = 1.0
        }
    }

    deinit {
        animationTimer?.invalidate()
    }

    private func setupLayers() {
        for layer in shapeLayers {
            layer.fillColor = UIColor.black.cgColor
            self.layer.addSublayer(layer)
        }
        dotLayer.path = Self.buildDotPath(scale: scale)
        arcInnerLayer.path = Self.buildArcInnerPath(scale: scale)
        arcOuterLayer.path = Self.buildArcOuterPath(scale: scale)
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> CGPoint {
        return CGPoint(x: x * scale, y: y * scale)
    }

    private static func buildDotPath(scale: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: point(10.12625, 17.0747, scale))
        path.addQuadCurve(to: point(9.13775, 14.6976, scale), controlPoint: point(10.12625, 15.6822, scale))
        path.addQuadCurve(to: point(6.75125, 13.7129, scale), controlPoint: point(8.14925, 13.7129, scale))
        path.addQuadCurve(to: point(4.36475, 14.6976, scale), controlPoint: point(5.35325, 13.7129, scale))
        path.addQuadCurve(to: point(3.37625, 17.0747, scale), controlPoint: point(3.37625, 15.6822, scale))
        path.addQuadCurve(to: point(4.36475, 19.4519, scale), controlPoint: point(3.37625, 18.4672, scale))
        path.addQuadCurve(to: point(6.75125, 20.4365, scale), controlPoint: point(5.35325, 20.4365, scale))
        path.addQuadCurve(to: point(9.13775, 19.4519, scale), controlPoint: point(8.14925, 20.4365, scale))
        path.addQuadCurve(to: point(10.12625, 17.0747, scale), controlPoint: point(10.12625, 18.4672, scale))
        path.close()
        return path.cgPath
    }

    private static func buildArcInnerPath(scale: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: point(20.25125, 17.0745, scale))
        path.addCurve(to: point(16.05425, 7.3301, scale),
                      controlPoint1: point(20.25125, 13.2397, scale),
                      controlPoint2: point(18.63975, 9.7797, scale))
        path.addLine(to: point(13.73595, 9.7733, scale))
        path.addCurve(to: point(16.87625, 17.0745, scale),
                      controlPoint1: point(15.67065, 11.6102, scale),
                      controlPoint2: point(16.87625, 14.2021, scale))
        path.addCurve(to: point(13.89755, 24.2189, scale),
                      controlPoint1: point(16.87625, 19.8661, scale),
                      controlPoint2: point(15.73755, 22.3928, scale))
        path.addLine(to: point(16.27795, 26.6021, scale))
        path.addCurve(to: point(20.25125, 17.0745, scale),
                      controlPoint1: point(18.73225, 24.1672, scale),
                      controlPoint2: point(20.25125, 20.7975, scale))
        path.close()
        return path.cgPath
    }

    private static func buildArcOuterPath(scale: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: point(27.00125, 17.0746, scale))
        path.addCurve(to: point(20.69045, 2.4432, scale),
                      controlPoint1: point(27.00125, 11.3146, scale),
                      controlPoint2: point(24.57745, 6.1186, scale))
        path.addLine(to: point(22.00875, 0, scale))
        path.addCurve(to: point(30.37625, 17.0746, scale),
                      controlPoint1: point(27.54645, 4.2882, scale),
                      controlPoint2: point(30.37625, 10.3522, scale))
        path.addCurve(to: point(23.41855, 33.7525, scale),
                      controlPoint1: point(30.37625, 23.5922, scale),
                      controlPoint2: point(27.71625, 29.491, scale))
        path.addLine(to: point(21.03815, 31.3693, scale))
        path.addCurve(to: point(27.00125, 17.0746, scale),
                      controlPoint1: point(24.72155, 27.7166, scale),
                      controlPoint2: point(27.00125, 22.6608, scale))
        path.close()
        return path.cgPath
    }
}
