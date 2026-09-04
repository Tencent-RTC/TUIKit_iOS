import UIKit

enum AudioRecorderReleaseAction {
    case sendAudio
    case cancel
    case transcribe
}

enum AudioRecorderRecordUiState {
    case idle
    case recording
    case readyToCancel
    case readyToTranscribe
}

struct AudioRecorderGestureTarget {
    let left: CGFloat
    let top: CGFloat
    let width: CGFloat
    let height: CGFloat

    func contains(_ x: CGFloat, _ y: CGFloat) -> Bool {
        return x >= left && x <= left + width && y >= top && y <= top + height
    }
}

final class MessageInputAudioRecorderView: UIView {
    private let backgroundView = RecorderGradientBackgroundView()

    private let statusLabel = UILabel()

    private let cancelButton = RecorderCircleButton()

    private let transcribeButton = RecorderCircleButton()

    private let bubbleView = RecorderBubbleView()

    private var isDismissed = false

    private static let defaultMaxDurationMs: Int = 60000

    private static let shownAlpha: CGFloat = 0.92

    private static let showAnimationDuration: TimeInterval = 0.12

    private static let dismissAnimationDuration: TimeInterval = 0.1

    private static let autoStopCountdownThresholdMs: Int = 10000

    private static let gradientLocations: [CGFloat] = [0, 0.42, 0.67, 1.0]

    private let maxDurationMs: Int

    private let actionSize: CGFloat = 80

    private let cancelLeftMargin: CGFloat = CGFloat(SpacingScheme.maxSpacing)

    private let cancelBottomMargin: CGFloat = 107

    private let transcribeRightMargin: CGFloat = CGFloat(SpacingScheme.maxSpacing)

    private let transcribeBottomMargin: CGFloat = 107

    private let statusBottomMargin: CGFloat = 199

    private let statusHorizontalMargin: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private let bubbleHorizontalMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private let bubbleBottomMargin: CGFloat = 43

    private let bubbleHeight: CGFloat = 40

    init(frame: CGRect, maxDurationMs: Int = MessageInputAudioRecorderView.defaultMaxDurationMs) {
        self.maxDurationMs = maxDurationMs
        super.init(frame: frame)
        constructHierarchy()
        setupStyle()
        setNeedsLayout()
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        bubbleView.stopAnimating()
    }

    // MARK: - Public

    func stopAnimating() {
        bubbleView.stopAnimating()
    }

    func show() {
        guard !isDismissed else { return }
        isHidden = false
        alpha = Self.shownAlpha
        UIView.animate(withDuration: Self.showAnimationDuration) {
            self.alpha = 1.0
        }
    }

    func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true
        UIView.animate(withDuration: Self.dismissAnimationDuration, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    func releaseAction(for finger: CGPoint) -> AudioRecorderReleaseAction {
        let local = CGPoint(x: finger.x - frame.origin.x, y: finger.y - frame.origin.y)
        let cancelTarget = AudioRecorderGestureTarget(
            left: cancelButton.frame.origin.x,
            top: cancelButton.frame.origin.y,
            width: cancelButton.frame.width,
            height: cancelButton.frame.height
        )
        let transcribeTarget = AudioRecorderGestureTarget(
            left: transcribeButton.frame.origin.x,
            top: transcribeButton.frame.origin.y,
            width: transcribeButton.frame.width,
            height: transcribeButton.frame.height
        )
        if cancelTarget.contains(local.x, local.y) {
            return .cancel
        }
        if transcribeTarget.contains(local.x, local.y) {
            return .transcribe
        }
        return .sendAudio
    }

    func update(state: AudioRecorderRecordUiState, durationMs: Int?, powerLevel: Int, maxDurationMs: Int) {
        let action = action(for: state)
        statusLabel.text = statusText(for: action, durationMs: durationMs, maxDurationMs: maxDurationMs)

        let colors = TUIChatKitTheme.colors
        let cancelActive = action == .cancel
        let transcribeActive = action == .transcribe

        cancelButton.setActive(
            cancelActive,
            idleColor: colors.buttonColorSecondaryDefault,
            activeColor: colors.buttonColorHangupDefault,
            contentColor: cancelActive ? colors.textColorButton : colors.textColorPrimary
        )
        transcribeButton.setActive(
            transcribeActive,
            idleColor: colors.buttonColorSecondaryDefault,
            activeColor: colors.buttonColorPrimaryDefault,
            contentColor: transcribeActive ? colors.textColorButton : colors.textColorPrimary
        )

        let bubbleColor: UIColor = cancelActive ? colors.buttonColorHangupDefault : colors.buttonColorPrimaryDefault
        bubbleView.setBubbleColor(bubbleColor)
        bubbleView.setContentColor(colors.textColorButton)
        bubbleView.setPowerLevel(powerLevel)
        bubbleView.setDuration(durationMs)
    }

    // MARK: - Private

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds

        let width = bounds.width
        let height = bounds.height
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft

        let cancelX = isRTL ? width - cancelLeftMargin - actionSize : cancelLeftMargin
        cancelButton.frame = CGRect(
            x: cancelX,
            y: height - cancelBottomMargin - actionSize,
            width: actionSize,
            height: actionSize
        )
        let transcribeX = isRTL ? transcribeRightMargin : width - transcribeRightMargin - actionSize
        transcribeButton.frame = CGRect(
            x: transcribeX,
            y: height - transcribeBottomMargin - actionSize,
            width: actionSize,
            height: actionSize
        )

        statusLabel.numberOfLines = 0
        statusLabel.frame = CGRect(x: statusHorizontalMargin, y: 0, width: width - 2 * statusHorizontalMargin, height: 0)
        statusLabel.sizeToFit()
        var statusFrame = statusLabel.frame
        statusFrame.origin.x = (width - statusFrame.width) / 2
        statusFrame.origin.y = height - statusBottomMargin - statusFrame.height
        statusLabel.frame = statusFrame

        bubbleView.frame = CGRect(
            x: bubbleHorizontalMargin,
            y: height - bubbleBottomMargin - bubbleHeight,
            width: width - 2 * bubbleHorizontalMargin,
            height: bubbleHeight
        )
    }

    private func constructHierarchy() {
        addSubview(backgroundView)
        addSubview(statusLabel)
        addSubview(cancelButton)
        addSubview(transcribeButton)
        addSubview(bubbleView)
    }

    private func setupStyle() {
        backgroundColor = .clear
        backgroundView.setGradientSpec(gradientColors(base: TUIChatKitTheme.colors.bgColorOperate), Self.gradientLocations)
        statusLabel.font = FontScheme.caption2Medium
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        statusLabel.text = LocalizedChatString("message_input_release_send_hint")

        cancelButton.setTitle(LocalizedChatString("message_input_cancel"))
        transcribeButton.setTitle(LocalizedChatString("message_input_transcribe_to_text"))
    }

    private func action(for state: AudioRecorderRecordUiState) -> AudioRecorderReleaseAction {
        switch state {
        case .readyToCancel:
            return .cancel
        case .readyToTranscribe:
            return .transcribe
        default:
            return .sendAudio
        }
    }

    private func statusText(for action: AudioRecorderReleaseAction, durationMs: Int?, maxDurationMs: Int) -> String {
        if action == .cancel {
            return LocalizedChatString("message_input_release_cancel_hint")
        }
        if action == .transcribe {
            return LocalizedChatString("message_input_release_transcribe_hint")
        }
        if let durationMs = durationMs, let countdown = remainingSecondsBeforeAutoStop(durationMs, maxDurationMs) {
            return String(format: LocalizedChatString("message_input_auto_stop_countdown"), countdown)
        }
        return LocalizedChatString("message_input_release_send_hint")
    }

    private func remainingSecondsBeforeAutoStop(_ durationMs: Int, _ maxDurationMs: Int) -> Int? {
        guard maxDurationMs > 0 else { return nil }
        let remaining = max(maxDurationMs - durationMs, 0)
        guard remaining <= Self.autoStopCountdownThresholdMs else { return nil }
        return max(Int(ceil(Double(remaining) / 1000)), 1)
    }

    private func gradientColors(base: UIColor) -> [UIColor] {
        return [
            base.withAlphaComponent(0),
            base.withAlphaComponent(0xB3 / 255.0),
            base,
            base
        ]
    }
}

// MARK: - 渐变背景（顶到底，对齐 Android `AudioRecorderOverlayBackgroundPolicy`）

final class RecorderGradientBackgroundView: UIView {
    private var gradientColors: [CGColor] = []

    private var gradientLocations: [CGFloat] = []

    private var cachedHeight: CGFloat = -1

    private var gradient: CGGradient?

    static func gradientColors(base: UIColor) -> [UIColor] {
        return [
            base.withAlphaComponent(0),
            base.withAlphaComponent(0xB3 / 255.0),
            base,
            base
        ]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setGradientSpec(_ colors: [UIColor], _ locations: [CGFloat]) {
        gradientColors = colors.map { $0.cgColor }
        gradientLocations = locations
        cachedHeight = -1
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        if cachedHeight != rect.height || gradient == nil {
            gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: gradientColors as CFArray,
                locations: gradientLocations
            )
            cachedHeight = rect.height
        }
        guard let gradient = gradient else { return }
        ctx.clear(rect)
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: rect.height),
            options: []
        )
    }
}

// MARK: - 气泡（圆角背景 + 波形 + 时长，对齐 Android `BubbleView`）

final class RecorderBubbleView: UIView {
    private static let totalBars = 24

    private static let barWidth: CGFloat = 2.5

    private static let barGap: CGFloat = 3

    private static let cornerRadius: CGFloat = CGFloat(RadiusScheme.alertRadius)

    private static let amplitudeBase: CGFloat = 13

    private static let minBarHeight: CGFloat = 3

    private static let durationRightPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let minBarFrequency: CGFloat = 2.4

    private static let barFrequencySpan: CGFloat = 3.2

    private static let amplitudeBaseFactor: CGFloat = 0.45

    private static let amplitudePowerFactor: CGFloat = 0.55

    private static let pseudoUpdateInterval: CFTimeInterval = 0.08

    private static let pseudoTargetMinValue: CGFloat = 0.1

    private static let pseudoSmoothingFactor: CGFloat = 0.35

    private var bubbleColor: UIColor = .clear

    private var contentColor: UIColor = .white

    private var powerLevel: Int = 0

    private var isFlat = false

    private var pseudoSpeaking = false

    private var pseudoTargets: [CGFloat] = []

    private var pseudoCurrent: [CGFloat] = []

    private var pseudoTimer: CFTimeInterval = 0

    private var durationText: String = "--:--"

    private let phases: [CGFloat]

    private let freqs: [CGFloat]

    private let startTime = CACurrentMediaTime()

    private let durationFont: UIFont

    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        var seed: UInt32 = 20260421
        func nextRandom() -> CGFloat {
            seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
            return CGFloat(seed) / CGFloat(0x7fffffff)
        }
        phases = (0..<RecorderBubbleView.totalBars).map { _ in nextRandom() * .pi * 2 }
        freqs = (0..<RecorderBubbleView.totalBars).map { _ in RecorderBubbleView.minBarFrequency + nextRandom() * RecorderBubbleView.barFrequencySpan }
        pseudoTargets = Array(repeating: 0.5, count: RecorderBubbleView.totalBars)
        pseudoCurrent = Array(repeating: 0.5, count: RecorderBubbleView.totalBars)
        durationFont = FontScheme.caption3Bold
        super.init(frame: frame)
        backgroundColor = .clear
        startAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopAnimating()
    }

    func startAnimating() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let bubblePath = UIBezierPath(roundedRect: rect, cornerRadius: RecorderBubbleView.cornerRadius)
        ctx.addPath(bubblePath.cgPath)
        ctx.setFillColor(bubbleColor.cgColor)
        ctx.fillPath()

        let centerY = rect.height / 2
        let layout = waveformLayout(containerWidth: rect.width)
        let t = CACurrentMediaTime() - startTime
        let normalizedPower = CGFloat(min(max(powerLevel, 0), 100)) / 100
        let amplitude = isFlat ? 0 : RecorderBubbleView.amplitudeBase * (RecorderBubbleView.amplitudeBaseFactor + normalizedPower * RecorderBubbleView.amplitudePowerFactor)

        for i in 0..<RecorderBubbleView.totalBars {
            let noise: CGFloat
            if pseudoSpeaking {
                noise = pseudoCurrent[i]
            } else {
                noise = abs(sin(t * Double(freqs[i]) + Double(phases[i])))
            }
            let barHeight = RecorderBubbleView.minBarHeight + amplitude * CGFloat(noise)
            let x = layout.startX + CGFloat(i) * (RecorderBubbleView.barWidth + RecorderBubbleView.barGap)
            let barRect = CGRect(
                x: x,
                y: centerY - barHeight / 2,
                width: RecorderBubbleView.barWidth,
                height: barHeight
            )
            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: RecorderBubbleView.barWidth / 2)
            ctx.addPath(barPath.cgPath)
        }
        ctx.setFillColor(contentColor.cgColor)
        ctx.fillPath()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: durationFont,
            .foregroundColor: contentColor
        ]
        let textSize = (durationText as NSString).size(withAttributes: attributes)
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let textX = isRTL
            ? RecorderBubbleView.durationRightPadding
            : rect.width - RecorderBubbleView.durationRightPadding - textSize.width
        let textY = centerY - textSize.height / 2
        (durationText as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
    }

    func setBubbleColor(_ color: UIColor) {
        if bubbleColor != color {
            bubbleColor = color
            setNeedsDisplay()
        }
    }

    func setContentColor(_ color: UIColor) {
        if contentColor != color {
            contentColor = color
            setNeedsDisplay()
        }
    }

    func setPowerLevel(_ level: Int) {
        powerLevel = level
    }

    func setFlat(_ flat: Bool) {
        isFlat = flat
        setNeedsDisplay()
    }

    func setPseudoSpeaking(_ speaking: Bool) {
        pseudoSpeaking = speaking
        if speaking {
            isFlat = false
            startAnimating()
        } else {
            isFlat = true
            stopAnimating()
            setNeedsDisplay()
        }
    }

    func setDuration(_ milliseconds: Int?) {
        durationText = Self.formatDuration(milliseconds)
        setNeedsDisplay()
    }

    @objc private func tick() {
        if pseudoSpeaking {
            updatePseudoAudio()
        }
        setNeedsDisplay()
    }

    private func updatePseudoAudio() {
        let now = CACurrentMediaTime()
        guard now - pseudoTimer > RecorderBubbleView.pseudoUpdateInterval else { return }
        pseudoTimer = now
        for index in 0..<RecorderBubbleView.totalBars {
            if Bool.random() {
                pseudoTargets[index] = CGFloat.random(in: RecorderBubbleView.pseudoTargetMinValue ... 1.0)
            }
            pseudoCurrent[index] += (pseudoTargets[index] - pseudoCurrent[index]) * RecorderBubbleView.pseudoSmoothingFactor
        }
    }

    private func waveformLayout(containerWidth: CGFloat) -> (startX: CGFloat, totalWidth: CGFloat) {
        let totalWidth = CGFloat(RecorderBubbleView.totalBars) * RecorderBubbleView.barWidth
            + CGFloat(RecorderBubbleView.totalBars - 1) * RecorderBubbleView.barGap
        let startX = (containerWidth - totalWidth) / 2
        return (startX, totalWidth)
    }

    private static func formatDuration(_ milliseconds: Int?) -> String {
        guard let milliseconds = milliseconds else { return "--:--" }
        return DateHelper.formatDurationMillis(milliseconds)
    }
}

// MARK: - 圆钮（取消 / 转文字，对齐 Android `cancelButtonView` / `transcribeButtonView`）

final class RecorderCircleButton: UIView {
    private static let titleMinimumScaleFactor: CGFloat = 0.6

    private let circleView = UIView()

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        circleView.layer.masksToBounds = true
        addSubview(circleView)
        circleView.addSubview(titleLabel)
        titleLabel.font = FontScheme.caption1Bold
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = Self.titleMinimumScaleFactor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ text: String) {
        titleLabel.text = text
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        circleView.frame = bounds
        circleView.layer.cornerRadius = bounds.width / 2
        titleLabel.frame = bounds
    }

    func setActive(_ active: Bool, idleColor: UIColor, activeColor: UIColor, contentColor: UIColor) {
        let background = active ? activeColor : idleColor
        if circleView.backgroundColor != background {
            circleView.backgroundColor = background
        }
        if titleLabel.textColor != contentColor {
            titleLabel.textColor = contentColor
        }
    }
}
