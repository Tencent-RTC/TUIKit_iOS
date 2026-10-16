import AtomicXCore
import Combine
import SnapKit
import UIKit

final class SettingsPanel: BottomSheetView {
    enum Mode {
        case preview
        case connected
    }

    var onDismiss: (() -> Void)?
    var onApply: (() -> Void)?

    private(set) var mode: Mode = .preview

    override var sheetHeight: CGFloat {
        let contentHeight = mode == .preview ? bounds.width + 152 : 190
        return contentHeight + safeAreaInsets.bottom
    }
    override var isDismissibleByTappingOutside: Bool { true }

    override func sheetWillDismiss() {
        stopPreview()
    }

    override func sheetDidDismiss() {
        onDismiss?()
    }

    private let backButton = UIButton(type: .custom)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let previewView = UIView()
    private let capStack = UIStackView()
    private let applyButton = UIButton(type: .custom)

    private let beautyCap = SettingCap(iconName: "livekit_living_setting_beauty", iconSize: CGSize(width: 18.05, height: 16.3))
    private let mirrorCap = SettingCap(iconName: "livekit_settings_mirror_off", iconSize: CGSize(width: 21, height: 22))
    private let flipCap = SettingCap(iconName: "livekit_living_setting_flip", iconSize: CGSize(width: 21, height: 18.5))

    private var deviceCancellable: AnyCancellable?
    private var isCameraTestActive = false
    private let beautyPanel = BeautyPanel()
    private let debouncedClick = DebouncedClick()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        bindDeviceStore()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSheetHeight(animated: false)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            deviceCancellable?.cancel()
            deviceCancellable = nil
            stopPreview()
            beautyPanel.removeFromSuperview()
        } else if deviceCancellable == nil {
            bindDeviceStore()
        }
    }

    func present(mode: Mode) {
        self.mode = mode
        applyMode()
        present()
        if mode == .preview {
            startPreview()
        }
    }

    func stopPreview() {
        guard isCameraTestActive else { return }
        isCameraTestActive = false
        DeviceStore.shared.stopCameraTest()
    }

    private func configureUI() {
        updateSheetHeight(animated: false)

        backButton.setImage(LiveKitResources.image(named: "livekit_coguest_chevron_down"), for: .normal)
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.transform = CGAffineTransform(rotationAngle: .pi / 2)
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        backButton.layer.cornerRadius = 18
        backButton.layer.masksToBounds = true
        backButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.debouncedClick.perform(for: self.backButton) { self.dismiss() }
        }, for: .touchUpInside)
        contentView.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(20)
            make.width.height.equalTo(36)
        }

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.text = LiveKitResources.localizedString("tuilivekit.player.coguest.settings.title")
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(24)
        }

        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.60)
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.text = LiveKitResources.localizedString("tuilivekit.player.coguest.settings.subtitle")
        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }

        previewView.backgroundColor = UIColor(red: 0.055, green: 0.098, blue: 0.196, alpha: 1)
        previewView.layer.cornerRadius = 20
        previewView.layer.masksToBounds = true
        contentView.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(64)
            make.trailing.equalToSuperview().offset(-64)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            make.height.equalTo(previewView.snp.width)
        }

        beautyCap.title = LiveKitResources.localizedString("tuilivekit.pusher.beautify")
        mirrorCap.title = LiveKitResources.localizedString("tuilivekit.pusher.mirror")
        flipCap.title = LiveKitResources.localizedString("tuilivekit.pusher.flip_camera")

        capStack.axis = .horizontal
        capStack.distribution = .equalSpacing
        capStack.alignment = .center
        [beautyCap, mirrorCap, flipCap].forEach(capStack.addArrangedSubview)
        contentView.addSubview(capStack)

        applyButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.coguest.apply"), for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.backgroundColor = UIColor(red: 0x3B / 255, green: 0x7B / 255, blue: 1, alpha: 1)
        applyButton.layer.cornerRadius = 22
        applyButton.layer.masksToBounds = true
        applyButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.debouncedClick.perform(for: self.applyButton) { self.onApply?() }
        }, for: .touchUpInside)
        contentView.addSubview(applyButton)

        applyMode()

        beautyCap.onTap = { [weak self] in
            guard let self else { return }
            self.debouncedClick.perform(for: self.beautyCap) { self.presentBeautyPanel() }
        }
        mirrorCap.onTap = { [weak self] in
            guard let self else { return }
            self.debouncedClick.perform(for: self.mirrorCap) { self.toggleMirror() }
        }
        flipCap.onTap = { [weak self] in
            guard let self else { return }
            self.debouncedClick.perform(for: self.flipCap) { self.flipCamera() }
        }
    }

    private func applyMode() {
        let showsPreview = mode == .preview
        previewView.isHidden = !showsPreview
        applyButton.isHidden = !showsPreview
        if !showsPreview {
            stopPreview()
        }
        capStack.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(56)
            if showsPreview {
                make.top.equalTo(previewView.snp.bottom).offset(20)
            } else {
                make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            }
            make.height.equalTo(76)
        }
        applyButton.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(capStack.snp.bottom).offset(24)
            make.height.equalTo(44)
        }
        updateSheetHeight(animated: false)
    }

    private func startPreview() {
        guard mode == .preview, !isCameraTestActive else { return }
        isCameraTestActive = true
        BeautyPreferences.restore()
        DeviceStore.shared.switchCamera(isFront: true)
        DeviceStore.shared.switchMirror(mirrorType: .enable)
        DeviceStore.shared.startCameraTest(cameraView: previewView, completion: nil)
    }

    private func bindDeviceStore() {
        deviceCancellable = DeviceStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceState in
                self?.applyDeviceState(deviceState)
            }
        applyDeviceState(DeviceStore.shared.state.value)
    }

    private func applyDeviceState(_ deviceState: DeviceState) {
        let mirrorEnabled = deviceState.localMirrorType != .disable
        mirrorCap.setIcon(name: mirrorEnabled ? "livekit_settings_mirror_on" : "livekit_settings_mirror_off")
        mirrorCap.isSelected = mirrorEnabled
    }

    private func toggleMirror() {
        let enabled = DeviceStore.shared.state.value.localMirrorType != .disable
        DeviceStore.shared.switchMirror(mirrorType: enabled ? .disable : .enable)
    }

    private func flipCamera() {
        let currentIsFront = DeviceStore.shared.state.value.isFrontCamera
        DeviceStore.shared.switchCamera(isFront: !currentIsFront)
    }

    private func presentBeautyPanel() {
        guard let host = superview else { return }
        if beautyPanel.superview !== host {
            beautyPanel.removeFromSuperview()
            host.addSubview(beautyPanel)
            beautyPanel.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        host.bringSubviewToFront(beautyPanel)
        beautyPanel.present()
    }
}

private final class SettingCap: UIControl {
    var title: String? {
        get { label.text }
        set { label.text = newValue }
    }
    var onTap: (() -> Void)?

    override var isSelected: Bool {
        didSet { updateBackground() }
    }

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let label = UILabel()
    private let iconSize: CGSize

    init(iconName: String, iconSize: CGSize) {
        self.iconSize = iconSize
        super.init(frame: .zero)

        iconContainer.isUserInteractionEnabled = false
        iconContainer.layer.cornerRadius = 24
        iconContainer.clipsToBounds = true
        addSubview(iconContainer)
        iconContainer.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(48)
        }

        iconView.image = LiveKitResources.image(named: iconName)
        iconView.contentMode = .scaleAspectFit
        iconContainer.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(iconSize.width)
            make.height.equalTo(iconSize.height)
        }

        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        addTarget(self, action: #selector(handlePressBegin), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handlePressEnd), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        updateBackground()
    }

    func setIcon(name: String) {
        iconView.image = LiveKitResources.image(named: name)
    }

    private func updateBackground() {
        iconContainer.backgroundColor = UIColor.white.withAlphaComponent(0.09)
    }

    @objc private func handlePressBegin() {
        UIView.animate(withDuration: 0.12) {
            self.iconContainer.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }

    @objc private func handlePressEnd() {
        UIView.animate(withDuration: 0.12) {
            self.iconContainer.transform = .identity
        }
    }

    @objc private func handleTap() {
        onTap?()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 60, height: 76)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
