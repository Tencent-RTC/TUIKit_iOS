import Foundation
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

enum AudioRecorderGesturePolicy {
    static let cancelUpwardDistance: CGFloat = 50

    static func textOnlyReleaseAction(initialFinger: CGPoint, finger: CGPoint) -> AudioRecorderReleaseAction {
        initialFinger.y - finger.y >= cancelUpwardDistance ? .cancel : .transcribe
    }
}

final class MessageInputAudioRecorderView: UIView {
    private let backgroundView = RecorderGradientBackgroundView()

    private let statusLabel = UILabel()

    private let cancelButton = RecorderCircleButton()

    private let transcribeButton = RecorderCircleButton()

    private let bubbleView = RecorderBubbleView()

    private var isDismissed = false

    private var realtimeActive = false

    private var lastAction: AudioRecorderReleaseAction = .sendAudio

    private static let defaultMaxDurationMs: Int = 60000

    private static let shownAlpha: CGFloat = 0.92

    private static let showAnimationDuration: TimeInterval = 0.12

    private static let dismissAnimationDuration: TimeInterval = 0.1

    private static let autoStopCountdownThresholdMs: Int = 10000

    private static let gradientLocations: [CGFloat] = [0, 0.42, 0.67, 1.0]

    private let maxDurationMs: Int
    private let allowSendOriginalVoice: Bool
    private let initialFinger: CGPoint

    private let actionSize: CGFloat = 80

    private let cancelLeftMargin: CGFloat = CGFloat(SpacingScheme.maxSpacing)

    private let cancelBottomMargin: CGFloat = 107

    private let transcribeRightMargin: CGFloat = CGFloat(SpacingScheme.maxSpacing)

    private let transcribeBottomMargin: CGFloat = 107

    private let statusBottomMargin: CGFloat = 199

    private let statusHorizontalMargin: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let compactBubbleWidth: CGFloat = 200

    private static let compactWaveformRowHeight: CGFloat = 20

    private static let compactArrowHeight: CGFloat = 8

    private let bubbleBottomMargin: CGFloat = 231

    private let compactBubbleHeight: CGFloat = CGFloat(SpacingScheme.iconIconSpacing) * 2 + MessageInputAudioRecorderView.compactWaveformRowHeight + MessageInputAudioRecorderView.compactArrowHeight

    private let expandedBubbleEdgeMargin: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    init(frame: CGRect, maxDurationMs: Int = MessageInputAudioRecorderView.defaultMaxDurationMs,
         allowSendOriginalVoice: Bool = true, initialFinger: CGPoint = .zero) {
        self.maxDurationMs = maxDurationMs
        self.allowSendOriginalVoice = allowSendOriginalVoice
        self.initialFinger = initialFinger
        super.init(frame: frame)
        constructHierarchy()
        bubbleView.setShowsArrow(true)
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

    func setRealtimeRecognitionActive(_ value: Bool) {
        guard realtimeActive != value else { return }
        realtimeActive = value
        bubbleView.setRecognizedText("")
        syncBubbleExpanded()
    }

    func updateRecognizedText(_ text: String) {
        bubbleView.setRecognizedText(text)
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
        if !allowSendOriginalVoice {
            return AudioRecorderGesturePolicy.textOnlyReleaseAction(initialFinger: initialFinger, finger: finger)
        }
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
        lastAction = action
        syncBubbleExpanded()
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
        let statusMaxWidth = width - 2 * statusHorizontalMargin
        let statusSize = statusLabel.sizeThatFits(CGSize(width: statusMaxWidth, height: .greatestFiniteMagnitude))
        statusLabel.frame = CGRect(
            x: statusHorizontalMargin,
            y: height - statusBottomMargin - statusSize.height,
            width: statusMaxWidth,
            height: statusSize.height
        )

        if bubbleView.isExpanded {
            let expandedWidth = width - 2 * expandedBubbleEdgeMargin
            let expandedHeight = bubbleView.preferredHeight(containerWidth: expandedWidth)
            bubbleView.frame = CGRect(
                x: expandedBubbleEdgeMargin,
                y: height - bubbleBottomMargin - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
            let arrowX = allowSendOriginalVoice
                ? transcribeButton.frame.midX - bubbleView.frame.minX : expandedWidth / 2
            bubbleView.setArrowCenterX(arrowX)
        } else {
            let compactWidth = min(MessageInputAudioRecorderView.compactBubbleWidth, width - 2 * expandedBubbleEdgeMargin)
            let bubbleY = height - bubbleBottomMargin - compactBubbleHeight
            let bubbleX: CGFloat
            let arrowX: CGFloat
            if allowSendOriginalVoice, lastAction == .cancel {
                let minX = expandedBubbleEdgeMargin
                let maxX = max(width - expandedBubbleEdgeMargin - compactWidth, minX)
                bubbleX = min(max(cancelButton.frame.midX - compactWidth / 2, minX), maxX)
                arrowX = cancelButton.frame.midX - bubbleX
            } else {
                bubbleX = max((width - compactWidth) / 2, expandedBubbleEdgeMargin)
                arrowX = compactWidth / 2
            }
            bubbleView.frame = CGRect(
                x: bubbleX,
                y: bubbleY,
                width: compactWidth,
                height: compactBubbleHeight
            )
            bubbleView.setArrowCenterX(arrowX)
        }
    }

    private func syncBubbleExpanded() {
        bubbleView.setExpanded(realtimeActive && lastAction == .transcribe)
        setNeedsLayout()
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
        statusLabel.text = LocalizedChatString(allowSendOriginalVoice ? "message_input_release_send_hint" : "InputRecordSlideToCancel")
        cancelButton.isHidden = !allowSendOriginalVoice
        transcribeButton.isHidden = !allowSendOriginalVoice

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
        if allowSendOriginalVoice, action == .transcribe {
            return LocalizedChatString("message_input_release_transcribe_hint")
        }
        if let durationMs = durationMs, let countdown = remainingSecondsBeforeAutoStop(durationMs, maxDurationMs) {
            return String(format: LocalizedChatString("message_input_auto_stop_countdown"), countdown)
        }
        return LocalizedChatString(allowSendOriginalVoice ? "message_input_release_send_hint" : "InputRecordSlideToCancel")
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

    private static let expandedHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let expandedVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let expandedWaveformWidth: CGFloat = 40

    private static let expandedWaveformHeight: CGFloat = 20

    static let expandedMaxTextHeight: CGFloat = 220

    private static let expandedArrowHeight: CGFloat = 8

    private static let expandedArrowHalfWidth: CGFloat = 8

    private static let compactRowWaveformWidth: CGFloat = 96

    private static let compactRowWaveformHeight: CGFloat = 20

    private static let compactRowGap: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let textLineSpacing: CGFloat = 4

    private static let placeholderAlpha: CGFloat = 0.6

    private var bubbleColor: UIColor = .clear

    private var contentColor: UIColor = .white

    private var powerLevel: Int = 0

    private var isFlat = false

    private var pseudoSpeaking = false

    private var pseudoTargets: [CGFloat] = []

    private var pseudoCurrent: [CGFloat] = []

    private var pseudoTimer: CFTimeInterval = 0

    private var durationText: String = "--:--"

    private var recognizedText = ""

    private var expanded = false

    private var showsArrow = false

    private var arrowCenterX: CGFloat?

    private let textScrollView = UIScrollView()

    private let textLabel = UILabel()

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
        textLabel.numberOfLines = 0
        textScrollView.showsVerticalScrollIndicator = false
        textScrollView.isHidden = true
        textScrollView.addSubview(textLabel)
        addSubview(textScrollView)
        applyTextContent()
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
        drawBubbleBody(in: ctx, rect: rect)
        if expanded {
            drawWaveform(in: ctx, region: expandedWaveformRegion(rect: rect))
        } else if showsArrow {
            drawCompactRow(in: ctx, rect: rect)
        } else {
            drawWaveform(in: ctx, region: rect)
            drawDuration(in: ctx, rect: rect)
        }
    }

    private func drawBubbleBody(in ctx: CGContext, rect: CGRect) {
        let hasArrow = expanded || showsArrow
        let bodyBottom = hasArrow ? rect.height - RecorderBubbleView.expandedArrowHeight : rect.height
        let path = UIBezierPath()
        let bodyRect = CGRect(x: 0, y: 0, width: rect.width, height: bodyBottom)
        path.append(UIBezierPath(roundedRect: bodyRect, cornerRadius: RecorderBubbleView.cornerRadius))
        if hasArrow {
            let radius = RecorderBubbleView.cornerRadius
            let halfWidth = RecorderBubbleView.expandedArrowHalfWidth
            let fallback = rect.width / 2
            let lowerBound: CGFloat = radius + halfWidth
            let upperBound: CGFloat = max(rect.width - radius - halfWidth, lowerBound)
            let rawCenterX: CGFloat = arrowCenterX ?? fallback
            let centerX: CGFloat = min(max(rawCenterX, lowerBound), upperBound)
            path.move(to: CGPoint(x: centerX - halfWidth, y: bodyBottom))
            path.addLine(to: CGPoint(x: centerX, y: rect.height))
            path.addLine(to: CGPoint(x: centerX + halfWidth, y: bodyBottom))
            path.close()
        }
        ctx.addPath(path.cgPath)
        ctx.setFillColor(bubbleColor.cgColor)
        ctx.fillPath()
    }

    private func drawCompactRow(in ctx: CGContext, rect: CGRect) {
        let contentHeight = rect.height - RecorderBubbleView.expandedArrowHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: durationFont,
            .foregroundColor: contentColor
        ]
        let textSize = (durationText as NSString).size(withAttributes: attributes)
        let rowWidth = RecorderBubbleView.compactRowWaveformWidth + RecorderBubbleView.compactRowGap + textSize.width
        let rowStartX = (rect.width - rowWidth) / 2
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let waveformX = isRTL
            ? rowStartX + textSize.width + RecorderBubbleView.compactRowGap
            : rowStartX
        let durationX = isRTL
            ? rowStartX
            : rowStartX + RecorderBubbleView.compactRowWaveformWidth + RecorderBubbleView.compactRowGap
        let waveformRegion = CGRect(
            x: waveformX,
            y: (contentHeight - RecorderBubbleView.compactRowWaveformHeight) / 2,
            width: RecorderBubbleView.compactRowWaveformWidth,
            height: RecorderBubbleView.compactRowWaveformHeight
        )
        drawWaveform(in: ctx, region: waveformRegion)
        let textY = (contentHeight - textSize.height) / 2
        (durationText as NSString).draw(at: CGPoint(x: durationX, y: textY), withAttributes: attributes)
    }

    private func drawWaveform(in ctx: CGContext, region: CGRect) {
        let barCount = expanded || showsArrow
            ? max(Int((region.width + RecorderBubbleView.barGap) / (RecorderBubbleView.barWidth + RecorderBubbleView.barGap)), 1)
            : RecorderBubbleView.totalBars
        let totalWidth = CGFloat(barCount) * RecorderBubbleView.barWidth + CGFloat(barCount - 1) * RecorderBubbleView.barGap
        let startX = region.minX + (region.width - totalWidth) / 2
        let centerY = region.midY
        let t = CACurrentMediaTime() - startTime
        let normalizedPower = CGFloat(min(max(powerLevel, 0), 100)) / 100
        let amplitude = isFlat ? 0 : RecorderBubbleView.amplitudeBase * (RecorderBubbleView.amplitudeBaseFactor + normalizedPower * RecorderBubbleView.amplitudePowerFactor)

        for i in 0 ..< barCount {
            let noise: CGFloat
            if pseudoSpeaking {
                noise = pseudoCurrent[i]
            } else {
                noise = abs(sin(t * Double(freqs[i]) + Double(phases[i])))
            }
            let barHeight = RecorderBubbleView.minBarHeight + amplitude * CGFloat(noise)
            let x = startX + CGFloat(i) * (RecorderBubbleView.barWidth + RecorderBubbleView.barGap)
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
    }

    private func drawDuration(in ctx: CGContext, rect: CGRect) {
        let centerY = rect.height / 2
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
            applyTextContent()
            setNeedsDisplay()
        }
    }

    var isExpanded: Bool {
        return expanded
    }

    func setRecognizedText(_ text: String) {
        guard recognizedText != text else { return }
        recognizedText = text
        applyTextContent()
        setNeedsLayout()
        if expanded, !text.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.scrollTextToBottom()
            }
        }
        superview?.setNeedsLayout()
    }

    func setExpanded(_ value: Bool) {
        guard expanded != value else { return }
        expanded = value
        textScrollView.isHidden = !value
        setNeedsLayout()
        setNeedsDisplay()
    }

    func setShowsArrow(_ value: Bool) {
        guard showsArrow != value else { return }
        showsArrow = value
        setNeedsDisplay()
    }

    func setArrowCenterX(_ x: CGFloat) {
        guard arrowCenterX != x else { return }
        arrowCenterX = x
        setNeedsDisplay()
    }

    func preferredHeight(containerWidth: CGFloat) -> CGFloat {
        return RecorderBubbleView.expandedVerticalPadding
            + expandedTextHeight(containerWidth: containerWidth)
            + RecorderBubbleView.expandedWaveformHeight
            + RecorderBubbleView.expandedVerticalPadding
            + RecorderBubbleView.expandedArrowHeight
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard expanded else { return }
        let contentWidth = bounds.width - RecorderBubbleView.expandedHorizontalPadding * 2
        let visibleHeight = expandedTextHeight(containerWidth: bounds.width)
        textScrollView.frame = CGRect(
            x: RecorderBubbleView.expandedHorizontalPadding,
            y: RecorderBubbleView.expandedVerticalPadding,
            width: contentWidth,
            height: visibleHeight
        )
        let fullHeight = expandedFullTextHeight(containerWidth: bounds.width)
        textLabel.frame = CGRect(x: 0, y: 0, width: contentWidth, height: fullHeight)
        textScrollView.contentSize = CGSize(width: contentWidth, height: fullHeight)
    }

    private func expandedWaveformRegion(rect: CGRect) -> CGRect {
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let textHeight = expandedTextHeight(containerWidth: rect.width)
        let rowY = RecorderBubbleView.expandedVerticalPadding + textHeight
        let x = isRTL
            ? RecorderBubbleView.expandedHorizontalPadding
            : rect.width - RecorderBubbleView.expandedHorizontalPadding - RecorderBubbleView.expandedWaveformWidth
        return CGRect(
            x: x,
            y: rowY,
            width: RecorderBubbleView.expandedWaveformWidth,
            height: RecorderBubbleView.expandedWaveformHeight
        )
    }

    private func expandedTextHeight(containerWidth: CGFloat) -> CGFloat {
        return min(expandedFullTextHeight(containerWidth: containerWidth), RecorderBubbleView.expandedMaxTextHeight)
    }

    private func expandedFullTextHeight(containerWidth: CGFloat) -> CGFloat {
        let contentWidth = containerWidth - RecorderBubbleView.expandedHorizontalPadding * 2
        guard contentWidth > 0 else { return 0 }
        return max(textLabel.attributedText?.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height ?? 0, FontScheme.caption1Regular.lineHeight)
    }

    private func applyTextContent() {
        let waiting = recognizedText.isEmpty
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = RecorderBubbleView.textLineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: FontScheme.caption1Regular,
            .foregroundColor: contentColor,
            .paragraphStyle: paragraph
        ]
        let display = waiting ? LocalizedChatString("message_input_realtime_transcribing") : recognizedText
        textLabel.attributedText = NSAttributedString(string: display, attributes: attributes)
        textLabel.alpha = waiting ? RecorderBubbleView.placeholderAlpha : 1
    }

    private func scrollTextToBottom() {
        let overflow = textScrollView.contentSize.height - textScrollView.bounds.height
        guard overflow > 0 else { return }
        textScrollView.contentOffset = CGPoint(x: 0, y: overflow)
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
