import SnapKit
import UIKit

final class PusherPrepareView: UIView {
    // MARK: - Outputs

    var onCountdownFinished: ((String) -> Void)?
    var onExit: (() -> Void)?
    var onSelectCover: ((String) -> Void)?
    var onTitleChanged: ((String) -> Void)?
    var onFlipCamera: (() -> Void)?
    var onShowBeauty: (() -> Void)?
    var onRefreshSettings: (() -> Void)?
    weak var settingsActionHandler: PusherSettingsActionHandling? {
        didSet { moreSettingsView.actionHandler = settingsActionHandler }
    }

    // MARK: - Child Views

    private let editingContentView = UIView()
    private let shadingView = PusherStageShadingView()
    private let liveInfoEditorView = PusherLiveInfoEditorView()
    private let exitButton = UIButton(type: .system)
    private let settingsActionsStack = UIStackView()
    private let startButton = GradientButton(type: .custom)
    private let coverPickerView = PusherCoverPickerView()
    private let moreSettingsView = PrepareMoreSettingsView()
    private let countdownView = CountdownView()

    // MARK: - Countdown State

    private var countdownTimer: Timer?
    private var countdownValue = 0
    private var countdownTitle: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        countdownTimer?.invalidate()
    }
}

// MARK: - Stage Input

extension PusherPrepareView {
    func bind(title: String, coverURL: String) {
        guard countdownTimer == nil else { return }
        liveInfoEditorView.bind(title: title, coverURL: coverURL)
        coverPickerView.bind(selectedURL: coverURL)
    }

    func bind(settings: PusherSettingsState) {
        moreSettingsView.bind(settings)
    }

    func deactivate() {
        stopCountdown()
        setCountdownPresented(false)
    }
}

// MARK: - UI Assembly

private extension PusherPrepareView {
    private func configureUI() {
        configureHierarchy()
        configureControls()
        bindActions()
        configureLayout()
    }

    private func configureHierarchy() {
        addSubview(editingContentView)
        editingContentView.addSubview(shadingView)
        editingContentView.addSubview(liveInfoEditorView)
        editingContentView.addSubview(exitButton)
        editingContentView.addSubview(settingsActionsStack)
        editingContentView.addSubview(startButton)
        addSubview(moreSettingsView)
        addSubview(coverPickerView)
        countdownView.isHidden = true
        addSubview(countdownView)
    }

    private func configureControls() {
        exitButton.setTitle("×", for: .normal)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.titleLabel?.font = PusherPrepareViewTypography.exitButtonFont
        exitButton.backgroundColor = .clear
        exitButton.addTarget(self, action: #selector(exit), for: .touchUpInside)

        let beauty = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.beautify"), assetName: "livekit_prepare_beauty", style: .prepare)
        let flip = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.flip_camera"), assetName: "livekit_prepare_flip", style: .prepare)
        let more = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.common.more"), assetName: "livekit_prepare_more", style: .prepare)
        beauty.addTarget(self, action: #selector(requestBeauty), for: .touchUpInside)
        flip.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
        more.addTarget(self, action: #selector(showMoreSettings), for: .touchUpInside)

        [beauty, flip, more].forEach(settingsActionsStack.addArrangedSubview)
        settingsActionsStack.axis = .horizontal
        settingsActionsStack.spacing = 32
        settingsActionsStack.alignment = .center

        startButton.setTitle(LiveKitResources.localizedString("tuilivekit.pusher.prepare.start_live"), for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = PusherPrepareViewTypography.startButtonFont
        startButton.layer.cornerRadius = 26
        startButton.layer.shadowColor = LiveTheme.Color.brandDeepBlue.cgColor
        startButton.layer.shadowOpacity = 0.4
        startButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        startButton.layer.shadowRadius = 14
        startButton.addTarget(self, action: #selector(start), for: .touchUpInside)
    }

    private func bindActions() {
        liveInfoEditorView.onTitleChanged = { [weak self] title in
            self?.onTitleChanged?(title)
        }
        liveInfoEditorView.onChangeCover = { [weak self] in
            guard let self else { return }
            endEditing(true)
            coverPickerView.present()
        }
        coverPickerView.onSelect = { [weak self] coverURL in
            self?.onSelectCover?(coverURL)
        }
        countdownView.onCancel = { [weak self] in
            self?.cancelCountdown()
        }
    }

    private func configureLayout() {
        editingContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        shadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        liveInfoEditorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(85).priority(.high)
            make.top.greaterThanOrEqualTo(exitButton.snp.bottom).offset(32)
            make.bottom.lessThanOrEqualTo(settingsActionsStack.snp.top).offset(-40)
        }
        exitButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide.snp.leading).offset(8)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(4)
            make.size.equalTo(44)
        }
        settingsActionsStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
            make.bottom.equalTo(startButton.snp.top).offset(-46)
        }
        startButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-7)
            make.height.equalTo(52)
        }
        moreSettingsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        coverPickerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        countdownView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - Countdown

private extension PusherPrepareView {
    @objc private func start() {
        guard countdownTimer == nil else { return }
        endEditing(true)
        countdownTitle = liveInfoEditorView.title
        countdownValue = 3
        setCountdownPresented(true)
        countdownView.show(number: countdownValue)

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.advanceCountdown()
        }
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceCountdown() {
        guard countdownTimer != nil else { return }
        if countdownValue > 1 {
            countdownValue -= 1
            countdownView.show(number: countdownValue)
        } else {
            let title = countdownTitle ?? liveInfoEditorView.title
            stopCountdown()
            setCountdownPresented(false)
            onCountdownFinished?(title)
        }
    }

    private func cancelCountdown() {
        stopCountdown()
        setCountdownPresented(false)
    }

    private func setCountdownPresented(_ isPresented: Bool) {
        editingContentView.isHidden = isPresented
        countdownView.isHidden = !isPresented
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = 0
        countdownTitle = nil
        countdownView.stopAnimation()
    }
}

// MARK: - User Actions

private extension PusherPrepareView {
    @objc private func flipCamera() {
        onFlipCamera?()
    }

    @objc private func showMoreSettings() {
        onRefreshSettings?()
        moreSettingsView.show()
    }

    @objc private func requestBeauty() {
        onShowBeauty?()
    }

    @objc private func exit() {
        onExit?()
    }
}

private final class GradientButton: UIButton {
    private let borderGradientLayer = CAGradientLayer()
    private let innerGradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        borderGradientLayer.colors = [
            LiveTheme.Color.brandDeepBlue.cgColor,
            LiveTheme.Color.brandBlue.cgColor,
            LiveTheme.Color.brandCyan.cgColor,
        ]
        borderGradientLayer.locations = [0, 0.5, 1]
        borderGradientLayer.startPoint = CGPoint(x: 0, y: 1)
        borderGradientLayer.endPoint = CGPoint(x: 1, y: 0)

        innerGradientLayer.colors = [
            LiveTheme.Color.brandDeepBlue.withAlphaComponent(0.92).cgColor,
            LiveTheme.Color.brandBlue.withAlphaComponent(0.8).cgColor,
        ]
        innerGradientLayer.startPoint = CGPoint(x: 0, y: 1)
        innerGradientLayer.endPoint = CGPoint(x: 1, y: 0)
        layer.insertSublayer(borderGradientLayer, at: 0)
        layer.insertSublayer(innerGradientLayer, above: borderGradientLayer)
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderGradientLayer.frame = bounds
        borderGradientLayer.cornerRadius = bounds.height / 2
        innerGradientLayer.frame = bounds.insetBy(dx: 2, dy: 2)
        innerGradientLayer.cornerRadius = max(0, (bounds.height - 4) / 2)
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherPrepareViewTypography {
    static let exitButtonFont: UIFont = UIFont.systemFont(ofSize: 30, weight: .light)
    static let startButtonFont: UIFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
}
