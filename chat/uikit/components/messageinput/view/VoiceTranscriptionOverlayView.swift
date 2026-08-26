import UIKit
import AVFoundation

struct VoiceTranscriptionCallbacks {
    let onCancel: () -> Void
    let onSendAudio: (String, Int) -> Void
    let onSendText: (String) -> Void
    let onTranslate: (String, String, @escaping (String) -> Void, @escaping () -> Void) -> Void
    let onStartSpeak: (String, @escaping (TimeInterval) -> Void, @escaping () -> Void, @escaping () -> Void) -> Void
    let onStopSpeak: () -> Void
}

final class VoiceTranscriptionOverlayView: UIView {
    private enum TranscriptionState {
        case loading
        case empty
        case text
    }

    private struct OverlayLayout {
        let bubbleTop: CGFloat
        let chipRowTop: CGFloat
        let cancelButtonTop: CGFloat
        let sendAudioButtonTop: CGFloat
        let sendTextButtonTop: CGFloat
        let labelTop: CGFloat
        let waveformTop: CGFloat
    }

    private static let showAnimationDuration: TimeInterval = 0.12

    private static let dismissAnimationDuration: TimeInterval = 0.1

    private static let gradientLocations: [CGFloat] = [0, 0.442, 0.632, 1.0]

    private static let editTextContentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

    private static let waveformPreviewPowerLevel: Int = 60

    private static let smallBubbleHeight: CGFloat = 68

    private static let largeBubbleHeight: CGFloat = 104

    private static let bubbleHeightLineTolerance: CGFloat = 1

    private static let singleLineTextHeight: CGFloat = FontScheme.caption1Regular.lineHeight

    private static let chipContentInsets = UIEdgeInsets(top: 3, left: 12, bottom: 3, right: 12)

    private static let loadingDotsLeadingInset: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let loadingDotsWidth: CGFloat = 48

    private static let loadingDotsHeight: CGFloat = 20

    private static let actionLabelWidth: CGFloat = 96

    private static let vectorIconSize: CGFloat = 20

    private let designWidthDP: CGFloat = 375

    private let bubbleTriangleHeight: CGFloat = 14

    private let chipRowHeight: CGFloat = 26

    private let bubbleWidth: CGFloat = 330

    private let bubbleLeftMargin: CGFloat = 22

    private let waveformHorizontalMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private let iconButtonSize: CGFloat = 48

    private let sendTextButtonSize: CGFloat = 80

    private let labelHeight: CGFloat = 20

    private let waveformHeight: CGFloat = 40

    private let waveformBottom: CGFloat = 43

    private let labelToWaveformGap: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private let iconToLabelGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private let sendTextToWaveformGap: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private let chipRowToActionGap: CGFloat = 30

    private let bubbleToKeyboardGap: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private let bubbleToChipGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private let chipCornerRadius: CGFloat = CGFloat(RadiusScheme.roundRadius)

    private let cancelButtonLeftDP: CGFloat = 48

    private let sendAudioButtonLeftDP: CGFloat = 142

    private let sendTextButtonLeftDP: CGFloat = 247

    private let backgroundView = RecorderGradientBackgroundView()

    private let bubbleView = TranscriptionBubbleView()

    private let editTextView = VerticalCenterTextView()

    private let loadingDotsView = LoadingDotsView()

    private let waveformView = RecorderBubbleView()

    private let cancelButton = UIButton(type: .system)

    private let sendAudioButton = UIButton(type: .system)

    private let sendTextButton = UIButton(type: .system)

    private let cancelLabel = UILabel()

    private let sendAudioLabel = UILabel()

    private let chipRow = UIStackView()

    private let audioPath: String

    private let audioDurationSecond: Int

    private let originalAudioDurationMs: Int

    private var callbacks: VoiceTranscriptionCallbacks

    private var state: TranscriptionState

    private var originalText: String = ""

    private var translatedText: String?

    private var isTranslating = false

    private var isSpeaking = false

    private var isDismissed = false

    private var keyboardHeight: CGFloat = 0

    private var bubbleHeight: CGFloat = VoiceTranscriptionOverlayView.smallBubbleHeight

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Init

    init(frame: CGRect,
         audioPath: String,
         audioDurationSecond: Int,
         text: String?,
         callbacks: VoiceTranscriptionCallbacks) {
        self.audioPath = audioPath
        self.audioDurationSecond = audioDurationSecond
        self.originalAudioDurationMs = audioDurationSecond * 1000
        self.callbacks = callbacks
        if let text = text, !text.isEmpty {
            self.state = .text
            self.originalText = text
        } else if text != nil {
            self.state = .empty
        } else {
            self.state = .loading
        }
        super.init(frame: frame)
        constructHierarchy()
        setupStyle()
        setupActions()
        bindInitialText()
        renderChipRow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopSpeaking()
    }

    // MARK: - Public

    func show(in window: UIWindow) {
        alpha = 0
        window.addSubview(self)
        self.frame = window.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        installKeyboardTracking()
        UIView.animate(withDuration: Self.showAnimationDuration) {
            self.alpha = 1
        }
    }

    func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true
        stopSpeaking()
        removeKeyboardTracking()
        UIView.animate(withDuration: Self.dismissAnimationDuration, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    func updateResult(_ resultText: String?) {
        if let resultText = resultText, !resultText.isEmpty {
            state = .text
            if originalText.isEmpty {
                originalText = resultText
            }
            translatedText = nil
            isTranslating = false
            if isSpeaking {
                isSpeaking = false
                callbacks.onStopSpeak()
            }
        } else {
            state = .empty
        }
        updateBubbleHeightForState(resultText)
        bindBubbleText(resultText)
        renderChipRow()
        applyTheme()
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        let layout = calculateOverlayLayout(
            rootHeight: bounds.height,
            bubbleHeight: bubbleHeight,
            keyboardHeight: keyboardHeight,
            showChipRow: state == .text
        )
        bubbleView.frame = CGRect(x: scaleX(bubbleLeftMargin), y: layout.bubbleTop, width: scaleX(bubbleWidth), height: bubbleHeight)
        positionInBubble()
        waveformView.frame = CGRect(
            x: scaleX(waveformHorizontalMargin),
            y: layout.waveformTop,
            width: bounds.width - scaleX(waveformHorizontalMargin) * 2,
            height: waveformHeight
        )
        chipRow.frame = CGRect(x: scaleX(bubbleLeftMargin), y: layout.chipRowTop, width: bounds.width - scaleX(bubbleLeftMargin) * 2, height: chipRowHeight)
        cancelButton.frame = circleFrame(leftDP: cancelButtonLeftDP, top: layout.cancelButtonTop, size: iconButtonSize)
        sendAudioButton.frame = circleFrame(leftDP: sendAudioButtonLeftDP, top: layout.sendAudioButtonTop, size: iconButtonSize)
        sendTextButton.frame = circleFrame(leftDP: sendTextButtonLeftDP, top: layout.sendTextButtonTop, size: sendTextButtonSize)
        cancelLabel.frame = labelFrame(centerX: cancelButton.center.x, top: layout.labelTop)
        sendAudioLabel.frame = labelFrame(centerX: sendAudioButton.center.x, top: layout.labelTop)
        makeCircular(cancelButton)
        makeCircular(sendAudioButton)
        makeCircular(sendTextButton)
        applyTheme()
    }

    private func constructHierarchy() {
        addSubview(backgroundView)
        addSubview(bubbleView)
        addSubview(waveformView)
        addSubview(chipRow)
        addSubview(cancelButton)
        addSubview(sendAudioButton)
        addSubview(sendTextButton)
        addSubview(cancelLabel)
        addSubview(sendAudioLabel)

        bubbleView.addSubview(editTextView)
        bubbleView.addSubview(loadingDotsView)

        chipRow.axis = .horizontal
        chipRow.spacing = CGFloat(SpacingScheme.iconIconSpacing)
        chipRow.alignment = .center
    }

    private func setupStyle() {
        backgroundColor = .clear
        let colors = ChatUIKitTheme.colors
        backgroundView.setGradientSpec(
            Self.overlayGradientColors(base: colors.bgColorOperate),
            Self.gradientLocations
        )

        editTextView.backgroundColor = .clear
        editTextView.font = FontScheme.caption1Regular
        editTextView.textColor = colors.textColorButton
        editTextView.textAlignment = .left
        editTextView.semanticContentAttribute = .forceLeftToRight
        editTextView.textContainerInset = Self.editTextContentInsets
        editTextView.textContainer.lineFragmentPadding = 0
        editTextView.isScrollEnabled = true
        editTextView.returnKeyType = .done

        let closeIcon = Self.vectorIcon(.close)
        let transcribeIcon = Self.vectorIcon(.transcribe)
        cancelButton.setImage(closeIcon, for: .normal)
        sendAudioButton.setImage(transcribeIcon, for: .normal)
        cancelButton.setTitle(nil, for: .normal)
        sendAudioButton.setTitle(nil, for: .normal)
        cancelButton.tintColor = colors.textColorPrimary
        sendAudioButton.tintColor = colors.textColorPrimary
        sendTextButton.titleLabel?.font = FontScheme.caption1Medium
        sendTextButton.setTitleColor(colors.textColorButton, for: .normal)
        sendTextButton.setTitle(LocalizedChatString("message_input_send"), for: .normal)

        cancelLabel.font = FontScheme.caption3Regular
        sendAudioLabel.font = FontScheme.caption3Regular
        cancelLabel.textAlignment = .center
        sendAudioLabel.textAlignment = .center
        cancelLabel.text = LocalizedChatString("message_input_cancel")
        sendAudioLabel.text = LocalizedChatString("message_input_send_original_voice")

        waveformView.setBubbleColor(ChatUIKitTheme.colors.bgColorInput)
        waveformView.setContentColor(ChatUIKitTheme.colors.textColorPrimary)
        waveformView.setDuration(originalAudioDurationMs)
        waveformView.setPowerLevel(Self.waveformPreviewPowerLevel)
        waveformView.setFlat(true)
        waveformView.stopAnimating()
        waveformView.isUserInteractionEnabled = true
        waveformView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleWaveformPlayback)))
    }

    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        sendAudioButton.addTarget(self, action: #selector(handleSendAudio), for: .touchUpInside)
        sendTextButton.addTarget(self, action: #selector(handleSendText), for: .touchUpInside)
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        backgroundTap.cancelsTouchesInView = false
        addGestureRecognizer(backgroundTap)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard !bubbleView.frame.contains(location) else { return }
        editTextView.resignFirstResponder()
    }

    private func bindInitialText() {
        bindBubbleText(originalText.isEmpty ? nil : originalText)
        updateBubbleHeightForState(originalText.isEmpty ? nil : originalText)
        applyTheme()
    }

    @objc private func handleCancel() {
        dismiss()
        callbacks.onCancel()
    }

    @objc private func handleSendAudio() {
        dismiss()
        callbacks.onSendAudio(audioPath, max(audioDurationSecond, 1))
    }

    @objc private func handleSendText() {
        let currentText = editTextView.text ?? ""
        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        dismiss()
        callbacks.onSendText(currentText)
    }

    private func applyTheme() {
        let colors = ChatUIKitTheme.colors
        backgroundView.setGradientSpec(
            Self.overlayGradientColors(base: colors.bgColorOperate),
            Self.gradientLocations
        )
        bubbleView.bubbleColor = state == .empty ? colors.buttonColorHangupDefault : colors.buttonColorPrimaryDefault
        let arrowCenterX = sendTextButton.frame.midX - bubbleView.frame.minX
        bubbleView.arrowCenterX = arrowCenterX
        loadingDotsView.dotColor = colors.textColorButton
        editTextView.textColor = colors.textColorButton
        cancelButton.backgroundColor = colors.buttonColorSecondaryDefault
        sendAudioButton.backgroundColor = colors.buttonColorSecondaryDefault
        sendTextButton.backgroundColor = state == .text ? colors.buttonColorPrimaryDefault : colors.buttonColorPrimaryDisabled
        cancelButton.setTitleColor(colors.textColorPrimary, for: .normal)
        sendAudioButton.setTitleColor(colors.textColorPrimary, for: .normal)
        sendTextButton.setTitleColor(colors.textColorButton, for: .normal)
        cancelLabel.textColor = colors.textColorTertiary
        sendAudioLabel.textColor = colors.textColorTertiary
        waveformView.setBubbleColor(colors.bgColorInput)
        waveformView.setContentColor(colors.textColorPrimary)
        sendTextButton.isEnabled = state == .text
    }

    private func bindBubbleText(_ resultText: String?) {
        if state == .loading {
            editTextView.isHidden = true
            loadingDotsView.isHidden = false
            editTextView.text = ""
        } else {
            let display: String
            switch state {
            case .empty:
                display = LocalizedChatString("message_input_voice_transcription_empty")
            case .text:
                display = resultText ?? originalText
            default:
                display = ""
            }
            loadingDotsView.isHidden = true
            editTextView.isHidden = false
            editTextView.text = display
            editTextView.isEditable = state == .text
        }
        sendTextButton.isEnabled = state == .text
    }

    private func updateBubbleHeightForState(_ resultText: String?) {
        let exceedsSingleLine = state == .text
            && renderedTextHeight(resultText ?? "") > Self.singleLineTextHeight + Self.bubbleHeightLineTolerance
        let next: CGFloat = exceedsSingleLine ? Self.largeBubbleHeight : Self.smallBubbleHeight
        guard next != bubbleHeight else { return }
        bubbleHeight = next
        setNeedsLayout()
    }

    private func renderedTextHeight(_ text: String) -> CGFloat {
        let width = scaleX(bubbleWidth) - Self.editTextContentInsets.left - Self.editTextContentInsets.right
        guard width > 0, !text.isEmpty else { return 0 }
        return (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: FontScheme.caption1Regular],
            context: nil
        ).height
    }

    private func renderChipRow() {
        chipRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard state == .text else {
            chipRow.isHidden = true
            return
        }
        chipRow.isHidden = false
        if translatedText == nil {
            chipRow.addArrangedSubview(makeChip(
                title: LocalizedChatString("voice_message_translate"),
                enabled: !isTranslating,
                action: { [weak self] in self?.handleTranslateChip() }
            ))
        } else {
            chipRow.addArrangedSubview(makeChip(
                title: LocalizedChatString("voice_message_undo_translate"),
                enabled: true,
                action: { [weak self] in self?.handleUndoTranslate() }
            ))
            let speakTitle = isSpeaking
                ? LocalizedChatString("voice_message_stop")
                : LocalizedChatString("voice_message_read_aloud")
            let dualPill = TranscriptionDualPillView()
            dualPill.configure(
                leftTitle: LocalizedChatString("voice_message_switch_language"),
                leftEnabled: !isTranslating,
                rightTitle: speakTitle,
                onLeft: { [weak self] in self?.handleSwitchLanguage() },
                onRight: { [weak self] in self?.handleReadAloud() }
            )
            chipRow.addArrangedSubview(dualPill)
        }
        chipRow.addArrangedSubview(makeFlexibleSpacer())
    }

    private func makeFlexibleSpacer() -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = .clear
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }

    private static func overlayGradientColors(base: UIColor) -> [UIColor] {
        return [
            base.withAlphaComponent(0),
            base.withAlphaComponent(0),
            base,
            base
        ]
    }

    private func makeChip(title: String, enabled: Bool, action: @escaping () -> Void) -> UIButton {
        let chip = UIButton(type: .system)
        chip.setTitle(title, for: .normal)
        chip.titleLabel?.font = FontScheme.caption3Regular
        chip.setTitleColor(enabled ? ChatUIKitTheme.colors.textColorSecondary : ChatUIKitTheme.colors.textColorDisable, for: .normal)
        chip.contentEdgeInsets = Self.chipContentInsets
        chip.backgroundColor = ChatUIKitTheme.colors.buttonColorSecondaryDefault
        chip.layer.cornerRadius = chipCornerRadius
        chip.contentHorizontalAlignment = .center
        chip.setContentHuggingPriority(.required, for: .horizontal)
        chip.heightAnchor.constraint(equalToConstant: chipRowHeight).isActive = true
        chip.isEnabled = enabled
        if enabled {
            chip.addAction(UIAction(handler: { _ in action() }), for: .touchUpInside)
        }
        return chip
    }

    private func handleTranslateChip() {
        if isTranslating { return }
        let lang = VoiceTranscriptionLanguageStore.selected
        if lang.isEmpty {
            presentLanguageSelector { [weak self] picked in
                VoiceTranscriptionLanguageStore.selected = picked
                self?.translateWith(picked)
            }
        } else {
            translateWith(lang)
        }
    }

    private func handleSwitchLanguage() {
        if isTranslating { return }
        presentLanguageSelector { [weak self] picked in
            VoiceTranscriptionLanguageStore.selected = picked
            self?.translateWith(picked)
        }
    }

    private func handleUndoTranslate() {
        if isSpeaking {
            stopReadAloud()
        }
        translatedText = nil
        setBubbleText(originalText)
        renderChipRow()
    }

    private func handleReadAloud() {
        if isSpeaking {
            stopReadAloud()
            return
        }
        let current = editTextView.text ?? ""
        guard !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSpeaking = true
        waveformView.setPseudoSpeaking(true)
        renderChipRow()
        callbacks.onStartSpeak(current, { [weak self] ttsDuration in
            guard let self = self, !self.isDismissed else { return }
            guard self.isSpeaking else { return }
            let ttsMs = Int(ttsDuration * 1000)
            waveformView.setDuration(ttsMs > 0 ? ttsMs : self.originalAudioDurationMs)
        }, { [weak self] in
            guard let self = self, !self.isDismissed else { return }
            if self.isSpeaking {
                self.stopReadAloud()
            }
        }, { [weak self] in
            guard let self = self, !self.isDismissed else { return }
            self.stopReadAloud()
        })
    }

    private func stopReadAloud() {
        isSpeaking = false
        waveformView.setPseudoSpeaking(false)
        waveformView.setDuration(originalAudioDurationMs)
        callbacks.onStopSpeak()
        renderChipRow()
    }

    private func translateWith(_ languageCode: String) {
        guard !originalText.isEmpty, !isTranslating else { return }
        isTranslating = true
        renderChipRow()
        callbacks.onTranslate(originalText, languageCode, { [weak self] translated in
            guard let self = self, !self.isDismissed else { return }
            self.isTranslating = false
            if translated.isEmpty {
                self.renderChipRow()
                return
            }
            self.translatedText = translated
            self.setBubbleText(translated)
            self.renderChipRow()
        }, { [weak self] in
            guard let self = self, !self.isDismissed else { return }
            self.isTranslating = false
            self.renderChipRow()
        })
    }

    private func setBubbleText(_ value: String) {
        updateBubbleHeightForState(value)
        editTextView.text = value
        sendTextButton.isEnabled = state == .text && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentLanguageSelector(onPicked: @escaping (String) -> Void) {
        let sheet = UIAlertController(
            title: LocalizedChatString("voice_message_select_language"),
            message: nil,
            preferredStyle: .actionSheet
        )
        let current = VoiceTranscriptionLanguageStore.selected
        for option in VoiceTranscriptionLanguageStore.options {
            let action = UIAlertAction(title: option.nativeName, style: .default) { _ in
                onPicked(option.code)
            }
            if option.code == current {
                action.setValue(true, forKey: "checked")
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        findViewController()?.present(sheet, animated: true)
    }

    @objc private func toggleWaveformPlayback() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
            waveformView.setFlat(true)
            waveformView.stopAnimating()
            return
        }
        if audioPlayer == nil {
            let url = URL(fileURLWithPath: audioPath)
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
        }
        audioPlayer?.play()
        if audioPlayer?.isPlaying == true {
            waveformView.setFlat(false)
            waveformView.setPowerLevel(Self.waveformPreviewPowerLevel)
            waveformView.startAnimating()
        }
    }

    private func stopSpeaking() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        waveformView.setPseudoSpeaking(false)
        waveformView.setDuration(originalAudioDurationMs)
    }

    private func installKeyboardTracking() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    private func removeKeyboardTracking() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let height = frame.minY < bounds.height ? bounds.height - frame.minY : 0
        let next = max(height, 0)
        guard next != keyboardHeight else { return }
        keyboardHeight = next
        setNeedsLayout()
    }

    private func positionInBubble() {
        let bodyHeight = bubbleHeight - bubbleTriangleHeight
        editTextView.contentInset = .zero
        editTextView.scrollIndicatorInsets = .zero
        editTextView.frame = CGRect(x: 0, y: 0, width: bubbleView.bounds.width, height: bodyHeight)
        editTextView.setNeedsLayout()
        editTextView.layoutIfNeeded()
        let textViewHeight = min(editTextView.contentSize.height, bodyHeight)
        let verticalOffset = max(0, (bodyHeight - textViewHeight) / 2)
        editTextView.frame = CGRect(
            x: 0,
            y: verticalOffset,
            width: bubbleView.bounds.width,
            height: bodyHeight - verticalOffset
        )
        loadingDotsView.frame = CGRect(x: Self.loadingDotsLeadingInset, y: (bodyHeight - Self.loadingDotsHeight) / 2, width: Self.loadingDotsWidth, height: Self.loadingDotsHeight)
    }

    private func circleFrame(leftDP: CGFloat, top: CGFloat, size: CGFloat) -> CGRect {
        return CGRect(x: scaleX(leftDP), y: top, width: size, height: size)
    }

    private func labelFrame(centerX: CGFloat, top: CGFloat) -> CGRect {
        return CGRect(x: centerX - Self.actionLabelWidth / 2, y: top, width: Self.actionLabelWidth, height: labelHeight)
    }

    private func makeCircular(_ button: UIButton) {
        button.clipsToBounds = true
        button.layer.cornerRadius = min(button.bounds.width, button.bounds.height) / 2
    }

    private func scaleX(_ dp: CGFloat) -> CGFloat {
        return dp * bounds.width / designWidthDP
    }

    private func calculateOverlayLayout(rootHeight: CGFloat,
                                        bubbleHeight: CGFloat,
                                        keyboardHeight: CGFloat,
                                        showChipRow: Bool) -> OverlayLayout {
        let safeRootHeight = max(rootHeight, 1)
        let iconButtonSize = self.iconButtonSize
        let sendTextButtonSize = self.sendTextButtonSize
        let labelHeight = self.labelHeight
        let waveformHeight = self.waveformHeight
        let waveformBottom = self.waveformBottom
        let labelToWaveformGap = self.labelToWaveformGap
        let iconToLabelGap = self.iconToLabelGap
        let sendTextToWaveformGap = self.sendTextToWaveformGap
        let chipRowToActionGap = self.chipRowToActionGap
        let bubbleToKeyboardGap = self.bubbleToKeyboardGap
        let bubbleToChipGap = self.bubbleToChipGap
        let chipBlock = showChipRow ? (chipRowHeight + bubbleToChipGap) : 0

        let waveformTop = max(safeRootHeight - waveformBottom - waveformHeight, 0)
        let labelTop = max(waveformTop - labelToWaveformGap - labelHeight, 0)
        let iconButtonTop = max(labelTop - iconToLabelGap - iconButtonSize, 0)
        let sendTextButtonTop = max(waveformTop - sendTextToWaveformGap - sendTextButtonSize, 0)
        let firstActionTop = min(iconButtonTop, sendTextButtonTop)

        let bubbleTopAboveActions = max(firstActionTop - chipRowToActionGap - chipBlock - bubbleHeight, 0)
        let maxBubbleTopBeforeKeyboard: CGFloat = keyboardHeight > 0
            ? max(safeRootHeight - keyboardHeight - bubbleToKeyboardGap - chipBlock - bubbleHeight, 0)
            : .greatestFiniteMagnitude

        let bubbleTop = min(bubbleTopAboveActions, maxBubbleTopBeforeKeyboard)
        return OverlayLayout(
            bubbleTop: bubbleTop,
            chipRowTop: bubbleTop + bubbleHeight + bubbleToChipGap,
            cancelButtonTop: iconButtonTop,
            sendAudioButtonTop: iconButtonTop,
            sendTextButtonTop: sendTextButtonTop,
            labelTop: labelTop,
            waveformTop: waveformTop
        )
    }

    private func findViewController() -> UIViewController? {
        if let root = self.window?.rootViewController {
            var controller: UIViewController? = root
            while let presented = controller?.presentedViewController {
                controller = presented
            }
            return controller
        }
        return nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceTranscriptionOverlayView: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer = nil
        waveformView.setPseudoSpeaking(false)
        waveformView.setDuration(originalAudioDurationMs)
    }
}

// MARK: - 气泡（圆角 + 底部箭头，对齐 Android `TranscriptionBubbleView`）

final class TranscriptionBubbleView: UIView {
    var bubbleColor: UIColor = .clear {
        didSet { setNeedsDisplay() }
    }

    var arrowCenterX: CGFloat? {
        didSet { setNeedsDisplay() }
    }

    private static let defaultArrowCenterTrailingInset: CGFloat = 64

    private let paintLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.addSublayer(paintLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    private func redraw() {
        let triangleHeight: CGFloat = 14
        let bodyBottom = bounds.height - triangleHeight
        let radius: CGFloat = 8
        let halfArrow: CGFloat = 12
        let path = UIBezierPath()
        let bodyRect = CGRect(x: 0, y: 0, width: bounds.width, height: bodyBottom)
        path.append(UIBezierPath(roundedRect: bodyRect, cornerRadius: radius))
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let fallbackArrowCenterX = isRTL ? Self.defaultArrowCenterTrailingInset : bounds.width - Self.defaultArrowCenterTrailingInset
        let centerX = (arrowCenterX ?? fallbackArrowCenterX).clamped(to: radius + halfArrow ... bounds.width - radius - halfArrow)
        path.move(to: CGPoint(x: centerX - halfArrow, y: bodyBottom))
        path.addLine(to: CGPoint(x: centerX, y: bounds.height))
        path.addLine(to: CGPoint(x: centerX + halfArrow, y: bodyBottom))
        path.close()
        paintLayer.path = path.cgPath
        paintLayer.fillColor = bubbleColor.cgColor
    }
}

// MARK: - 垂直居中文本视图（对齐 Android `Gravity.CENTER_VERTICAL`）

final class VerticalCenterTextView: UITextView {

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

// MARK: - Loading 三点（对齐 Android `LoadingDotsView`）

final class LoadingDotsView: UIView {
    var dotColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    private static let dotPhaseStep: CGFloat = 0.18

    private static let dotAnimationCycleDuration: CGFloat = 0.9

    private static let dotMinAlpha: CGFloat = 90

    private static let dotAlphaAmplitude: CGFloat = 165

    private var displayLink: CADisplayLink?

    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let radius: CGFloat = 3
        let gap: CGFloat = 10
        let startX = radius
        let centerY = bounds.height / 2
        for index in 0 ..< 3 {
            let phase = (progress + CGFloat(index) * Self.dotPhaseStep).truncatingRemainder(dividingBy: 1)
            let alpha = (Self.dotMinAlpha + Self.dotAlphaAmplitude * abs(sin(phase * .pi))).clamped(to: Self.dotMinAlpha ... 255)
            ctx.setFillColor(dotColor.withAlphaComponent(alpha / 255).cgColor)
            ctx.addArc(center: CGPoint(x: startX + CGFloat(index) * gap, y: centerY), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            ctx.fillPath()
        }
    }

    private func startAnimating() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        progress = (progress + CGFloat(link.duration) / Self.dotAnimationCycleDuration).truncatingRemainder(dividingBy: 1)
        setNeedsDisplay()
    }
}

final class TranscriptionDualPillView: UIView {
    private static let pillHeight: CGFloat = 26

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let segmentSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let dividerWidth: CGFloat = 0.5

    private static let dividerHeight: CGFloat = 12

    private static let dividerColor = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? Colors.GrayDark5 : Colors.GrayLight4
    }

    private let leftButton = UIButton(type: .system)

    private let rightButton = UIButton(type: .system)

    private let dividerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        leftButton.titleLabel?.font = FontScheme.caption3Regular
        rightButton.titleLabel?.font = FontScheme.caption3Regular
        dividerView.backgroundColor = Self.dividerColor
        addSubview(leftButton)
        addSubview(dividerView)
        addSubview(rightButton)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let leftWidth = leftButton.intrinsicContentSize.width
        let rightWidth = rightButton.intrinsicContentSize.width
        let width = Self.horizontalPadding * 2 + leftWidth + Self.segmentSpacing + Self.dividerWidth + Self.segmentSpacing + rightWidth
        return CGSize(width: width, height: Self.pillHeight)
    }

    func configure(leftTitle: String,
                   leftEnabled: Bool,
                   rightTitle: String,
                   onLeft: @escaping () -> Void,
                   onRight: @escaping () -> Void) {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.buttonColorSecondaryDefault
        leftButton.setTitle(leftTitle, for: .normal)
        rightButton.setTitle(rightTitle, for: .normal)
        leftButton.setTitleColor(leftEnabled ? colors.textColorSecondary : colors.textColorDisable, for: .normal)
        rightButton.setTitleColor(colors.textColorSecondary, for: .normal)
        leftButton.isEnabled = leftEnabled
        if leftEnabled {
            leftButton.addAction(UIAction(handler: { _ in onLeft() }), for: .touchUpInside)
        }
        rightButton.addAction(UIAction(handler: { _ in onRight() }), for: .touchUpInside)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        let leftWidth = leftButton.intrinsicContentSize.width
        let rightWidth = rightButton.intrinsicContentSize.width
        leftButton.frame = CGRect(x: Self.horizontalPadding, y: 0, width: leftWidth, height: bounds.height)
        dividerView.frame = CGRect(
            x: leftButton.frame.maxX + Self.segmentSpacing,
            y: (bounds.height - Self.dividerHeight) / 2,
            width: Self.dividerWidth,
            height: Self.dividerHeight
        )
        rightButton.frame = CGRect(x: dividerView.frame.maxX + Self.segmentSpacing, y: 0, width: rightWidth, height: bounds.height)
    }
}

// MARK: - 翻译目标语言存储（对齐 Android `VoiceMessageConfig`）

enum VoiceTranscriptionLanguageStore {
    struct Option {
        let code: String
        let nativeName: String
    }

    static let options: [Option] = [
        Option(code: "zh", nativeName: "简体中文"),
        Option(code: "zh-TW", nativeName: "繁體中文"),
        Option(code: "en", nativeName: "English"),
        Option(code: "ja", nativeName: "日本語"),
        Option(code: "ko", nativeName: "한국어"),
        Option(code: "fr", nativeName: "Français"),
        Option(code: "es", nativeName: "Español"),
        Option(code: "it", nativeName: "Italiano"),
        Option(code: "de", nativeName: "Deutsch"),
        Option(code: "tr", nativeName: "Türkçe"),
        Option(code: "ru", nativeName: "Русский"),
        Option(code: "pt", nativeName: "Português"),
        Option(code: "vi", nativeName: "Tiếng Việt"),
        Option(code: "id", nativeName: "Bahasa Indonesia"),
        Option(code: "th", nativeName: "ภาษาไทย"),
        Option(code: "ms", nativeName: "Bahasa Melayu"),
        Option(code: "hi", nativeName: "हिन्दी")
    ]

    private static let key = "AtomicXRecordTranslateTargetLanguage"

    static var selected: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Android 矢量图标（对齐 message_input_voice_close_icon / message_input_voice_transcribe_icon）

private enum ChatVectorIcon {
    case close
    case transcribe

    var pathData: String {
        switch self {
        case .close:
            return "M16.6286,4.2548 L4.2542,16.6291 L3.3704,15.7452 L15.7447,3.3709 L16.6286,4.2548 Z M15.7446,16.6292 L3.3703,4.2549 L4.2542,3.371 L16.6285,15.7453 L15.7446,16.6292 Z"
        case .transcribe:
            return "M11.8427,18.3046 C13.8068,16.0966 15,13.1876 15,10 C13.8068,3.9034 13.8068,3.9034 11.8427,1.6953 L12.777,0.8649 C14.9375,3.2937 16.25,6.4936 16.25,10 C14.9375,16.7062 14.9375,16.7062 12.777,19.1351 L11.8427,18.3046 Z M9.9742,3.3563 C11.5455,5.1227 12.5,7.4499 12.5,10 C11.5455,14.8773 11.5455,14.8773 9.9742,16.6437 L9.0399,15.8132 C10.4148,14.2676 11.25,12.2313 11.25,10 C10.4148,5.7323 10.4148,5.7323 9.0399,4.1867 L9.9742,3.3563 Z M7.1714,14.1523 C8.1534,13.0483 8.75,11.5938 8.75,10 C8.1534,6.9517 8.1534,6.9517 7.1714,5.8477 L6.2371,6.6781 C7.0227,7.5613 7.5,8.7249 7.5,10 C7.0227,12.4386 7.0227,12.4386 6.2371,13.3218 L7.1714,14.1523 Z M4.3685,11.6609 C4.7614,11.2193 5,10.6375 5,10 C5,9.3624 4.7614,8.7807 4.3685,8.339 L2.5,10 L4.3685,11.6609 Z"
        }
    }
}

private extension VoiceTranscriptionOverlayView {
    static func vectorIcon(_ icon: ChatVectorIcon) -> UIImage {
        let size = CGSize(width: Self.vectorIconSize, height: Self.vectorIconSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            for path in parseVectorPaths(icon.pathData) {
                path.fill()
            }
        }.withRenderingMode(.alwaysTemplate)
    }
}

private enum VectorToken {
    case command(Character)
    case number(CGFloat)
}

private func parseVectorPaths(_ data: String) -> [UIBezierPath] {
    var tokens: [VectorToken] = []
    var cursor = data.startIndex
    while cursor < data.endIndex {
        let character = data[cursor]
        if character.isLetter {
            tokens.append(.command(character))
            cursor = data.index(after: cursor)
        } else if character == " " || character == "," || character == "\n" || character == "\t" {
            cursor = data.index(after: cursor)
        } else {
            var end = cursor
            while end < data.endIndex {
                let unit = data[end]
                if unit.isNumber || unit == "." || unit == "-" || unit == "+" || unit == "e" || unit == "E" {
                    end = data.index(after: end)
                } else {
                    break
                }
            }
            if let value = Double(String(data[cursor..<end])) {
                tokens.append(.number(CGFloat(value)))
            }
            cursor = end
        }
    }

    var paths: [UIBezierPath] = []
    var path: UIBezierPath?
    var command: Character = "M"
    var numbers: [CGFloat] = []
    for token in tokens {
        switch token {
        case .command(let letter):
            applyVectorCommand(command, numbers, &path, &paths)
            numbers = []
            command = letter
        case .number(let value):
            numbers.append(value)
        }
    }
    applyVectorCommand(command, numbers, &path, &paths)
    return paths
}

private func applyVectorCommand(_ command: Character,
                                _ numbers: [CGFloat],
                                _ path: inout UIBezierPath?,
                                _ paths: inout [UIBezierPath]) {
    switch command {
    case "M":
        if numbers.count >= 2 {
            path = UIBezierPath()
            path?.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            paths.append(path!)
        }
    case "L":
        if numbers.count >= 2 {
            path?.addLine(to: CGPoint(x: numbers[0], y: numbers[1]))
        }
    case "C":
        var index = 0
        while index + 5 < numbers.count {
            path?.addCurve(
                to: CGPoint(x: numbers[index + 4], y: numbers[index + 5]),
                controlPoint1: CGPoint(x: numbers[index], y: numbers[index + 1]),
                controlPoint2: CGPoint(x: numbers[index + 2], y: numbers[index + 3])
            )
            index += 6
        }
    case "Z":
        path?.close()
    default:
        break
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
