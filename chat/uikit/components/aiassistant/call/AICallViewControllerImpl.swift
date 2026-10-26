import AVFoundation
import SnapKit
import UIKit

internal final class AICallViewControllerImpl: NSObject {
    internal weak var owner: AICallViewController?

    private var view: UIView {
        guard let owner else { preconditionFailure("AI Call owner is unavailable") }
        return owner.view
    }

    private var isBeingDismissed: Bool {
        owner?.isBeingDismissed ?? false
    }

    private func dismiss(animated: Bool) {
        owner?.dismiss(animated: animated)
    }

    private static let orbSizeFull: CGFloat = 280
    private static let orbSizeCompact: CGFloat = 72
    private static let orbCompactContainerHeight: CGFloat = 104
    private static let topBarHeight: CGFloat = 56
    private static let buttonSize: CGFloat = 56
    private static let buttonSpacing: CGFloat = 16

    private let robotUserID: String
    private let config: AICallConfig

    private let topBar = UIView()
    private let modePillLabel = UILabel()
    private let middleStack = UIStackView()
    private let orbContainer = UIView()
    private let orbView = VoiceOrbView()
    private let transcriptContainer = UIView()
    private var transcriptView: AICallTranscriptView?
    private let statusLabel = UILabel()
    private let buttonRow = UIStackView()
    private let micButton = UIButton(type: .custom)
    private let subtitleButton = UIButton(type: .custom)
    private let hangupButton = UIButton(type: .custom)
    private let disclaimerLabel = UILabel()

    private var orbWidthConstraint: Constraint?
    private var orbHeightConstraint: Constraint?
    private var orbContainerHeightConstraint: Constraint?

    private var controller: AICallController?
    private var latestEntries: [AICallTranscriptEntry] = []
    private var subtitleVisible = true
    private var showingTranscriptPanel = false
    private var currentState: AICallState = .idle
    private var isMuted = false
    private var listeningFailed = false

    internal init(robotUserID: String, config: AICallConfig) {
        self.robotUserID = robotUserID
        self.config = config
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        controller?.release()
    }

    internal func viewDidLoad() {
        setupViews()
        activateConstraints()
        renderState(.idle)
        observeNotifications()
        UIApplication.shared.isIdleTimerDisabled = true
        ensureMicrophonePermission()
    }

    internal func viewDidDisappear(_ animated: Bool) {
        if isBeingDismissed {
            UIApplication.shared.isIdleTimerDisabled = false
            controller?.release()
            controller = nil
        }
    }

    private func setupViews() {
        view.backgroundColor = UIColor(red: 0x12 / 255.0, green: 0x14 / 255.0, blue: 0x17 / 255.0, alpha: 1)

        modePillLabel.text = LocalizedChatString("DemoAICallModeFree")
        modePillLabel.font = .systemFont(ofSize: 14)
        modePillLabel.textColor = .white
        modePillLabel.textAlignment = .center
        modePillLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        modePillLabel.layer.cornerRadius = 16
        modePillLabel.clipsToBounds = true
        topBar.addSubview(modePillLabel)

        middleStack.axis = .vertical
        middleStack.distribution = .fill
        middleStack.addArrangedSubview(orbContainer)
        middleStack.addArrangedSubview(transcriptContainer)
        transcriptContainer.isHidden = true

        orbContainer.addSubview(orbView)

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = UIColor(red: 0xB8 / 255.0, green: 0xBD / 255.0, blue: 0xC4 / 255.0, alpha: 1)
        statusLabel.textAlignment = .center

        buttonRow.axis = .horizontal
        buttonRow.spacing = Self.buttonSpacing
        buttonRow.alignment = .center
        buttonRow.addArrangedSubview(micButton)
        buttonRow.addArrangedSubview(subtitleButton)
        buttonRow.addArrangedSubview(hangupButton)

        configureCircleButton(micButton, icon: "mic.fill", background: UIColor.white.withAlphaComponent(0.12))
        configureCircleButton(subtitleButton, icon: "captions.bubble.fill", background: UIColor.white.withAlphaComponent(0.12))
        configureCircleButton(hangupButton, icon: "phone.down.fill", background: .systemRed)
        micButton.addTarget(self, action: #selector(handleMicTapped), for: .touchUpInside)
        subtitleButton.addTarget(self, action: #selector(handleSubtitleTapped), for: .touchUpInside)
        hangupButton.addTarget(self, action: #selector(handleHangupTapped), for: .touchUpInside)
        micButton.accessibilityLabel = "mic"
        subtitleButton.accessibilityLabel = "subtitle"
        hangupButton.accessibilityLabel = LocalizedChatString("DemoAICallHangup")

        disclaimerLabel.text = LocalizedChatString("DemoAICallDisclaimer")
        disclaimerLabel.font = .systemFont(ofSize: 11)
        disclaimerLabel.textColor = UIColor(red: 0x6E / 255.0, green: 0x74 / 255.0, blue: 0x7C / 255.0, alpha: 1)
        disclaimerLabel.textAlignment = .center

        view.addSubview(topBar)
        view.addSubview(middleStack)
        view.addSubview(statusLabel)
        view.addSubview(buttonRow)
        view.addSubview(disclaimerLabel)
    }

    private func configureCircleButton(_ button: UIButton, icon: String, background: UIColor) {
        button.setImage(
            UIImage(systemName: icon)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
                .withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        button.tintColor = .white
        button.backgroundColor = background
        button.layer.cornerRadius = Self.buttonSize / 2
        button.clipsToBounds = true
    }

    private func activateConstraints() {
        topBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.topBarHeight)
        }
        modePillLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(32)
            make.width.greaterThanOrEqualTo(88)
        }

        disclaimerLabel.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.leading.trailing.equalToSuperview()
        }
        buttonRow.snp.makeConstraints { make in
            make.bottom.equalTo(disclaimerLabel.snp.top).offset(-12)
            make.centerX.equalToSuperview()
            make.height.equalTo(Self.buttonSize)
        }
        [micButton, subtitleButton, hangupButton].forEach {
            $0.snp.makeConstraints { make in
                make.width.height.equalTo(Self.buttonSize)
            }
        }
        statusLabel.snp.makeConstraints { make in
            make.bottom.equalTo(buttonRow.snp.top).offset(-32)
            make.leading.trailing.equalToSuperview()
        }
        middleStack.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(statusLabel.snp.top)
        }
        orbView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            orbWidthConstraint = make.width.equalTo(Self.orbSizeFull).constraint
            orbHeightConstraint = make.height.equalTo(Self.orbSizeFull).constraint
        }
    }

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func ensureMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            startController()
        case .denied:
            WindowToastManager.shared.info(LocalizedChatString("DemoAICallPermissionDenied"))
            dismiss(animated: true)
        default:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.startController()
                    } else {
                        WindowToastManager.shared.info(LocalizedChatString("DemoAICallPermissionDenied"))
                        self.dismiss(animated: true)
                    }
                }
            }
        }
    }

    private func startController() {
        guard controller == nil else { return }
        let controller = AICallController(robotUserID: robotUserID, delegate: self, config: config)
        guard controller.start() else {
            dismiss(animated: true)
            return
        }
        self.controller = controller
    }

    @objc private func handleMicTapped() {
        if listeningFailed, !isMuted {
            controller?.retryListening()
            return
        }
        isMuted = !isMuted
        micButton.setImage(
            UIImage(systemName: isMuted ? "mic.slash.fill" : "mic.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
                .withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        controller?.setMuted(isMuted)
        renderState(currentState)
    }

    @objc private func handleSubtitleTapped() {
        subtitleVisible = !subtitleVisible
        subtitleButton.setImage(
            UIImage(systemName: subtitleVisible ? "captions.bubble.fill" : "captions.bubble")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
                .withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        applySubtitleVisibility()
    }

    @objc private func handleHangupTapped() {
        dismiss(animated: true)
    }

    @objc private func handleDidEnterBackground() {
        controller?.pause()
    }

    @objc private func handleWillEnterForeground() {
        controller?.resume()
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            controller?.pause()
        case .ended:
            controller?.resume()
        @unknown default:
            break
        }
    }

    private func shouldShowTranscriptPanel() -> Bool {
        subtitleVisible && latestEntries.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func applySubtitleVisibility() {
        let showPanel = shouldShowTranscriptPanel()
        if showPanel, transcriptView == nil {
            let transcriptView = AICallTranscriptView()
            transcriptContainer.addSubview(transcriptView)
            transcriptView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            transcriptView.submit(latestEntries)
            self.transcriptView = transcriptView
        }
        guard showPanel != showingTranscriptPanel else { return }
        showingTranscriptPanel = showPanel
        resizeOrb(compact: showPanel)
    }

    private func resizeOrb(compact: Bool) {
        transcriptContainer.isHidden = !compact
        let orbSize = compact ? Self.orbSizeCompact : Self.orbSizeFull
        orbWidthConstraint?.update(offset: orbSize)
        orbHeightConstraint?.update(offset: orbSize)
        if compact, orbContainerHeightConstraint == nil {
            orbContainer.snp.makeConstraints { make in
                orbContainerHeightConstraint = make.height.equalTo(Self.orbCompactContainerHeight).constraint
            }
        } else if !compact {
            orbContainerHeightConstraint?.deactivate()
            orbContainerHeightConstraint = nil
        }
        UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            AICallLog("[AICallUI] layout compact=\(compact) containerHidden=\(self.transcriptContainer.isHidden) containerFrame=\(self.transcriptContainer.frame) tableFrame=\(self.transcriptView?.frame ?? .zero)")
        }
    }

    private func renderState(_ state: AICallState) {
        currentState = state
        let showMuted = isMuted && (state == .listening || state == .idle)
        orbView.setState(showMuted ? .listening : state)
        let key: String
        if showMuted {
            key = "DemoAICallMuted"
        } else if listeningFailed {
            key = "DemoAICallStartFailedRetry"
        } else {
            switch state {
            case .listening, .idle:
                key = "DemoAICallListening"
            case .thinking:
                key = "DemoAICallThinking"
            case .speaking:
                key = "DemoAICallSpeaking"
            }
        }
        statusLabel.text = LocalizedChatString(key)
    }
}

extension AICallViewControllerImpl: AICallControllerDelegate {
    func callController(_ controller: AICallController, didChangeState state: AICallState) {
        if state != .idle {
            listeningFailed = false
        }
        renderState(state)
    }

    func callController(_ controller: AICallController, didChangeTranscript entries: [AICallTranscriptEntry]) {
        AICallLog("[AICallUI] transcript entries=\(entries.count) main=\(Thread.isMainThread) last=\"\(entries.last?.text.prefix(20) ?? "")\"")
        latestEntries = entries
        transcriptView?.submit(entries)
        applySubtitleVisibility()
    }

    func callController(_ controller: AICallController, didUpdateAudioLevel level: Float) {
        orbView.setLevel(level)
    }

    func callController(_ controller: AICallController, didEncounterError error: AICallError) {
        let key: String
        switch error {
        case .audioUnavailable:
            key = "DemoAICallAudioUnavailable"
        case .playbackUnavailable:
            key = "DemoAICallPlaybackUnavailable"
        case .asrStartFailed:
            key = "DemoAICallStartFailed"
        case .sendFailed:
            key = "DemoAICallSendFailed"
        case .replyTimeout:
            key = "DemoAICallReplyTimeout"
        }
        WindowToastManager.shared.info(LocalizedChatString(key))
    }

    func callControllerDidFailListening(_ controller: AICallController) {
        listeningFailed = true
        renderState(currentState)
    }
}
