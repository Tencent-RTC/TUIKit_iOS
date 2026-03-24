import UIKit
import SnapKit
import Combine
import AtomicXCore

/**
 * Device management panel content - reusable component
 *
 * APIs involved:
 * - DeviceStore.shared.openLocalCamera(isFront:completion:) - open the camera
 * - DeviceStore.shared.closeLocalCamera() - close the camera
 * - DeviceStore.shared.openLocalMicrophone(completion:) - open the microphone
 * - DeviceStore.shared.closeLocalMicrophone() - close the microphone
 * - DeviceStore.shared.switchCamera(isFront:) - switch between the front and rear cameras
 * - DeviceStore.shared.switchMirror(mirrorType:) - set the mirror mode
 * - DeviceStore.shared.updateVideoQuality(_:) - set the video quality
 * - DeviceStore.shared.state - device state observation (DeviceState)
 *
 * Pure UI component that depends only on the public DeviceStore API and is not coupled to a specific business scenario.
 * Reusable across all four stages (BasicStreaming /Interactive /MultiConnect /LivePK).
 */
class DeviceSettingView: UIView {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()

    /// camera switch
    private let cameraSwitch = SettingToggleRow(
        icon: "camera.fill",
        titleKey: "deviceSetting.camera"
    )

    /// microphone switch
    private let microphoneSwitch = SettingToggleRow(
        icon: "mic.fill",
        titleKey: "deviceSetting.microphone"
    )

    /// front/rear camera switch
    private let frontCameraSwitch = SettingToggleRow(
        icon: "camera.rotate.fill",
        titleKey: "deviceSetting.frontCamera"
    )

    /// mirror mode switch
    private let mirrorSwitch = SettingToggleRow(
        icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill",
        titleKey: "deviceSetting.mirror"
    )

    /// video quality selection
    private let videoQualityRow = SettingSegmentRow(
        icon: "slider.horizontal.3",
        titleKey: "deviceSetting.videoQuality",
        segments: ["360P", "540P", "720P", "1080P"]
    )

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupBindings()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }

        // Add the control rows to the stack view in order
        let rows: [UIView] = [
            cameraSwitch,
            createSeparator(),
            microphoneSwitch,
            createSeparator(),
            frontCameraSwitch,
            createSeparator(),
            mirrorSwitch,
            createSeparator(),
            videoQualityRow,
        ]

        rows.forEach { stackView.addArrangedSubview($0) }
    }

    private func setupBindings() {
        // Subscribe to device state changes and synchronize control states in real time
        DeviceStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceState in
                self?.updateUI(with: deviceState)
            }
            .store(in: &cancellables)
    }

    private func setupActions() {
        // camera switch
        cameraSwitch.onToggle = { isOn in
            if isOn {
                DeviceStore.shared.openLocalCamera(isFront: DeviceStore.shared.state.value.isFrontCamera, completion: nil)
            } else {
                DeviceStore.shared.closeLocalCamera()
            }
        }

        // microphone switch
        microphoneSwitch.onToggle = { isOn in
            if isOn {
                DeviceStore.shared.openLocalMicrophone(completion: nil)
            } else {
                DeviceStore.shared.closeLocalMicrophone()
            }
        }

        // front/rear camera switch
        frontCameraSwitch.onToggle = { isOn in
            DeviceStore.shared.switchCamera(isFront: isOn)
        }

        // mirror mode switch
        mirrorSwitch.onToggle = { isOn in
            DeviceStore.shared.switchMirror(mirrorType: isOn ? .enable : .disable)
        }

        // video quality selection
        videoQualityRow.onSegmentChanged = { index in
            let qualities: [VideoQuality] = [.quality360P, .quality540P, .quality720P, .quality1080P]
            if index < qualities.count {
                DeviceStore.shared.updateVideoQuality(qualities[index])
            }
        }
    }

    // MARK: - State Update

    private func updateUI(with state: DeviceState) {
        cameraSwitch.setOn(state.cameraStatus == .on)
        microphoneSwitch.setOn(state.microphoneStatus == .on)
        frontCameraSwitch.setOn(state.isFrontCamera)
        mirrorSwitch.setOn(state.localMirrorType == .enable)

        // Map video quality to the segment index
        let qualityIndex: Int
        switch state.localVideoQuality {
        case .quality360P:
            qualityIndex = 0
        case .quality540P:
            qualityIndex = 1
        case .quality720P:
            qualityIndex = 2
        case .quality1080P:
            qualityIndex = 3
        @unknown default:
            qualityIndex = 2
        }
        videoQualityRow.setSelectedIndex(qualityIndex)
    }

    // MARK: - Helpers

    private func createSeparator() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = .separator
        container.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(56)
            make.trailing.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        return container
    }
}

// MARK: - SettingToggleRow

/// Switch row component in device settings - icon and title on the left, switch on the right
class SettingToggleRow: UIView {

    var onToggle: ((Bool) -> Void)?

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let toggle: UISwitch = {
        let toggle = UISwitch()
        return toggle
    }()

    init(icon: String, titleKey: String) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = titleKey.localized
        setupUI()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(toggle)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
        }

        toggle.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        self.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
    }

    private func setupActions() {
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
    }

    @objc private func toggleChanged() {
        onToggle?(toggle.isOn)
    }

    func setOn(_ isOn: Bool) {
        guard toggle.isOn != isOn else { return }
        toggle.setOn(isOn, animated: false)
    }
}

// MARK: - SettingSegmentRow

/// Segmented row component in device settings - icon and title on the left, segmented control below
class SettingSegmentRow: UIView {

    var onSegmentChanged: ((Int) -> Void)?

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let segmentedControl: UISegmentedControl

    init(icon: String, titleKey: String, segments: [String]) {
        segmentedControl = UISegmentedControl(items: segments)
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = titleKey.localized
        setupUI()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(segmentedControl)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(14)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.centerY.equalTo(iconView)
        }

        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-14)
        }

        segmentedControl.selectedSegmentIndex = 2 // Default to 720P
    }

    private func setupActions() {
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    @objc private func segmentChanged() {
        onSegmentChanged?(segmentedControl.selectedSegmentIndex)
    }

    func setSelectedIndex(_ index: Int) {
        guard segmentedControl.selectedSegmentIndex != index else { return }
        segmentedControl.selectedSegmentIndex = index
    }
}
