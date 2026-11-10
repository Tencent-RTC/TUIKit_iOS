import SnapKit
import UIKit

final class VoiceLoungePauseView: UIView {
    var onResume: (() -> Void)?

    private let role: VoiceLoungeRole
    private let clock: VoiceLoungeLiveClock
    private var timer: Timer?
    private let titleLabel = UILabel()
    private let timerLabel = UILabel()
    private let resumeButton = UIButton(type: .system)
    private var renderedSeconds: Int?

    init(role: VoiceLoungeRole, clock: VoiceLoungeLiveClock) {
        self.role = role
        self.clock = clock
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        applyRole()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPaused(_ paused: Bool) {
        isHidden = !paused
        renderedSeconds = nil
        updateTimer()
    }

    private func setupViews() {
        addSubview(titleLabel)
        addSubview(timerLabel)
        addSubview(resumeButton)
    }

    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview().offset(-60)
            make.height.equalTo(29)
        }
        timerLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.height.equalTo(42)
        }
        resumeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-42)
            make.size.equalTo(CGSize(width: 205, height: 48))
        }
    }

    private func setupStyles() {
        isHidden = true
        backgroundColor = PauseViewStyle.background
        titleLabel.text = .pausedTitle
        titleLabel.textColor = .white
        titleLabel.font = PauseViewStyle.titleFont
        titleLabel.textAlignment = .center
        timerLabel.textColor = .white
        timerLabel.font = PauseViewStyle.timerFont
        timerLabel.textAlignment = .center
        timerLabel.text = "00:00"
        resumeButton.setTitle(.resume, for: .normal)
        resumeButton.setTitleColor(PauseViewStyle.resumeForeground, for: .normal)
        resumeButton.titleLabel?.font = PauseViewStyle.resumeFont
        resumeButton.backgroundColor = .white
        resumeButton.layer.cornerRadius = 10
        resumeButton.layer.shadowColor = UIColor.black.cgColor
        resumeButton.layer.shadowOpacity = 0.28
        resumeButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        resumeButton.layer.shadowRadius = 28
    }

    private func setupBindings() { resumeButton.addTarget(self, action: #selector(tapResume), for: .touchUpInside) }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateTimer()
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard !isHidden, role == .host, window != nil else { return }
        renderTimer()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.renderTimer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func applyRole() {
        let audience = role == .audience
        titleLabel.text = audience ? .pausedAudience : .pausedTitle
        timerLabel.isHidden = audience
        resumeButton.setTitle(audience ? .leaveRoom : .resume, for: .normal)
    }

    private func renderTimer() {
        let seconds = clock.currentPauseSeconds
        guard renderedSeconds != seconds else { return }
        renderedSeconds = seconds
        timerLabel.text = String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

extension VoiceLoungePauseView { @objc private func tapResume() { onResume?() } }

private enum PauseViewStyle {
    static let background: UIColor = UIColor.black.withAlphaComponent(0.9)
    static let resumeForeground: UIColor = UIColor(white: 0.067, alpha: 1)
    static let titleFont: UIFont = UIFont.systemFont(ofSize: 22)
    static let timerFont: UIFont = UIFont.systemFont(ofSize: 37)
    static let resumeFont: UIFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
}

private extension String {
    static var pausedAudience: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.living.paused_audience")
    }
    static var leaveRoom: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.leave_room") }
    static var pausedTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.paused_title") }
    static var resume: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.resume") }
}
