import AtomicXCore
import TUIChatKit
import SnapKit
import UIKit

private final class SettingSubPageHeaderView: UIView {
    private static let horizontalPadding: CGFloat = 16

    private static let verticalPadding: CGFloat = 12

    private static let backButtonSize: CGFloat = 24

    private let backButton = ExpandedHitButton(type: .custom)

    private let titleLabel = UILabel()

    private let onBack: () -> Void

    init(title: String, onBack: @escaping () -> Void) {
        self.onBack = onBack
        super.init(frame: .zero)
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        let backImage = AtomicXChatResources.image(named: "contact_info_back")?.withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "chevron.left")?.withRenderingMode(.alwaysTemplate)
        backButton.setImage(backImage, for: .normal)
        backButton.tintColor = colors.textColorPrimary
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        addSubview(backButton)
        addSubview(titleLabel)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.backButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleBack() {
        onBack()
    }
}

private final class SettingEntryRowView: UIControl {
    private static let horizontalPadding: CGFloat = 16

    private static let verticalPadding: CGFloat = 12

    private static let arrowSpacing: CGFloat = 8

    private let titleLabel = UILabel()

    private let valueLabel = UILabel()

    private let arrowImageView = UIImageView()

    init(title: String) {
        super.init(frame: .zero)
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        valueLabel.font = .systemFont(ofSize: 16)
        valueLabel.textColor = colors.textColorPrimary
        valueLabel.lineBreakMode = .byTruncatingTail
        arrowImageView.image = AtomicXChatResources.image(named: "contact_info_arrow_right")?.withRenderingMode(.alwaysTemplate)
        arrowImageView.tintColor = colors.textColorTertiary
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(arrowImageView)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-Self.arrowSpacing)
            make.centerY.equalToSuperview()
        }
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }
}

// MARK: - 语音消息设置

final class VoiceMessageSettingViewController: UIViewController {
    private static let groupSpacerHeight: CGFloat = 10

    private lazy var cloneRow = SettingEntryRowView(title: LocalizedChatString("VoiceClone"))

    private lazy var selectRow = SettingEntryRowView(title: LocalizedChatString("VoiceSelect"))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        let header = SettingSubPageHeaderView(title: LocalizedChatString("VoiceMessageSettings")) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        let divider = UIView()
        divider.backgroundColor = TUIChatKitTheme.colors.strokeColorPrimary
        let spacer = UIView()
        spacer.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        view.addSubview(header)
        view.addSubview(spacer)
        view.addSubview(cloneRow)
        view.addSubview(divider)
        view.addSubview(selectRow)
        header.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        spacer.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.groupSpacerHeight)
        }
        cloneRow.snp.makeConstraints { make in
            make.top.equalTo(spacer.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        divider.snp.makeConstraints { make in
            make.top.equalTo(cloneRow.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        selectRow.snp.makeConstraints { make in
            make.top.equalTo(divider.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        cloneRow.addTarget(self, action: #selector(handleCloneTapped), for: .touchUpInside)
        selectRow.addTarget(self, action: #selector(handleSelectTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let name = VoiceMessageConfig.shared.getSelectedVoiceName()
        selectRow.setValue(name.isEmpty ? LocalizedChatString("voice_message_voice_default") : name)
    }

    @objc private func handleCloneTapped() {
        navigationController?.pushViewController(VoiceCloneViewController(), animated: true)
    }

    @objc private func handleSelectTapped() {
        navigationController?.pushViewController(VoiceSelectViewController(), animated: true)
    }
}

// MARK: - 音色选择

final class VoiceSelectViewController: UIViewController {
    private static let badgeFontSize: CGFloat = 10

    private static let badgeCornerRadius: CGFloat = 4

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var defaultVoices: [CustomVoiceItem] = []

    private var customVoices: [CustomVoiceItem] = []

    private var selectedId = ""

    private var isLoading = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        let header = SettingSubPageHeaderView(title: LocalizedChatString("VoiceSelect")) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        view.addSubview(header)
        view.addSubview(tableView)
        header.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        tableView.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VoiceCell")
        defaultVoices = VoiceItemProvider.defaultVoiceList()
        selectedId = VoiceMessageConfig.shared.getSelectedVoiceId()
        loadCustomVoices()
    }

    private func loadCustomVoices() {
        isLoading = true
        AiMediaProcessManager.getCustomVoiceList(onSuccess: { [weak self] list in
            self?.isLoading = false
            self?.customVoices = list
            self?.tableView.reloadData()
        }, onFailure: { [weak self] _, _ in
            self?.isLoading = false
            self?.customVoices = []
            self?.tableView.reloadData()
        })
    }

    private func selectVoice(_ voice: CustomVoiceItem) {
        VoiceMessageConfig.shared.setSelectedVoice(id: voice.voiceId, name: voice.name)
        selectedId = voice.voiceId
        tableView.reloadData()
    }

    private func deleteVoice(_ voice: CustomVoiceItem) {
        AiMediaProcessManager.deleteCustomVoice(voiceId: voice.voiceId, onSuccess: { [weak self] in
            guard let self = self else { return }
            self.customVoices.removeAll { $0.voiceId == voice.voiceId }
            if self.selectedId == voice.voiceId {
                VoiceMessageConfig.shared.setSelectedVoice(id: "", name: "")
                self.selectedId = ""
            }
            self.tableView.reloadData()
        }, onFailure: { [weak self] _, _ in
            let alert = UIAlertController(title: LocalizedChatString("VoiceDeleteFailed"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: LocalizedChatString("AlertConfirm"), style: .default))
            self?.present(alert, animated: true)
        })
    }
}

extension VoiceSelectViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return defaultVoices.count
        }
        return max(customVoices.count, isLoading ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? LocalizedChatString("VoiceDefaultGroup") : LocalizedChatString("VoiceCustomGroup")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceCell", for: indexPath)
        let colors = TUIChatKitTheme.colors
        cell.backgroundColor = colors.bgColorOperate
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        if indexPath.section == 1 && customVoices.isEmpty && !isLoading {
            let emptyLabel = UILabel()
            emptyLabel.text = LocalizedChatString("VoiceCustomEmpty")
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textColor = colors.textColorTertiary
            cell.contentView.addSubview(emptyLabel)
            emptyLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(16)
                make.centerY.equalToSuperview()
            }
            return cell
        }
        let voice = indexPath.section == 0 ? defaultVoices[indexPath.row] : customVoices[indexPath.row]
        let nameLabel = UILabel()
        nameLabel.text = voice.name
        nameLabel.font = .systemFont(ofSize: 16)
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        cell.contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
        }
        var trailingView: UIView = nameLabel
        if indexPath.section == 1 {
            let badgeLabel = UILabel()
            badgeLabel.text = LocalizedChatString("VoiceCustomBadge")
            badgeLabel.font = .systemFont(ofSize: Self.badgeFontSize)
            badgeLabel.textColor = colors.textColorButton
            badgeLabel.backgroundColor = colors.buttonColorPrimaryDefault
            badgeLabel.layer.cornerRadius = Self.badgeCornerRadius
            badgeLabel.layer.masksToBounds = true
            let idLabel = UILabel()
            idLabel.text = voice.voiceId
            idLabel.font = .systemFont(ofSize: 12)
            idLabel.textColor = colors.textColorTertiary
            idLabel.lineBreakMode = .byTruncatingTail
            cell.contentView.addSubview(badgeLabel)
            cell.contentView.addSubview(idLabel)
            badgeLabel.snp.makeConstraints { make in
                make.leading.equalTo(nameLabel.snp.trailing).offset(8)
                make.centerY.equalToSuperview()
            }
            idLabel.snp.makeConstraints { make in
                make.leading.equalTo(badgeLabel.snp.trailing).offset(8)
                make.centerY.equalToSuperview()
            }
            trailingView = idLabel
        }
        if voice.voiceId == selectedId {
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
            checkmark.tintColor = colors.textColorLink
            cell.contentView.addSubview(checkmark)
            checkmark.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(trailingView.snp.trailing).offset(8)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && customVoices.isEmpty {
            return
        }
        let voice = indexPath.section == 0 ? defaultVoices[indexPath.row] : customVoices[indexPath.row]
        selectVoice(voice)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, !customVoices.isEmpty else { return nil }
        let voice = customVoices[indexPath.row]
        let deleteAction = UIContextualAction(style: .destructive, title: LocalizedChatString("VoiceDelete")) { [weak self] _, _, completion in
            self?.deleteVoice(voice)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - 音色克隆

private final class WaveformView: UIView {
    private static let barCount = 24

    private static let barWidth: CGFloat = 3

    private static let barSpacing: CGFloat = 3

    private static let barCornerRadius: CGFloat = 1.5

    private static let maxBarHeight: CGFloat = 36

    private static let minBarHeight: CGFloat = 3

    private var bars: [UIView] = []

    private var currentSamples: [CGFloat] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        backgroundColor = TUIChatKitTheme.colors.bgColorInput
        for _ in 0 ..< Self.barCount {
            let bar = UIView()
            bar.backgroundColor = TUIChatKitTheme.colors.buttonColorPrimaryDefault
            bar.layer.cornerRadius = Self.barCornerRadius
            addSubview(bar)
            bars.append(bar)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        relayoutBars()
    }

    func updateSamples(_ samples: [CGFloat]) {
        currentSamples = samples
        relayoutBars()
    }

    private func relayoutBars() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let centerY = bounds.height / 2
        let totalWidth = CGFloat(Self.barCount) * Self.barWidth + CGFloat(Self.barCount - 1) * Self.barSpacing
        let startX = (bounds.width - totalWidth) / 2
        for (index, bar) in bars.enumerated() {
            let sample = index < currentSamples.count ? currentSamples[index] : 0.1
            let height = max(Self.minBarHeight, sample * Self.maxBarHeight)
            let x = startX + CGFloat(index) * (Self.barWidth + Self.barSpacing)
            bar.frame = CGRect(x: x, y: centerY - height / 2, width: Self.barWidth, height: height)
        }
    }
}

final class VoiceCloneViewController: UIViewController {
    private static let minCloneSeconds = 3

    private static let maxCloneMs = 30000

    private static let recordButtonSize: CGFloat = 64

    private static let horizontalPadding: CGFloat = 16

    private let scrollView = UIScrollView()

    private let contentStack = UIStackView()

    private let tipLabel = UILabel()

    private let readingTitleLabel = UILabel()

    private let sampleLabel = UILabel()

    private let waveformView = WaveformView()

    private let timeLabel = UILabel()

    private let recordButton = UIButton(type: .custom)

    private let statusLabel = UILabel()

    private let authTipLabel = UILabel()

    private let nameField = UITextField()

    private let submitButton = UIButton(type: .custom)

    private let submitIndicator = UIActivityIndicatorView(style: .medium)

    private var isRecording = false

    private var isSubmitting = false

    private var recordedPath: String?

    private var durationMs = 0

    private var powerSamples: [CGFloat] = Array(repeating: 0.1, count: 24)

    private var statusKey = "VoiceCloneStart"

    private var waveformTimer: Timer?

    private var latestRealPower: CGFloat?

    private var waveformPhase: CGFloat = 0

    private var canSubmit: Bool {
        return recordedPath != nil && !isSubmitting && !isRecording
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        let header = SettingSubPageHeaderView(title: LocalizedChatString("VoiceClone")) { [weak self] in
            self?.cancelRecordingIfNeeded()
            self?.navigationController?.popViewController(animated: true)
        }
        view.addSubview(header)
        view.addSubview(scrollView)
        header.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        scrollView.addSubview(contentStack)
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 20, left: Self.horizontalPadding, bottom: 20, right: Self.horizontalPadding))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-Self.horizontalPadding * 2)
        }
        buildContent()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelRecordingIfNeeded()
    }

    private func buildContent() {
        let colors = TUIChatKitTheme.colors
        tipLabel.text = LocalizedChatString("VoiceCloneTip")
        tipLabel.font = .systemFont(ofSize: 14)
        tipLabel.textColor = colors.textColorSecondary
        tipLabel.numberOfLines = 0
        readingTitleLabel.text = LocalizedChatString("VoiceCloneReadingTitle")
        readingTitleLabel.font = .systemFont(ofSize: 16)
        readingTitleLabel.textColor = colors.textColorPrimary
        readingTitleLabel.textAlignment = .center
        readingTitleLabel.numberOfLines = 0
        sampleLabel.text = "“\(LocalizedChatString("VoiceCloneSample"))”"
        sampleLabel.font = .systemFont(ofSize: 16)
        sampleLabel.textColor = colors.textColorPrimary
        sampleLabel.textAlignment = .center
        sampleLabel.numberOfLines = 0
        waveformView.snp.makeConstraints { make in
            make.height.equalTo(56)
        }
        waveformView.updateSamples(powerSamples)
        timeLabel.text = "00:00"
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        timeLabel.textColor = colors.textColorPrimary
        timeLabel.textAlignment = .center
        recordButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        recordButton.tintColor = colors.textColorButton
        recordButton.backgroundColor = colors.buttonColorPrimaryDefault
        recordButton.layer.cornerRadius = Self.recordButtonSize / 2
        recordButton.snp.makeConstraints { make in
            make.width.height.equalTo(Self.recordButtonSize)
        }
        recordButton.addTarget(self, action: #selector(toggleRecord), for: .touchUpInside)
        let recordButtonContainer = UIView()
        recordButtonContainer.addSubview(recordButton)
        recordButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = colors.textColorSecondary
        statusLabel.textAlignment = .center
        statusLabel.text = LocalizedChatString(statusKey)
        authTipLabel.text = LocalizedChatString("VoiceCloneAuthTip")
        authTipLabel.font = .systemFont(ofSize: 12)
        authTipLabel.textColor = colors.textColorTertiary
        authTipLabel.numberOfLines = 0
        nameField.placeholder = LocalizedChatString("VoiceCloneNameHint")
        nameField.font = .systemFont(ofSize: 16)
        nameField.textColor = colors.textColorPrimary
        nameField.backgroundColor = colors.bgColorInput
        nameField.layer.cornerRadius = 8
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        nameField.leftViewMode = .always
        nameField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        nameField.rightViewMode = .always
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        submitButton.setTitle(LocalizedChatString("VoiceCloneSubmit"), for: .normal)
        submitButton.setTitleColor(colors.textColorButton, for: .normal)
        submitButton.titleLabel?.font = .systemFont(ofSize: 16)
        submitButton.layer.cornerRadius = 8
        submitButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        submitButton.addTarget(self, action: #selector(submit), for: .touchUpInside)
        submitIndicator.color = colors.textColorButton
        submitIndicator.hidesWhenStopped = true
        submitButton.addSubview(submitIndicator)
        submitIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        refreshSubmitButton()

        contentStack.addArrangedSubview(tipLabel)
        contentStack.addArrangedSubview(readingTitleLabel)
        contentStack.addArrangedSubview(sampleLabel)
        contentStack.addArrangedSubview(waveformView)
        contentStack.addArrangedSubview(timeLabel)
        contentStack.addArrangedSubview(recordButtonContainer)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(authTipLabel)
        contentStack.addArrangedSubview(nameField)
        contentStack.addArrangedSubview(submitButton)

        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        backgroundTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(backgroundTap)
    }

    private func refreshSubmitButton() {
        let colors = TUIChatKitTheme.colors
        submitButton.isEnabled = canSubmit
        submitButton.backgroundColor = canSubmit ? colors.buttonColorPrimaryDefault : colors.buttonColorPrimaryDisabled
    }

    private func refreshRecordButton() {
        let colors = TUIChatKitTheme.colors
        recordButton.setImage(UIImage(systemName: isRecording ? "stop.fill" : "mic.fill"), for: .normal)
        recordButton.backgroundColor = isRecording ? colors.textColorError : colors.buttonColorPrimaryDefault
    }

    private func updateTimeLabel() {
        let totalSec = durationMs / 1000
        timeLabel.text = String(format: "%02d:%02d", totalSec / 60, totalSec % 60)
    }

    @objc private func handleBackgroundTapped() {
        view.endEditing(true)
    }

    @objc private func toggleRecord() {
        guard !isSubmitting else { return }
        if isRecording {
            AudioRecorder.sharedRecorder.stopRecord()
            return
        }
        recordedPath = nil
        durationMs = 0
        powerSamples = Array(repeating: 0.1, count: 24)
        latestRealPower = nil
        waveformPhase = 0
        updateTimeLabel()
        waveformView.updateSamples(powerSamples)
        refreshSubmitButton()
        let recorder = AudioRecorder.sharedRecorder
        recorder.onRecordTime = { [weak self] timeMs in
            DispatchQueue.main.async {
                self?.durationMs = timeMs
                self?.updateTimeLabel()
            }
        }
        recorder.onPowerLevel = { [weak self] power in
            self?.latestRealPower = min(1, max(0.1, CGFloat(power + 60) / 60))
        }
        recorder.onRecordingComplete = { [weak self] resultCode, filePath, durationSec in
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.stopWaveformTimer()
                self?.refreshRecordButton()
                self?.handleRecordComplete(resultCode: resultCode, filePath: filePath, durationSec: durationSec)
            }
        }
        isRecording = true
        refreshRecordButton()
        statusKey = "VoiceCloneStop"
        statusLabel.text = LocalizedChatString(statusKey)
        startWaveformTimer()
        recorder.startRecord(minDurationMs: Self.minCloneSeconds * 1000, maxDurationMs: Self.maxCloneMs)
    }

    private func startWaveformTimer() {
        stopWaveformTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.waveformPhase += 0.6
                let next: CGFloat
                if let realPower = self.latestRealPower {
                    next = realPower
                } else {
                    let sine = (sin(self.waveformPhase) + 1) / 2
                    let jitter = CGFloat.random(in: -0.15 ... 0.15)
                    next = min(1, max(0.1, 0.25 + sine * 0.6 + jitter))
                }
                self.powerSamples.append(next)
                if self.powerSamples.count > 24 {
                    self.powerSamples.removeFirst(self.powerSamples.count - 24)
                }
                self.waveformView.updateSamples(self.powerSamples)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        waveformTimer = timer
    }

    private func stopWaveformTimer() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        latestRealPower = nil
    }

    private func handleRecordComplete(resultCode: AudioRecordResultCode, filePath: String, durationSec: Int) {
        switch resultCode {
        case .success, .exceedMaxDuration:
            if durationSec >= Self.minCloneSeconds && !filePath.isEmpty {
                recordedPath = filePath
                durationMs = durationSec * 1000
                statusKey = "VoiceCloneDone"
            } else {
                resetRecordingState()
                showAlert(LocalizedChatString("VoiceCloneTooShortMessage"))
            }
        case .errorLessThanMinDuration:
            resetRecordingState()
            showAlert(LocalizedChatString("VoiceCloneTooShortMessage"))
        case .errorRecordPermissionDenied:
            resetRecordingState()
            showAlert(LocalizedChatString("VoiceClonePermissionDenied"))
        case .errorCancel:
            resetRecordingState()
        default:
            resetRecordingState()
            showAlert(LocalizedChatString("VoiceCloneRecordFailed"))
        }
        statusLabel.text = LocalizedChatString(statusKey)
        updateTimeLabel()
        refreshSubmitButton()
    }

    private func resetRecordingState() {
        recordedPath = nil
        durationMs = 0
        statusKey = "VoiceCloneStart"
    }

    private func cancelRecordingIfNeeded() {
        guard isRecording else { return }
        AudioRecorder.sharedRecorder.cancelRecord()
        isRecording = false
        stopWaveformTimer()
        refreshRecordButton()
    }

    @objc private func submit() {
        guard let path = recordedPath, !path.isEmpty else {
            showAlert(LocalizedChatString("VoiceCloneEmptyRecord"))
            return
        }
        guard !isSubmitting else { return }
        let trimmedName = (nameField.text ?? "").trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? LocalizedChatString("VoiceCloneDefaultName") : trimmedName
        isSubmitting = true
        submitButton.setTitle(nil, for: .normal)
        submitIndicator.startAnimating()
        refreshSubmitButton()
        AiMediaProcessManager.voiceClone(filePath: path, voiceName: name, onSuccess: { [weak self] voiceId in
            guard let self = self else { return }
            self.isSubmitting = false
            self.submitIndicator.stopAnimating()
            self.submitButton.setTitle(LocalizedChatString("VoiceCloneSubmit"), for: .normal)
            self.refreshSubmitButton()
            VoiceMessageConfig.shared.setSelectedVoice(id: voiceId, name: name)
            let alert = UIAlertController(
                title: LocalizedChatString("VoiceCloneSuccessTitle"),
                message: LocalizedChatString("VoiceCloneSuccessMessage"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: LocalizedChatString("AlertConfirm"), style: .default) { _ in
                self.navigationController?.popViewController(animated: true)
            })
            self.present(alert, animated: true)
        }, onFailure: { [weak self] _, _ in
            guard let self = self else { return }
            self.isSubmitting = false
            self.submitIndicator.stopAnimating()
            self.submitButton.setTitle(LocalizedChatString("VoiceCloneSubmit"), for: .normal)
            self.refreshSubmitButton()
            self.showAlert(LocalizedChatString("VoiceCloneFailed"))
        })
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LocalizedChatString("AlertConfirm"), style: .default))
        present(alert, animated: true)
    }
}

extension VoiceCloneViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
