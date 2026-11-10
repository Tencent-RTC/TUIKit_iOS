import AtomicXCore
import Combine
import TUICore
import TXLiteAVSDK_Professional
import SnapKit
import UIKit

/// User preferences are independent of SDK state and shared by both camera entry points.
struct BeautyPreferences: Codable {
    var isEnabled = true
    var smoothLevel: Float = 0
    var whitenessLevel: Float = 0
    var ruddyLevel: Float = 0

    static var currentKey: String? {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID, !userID.isEmpty else { return nil }
        return "TUILiveKit.beauty.v1.\(LoginStore.shared.sdkAppID).\(userID)"
    }

    static func load(for key: String?) -> BeautyPreferences {
        guard let key, let data = UserDefaults.standard.data(forKey: key),
            var settings = try? JSONDecoder().decode(Self.self, from: data)
        else { return Self() }
        settings.smoothLevel = validated(settings.smoothLevel)
        settings.whitenessLevel = validated(settings.whitenessLevel)
        settings.ruddyLevel = validated(settings.ruddyLevel)
        return settings
    }

    func save(for key: String?) {
        guard let key, let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func restore() {
        AdvancedBeautySession.shared.refresh()
        if !AdvancedBeautySession.shared.isProcessing { load(for: currentKey).apply() }
    }

    func apply() {
        BaseBeautyStore.shared.setSmoothLevel(smoothLevel: isEnabled ? smoothLevel : 0)
        BaseBeautyStore.shared.setWhitenessLevel(whitenessLevel: isEnabled ? whitenessLevel : 0)
        BaseBeautyStore.shared.setRuddyLevel(ruddyLevel: isEnabled ? ruddyLevel : 0)
    }

    private static func validated(_ value: Float) -> Float { value.isFinite ? min(9, max(0, value)) : 0 }
}

/// Shared beauty sheet. SDK readback never overwrites the user's saved choices.
final class BeautyPanel: BottomSheetView {
    var onDidDismiss: (() -> Void)?

    private enum Kind: CaseIterable {
        case smooth
        case whiteness
        case ruddy

        var title: String {
            switch self {
            case .smooth: return LiveKitResources.localizedString("tuilivekit.pusher.beauty.smooth")
            case .whiteness: return LiveKitResources.localizedString("tuilivekit.pusher.beauty.whiteness")
            case .ruddy: return LiveKitResources.localizedString("tuilivekit.pusher.beauty.ruddy")
            }
        }

        var assetName: String {
            switch self {
            case .smooth: return "livekit_beauty_smooth"
            case .whiteness: return "livekit_beauty_whiteness"
            case .ruddy: return "livekit_beauty_ruddy"
            }
        }
    }

    private let beautySwitch = UISwitch()
    private let typeLabel = LiveText(.caption, tone: .secondary)
    private let valueLabel = LiveText(.caption, alignment: .right, emphasized: true)
    private let slider = LiveSlider(range: 0...9)
    private var buttons: [(Kind, BeautyOptionControl)] = []
    private var selectedKind: Kind = .smooth
    private var settings = BeautyPreferences()
    private var preferencesKey: String?
    private var isActive = false
    private var sessionSubscription: AnyCancellable?
    private weak var advancedPanel: UIView?
    private var basicSubviews: [UIView] = []

    override var sheetHeight: CGFloat { advancedPanel?.intrinsicContentSize.height ?? 220 }
    override var dimsBackground: Bool { false }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sheetTitle = LiveKitResources.localizedString("tuilivekit.pusher.beauty")
        let shellSubviews = contentView.subviews
        configureUI()
        basicSubviews = contentView.subviews.filter { !shellSubviews.contains($0) }
        updateEnabledAppearance()
        sessionSubscription = NotificationCenter.default.publisher(for: AdvancedBeautySession.changed).receive(
            on: DispatchQueue.main
        ).sink { [weak self] _ in
            guard let self, self.isActive else { return }
            self.updateBeautyContent()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func sheetWillPresent() {
        preferencesKey = BeautyPreferences.currentKey
        settings = BeautyPreferences.load(for: preferencesKey)
        if !AdvancedBeautySession.shared.isProcessing { settings.apply() }
        select(.smooth)
        updateEnabledAppearance()
        isActive = true
        AdvancedBeautySession.shared.refresh()
        updateBeautyContent()
        if advancedPanel == nil, TUICore.getService("TUICore_TEBeautyService") != nil {
            LiveToast.show(LiveKitResources.localizedString("tuilivekit.beauty.advanced_unavailable"))
        }
    }

    private func updateBeautyContent() {
        let panel = AdvancedBeautySession.shared.panel
        if advancedPanel !== panel { advancedPanel?.removeFromSuperview() }
        advancedPanel = panel
        // The SDK owns the entire advanced panel, including its surface and category header.
        // Only the shared outside-tap dismissal and presentation animation remain.
        sheetTitle = panel == nil ? LiveKitResources.localizedString("tuilivekit.pusher.beauty") : nil
        contentView.showsDecoration = panel == nil
        basicSubviews.forEach { $0.isHidden = panel != nil }
        if let panel {
            contentView.addSubview(panel)
            panel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        } else {
            BeautyPreferences.load(for: BeautyPreferences.currentKey).apply()
        }
        updateSheetHeight(animated: false)
    }

    override func sheetWillDismiss() {
        AdvancedBeautySession.shared.save()
        isActive = false
    }

    override func sheetDidDismiss() { onDidDismiss?() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { isActive = false }
    }

    private var canEdit: Bool {
        isActive && advancedPanel == nil && window != nil && preferencesKey == BeautyPreferences.currentKey
    }

    private func setEnabled(_ enabled: Bool) {
        guard canEdit, settings.isEnabled != enabled else { return }
        settings.isEnabled = enabled
        settings.save(for: preferencesKey)
        settings.apply()
        updateEnabledAppearance()
    }

    private func updateEnabledAppearance() {
        beautySwitch.setOn(settings.isEnabled, animated: false)
        slider.isEnabled = settings.isEnabled
        slider.alpha = settings.isEnabled ? 1 : 0.4
        updateSlider()
    }

    private func configureUI() {
        let controls = UIView()
        contentView.addSubview(controls)
        controls.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(68)
            make.height.equalTo(112)
        }
        controls.addSubview(typeLabel)

        controls.addSubview(valueLabel)

        slider.onValueChanged = { [weak self] value in self?.setBeautyLevel(value) }
        controls.addSubview(slider)

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        controls.addSubview(row)

        let switchItem = UIView()
        row.addArrangedSubview(switchItem)
        let switchTitle = LiveText(
            .control, text: LiveKitResources.localizedString("tuilivekit.pusher.beauty"), tone: .secondary,
            alignment: .center)
        switchItem.addSubview(switchTitle)
        beautySwitch.onTintColor = UIColor(red: 0.18, green: 0.52, blue: 0.95, alpha: 1)
        beautySwitch.transform = CGAffineTransform(scaleX: 0.81, y: 0.81)
        beautySwitch.accessibilityLabel = switchTitle.text
        beautySwitch.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }
                self.setEnabled(self.beautySwitch.isOn)
            }, for: .valueChanged)
        switchItem.addSubview(beautySwitch)
        beautySwitch.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(switchItem.snp.top).offset(26)
        }
        switchTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(56)
            make.height.equalTo(14)
        }

        Kind.allCases.forEach { kind in
            let button = BeautyOptionControl(title: kind.title, assetName: kind.assetName)
            button.addAction(UIAction { [weak self] _ in self?.select(kind) }, for: .touchUpInside)
            buttons.append((kind, button))
            row.addArrangedSubview(button)
        }

        typeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.top.equalToSuperview()
            make.width.greaterThanOrEqualTo(34)
            make.height.equalTo(32)
        }
        slider.snp.makeConstraints { make in
            make.leading.equalTo(typeLabel.snp.trailing).offset(8)
            make.trailing.equalTo(valueLabel.snp.leading).offset(-8)
            make.centerY.equalTo(typeLabel)
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalTo(typeLabel)
            make.width.equalTo(22)
        }
        row.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(40)
            make.height.equalTo(73)
        }
        select(.smooth)
    }

    private func select(_ kind: Kind) {
        selectedKind = kind
        buttons.forEach { value, button in button.isSelected = value == kind }
        updateSlider()
    }

    private func updateSlider() {
        switch selectedKind {
        case .smooth: configureSlider(title: Kind.smooth.title, value: settings.smoothLevel)
        case .whiteness: configureSlider(title: Kind.whiteness.title, value: settings.whitenessLevel)
        case .ruddy: configureSlider(title: Kind.ruddy.title, value: settings.ruddyLevel)
        }
    }

    private func configureSlider(title: String, value: Float) {
        typeLabel.text = title
        slider.isHidden = false
        slider.value = value
        valueLabel.text = String(Int(value.rounded()))
    }

    private func setBeautyLevel(_ value: Float) {
        guard canEdit, settings.isEnabled, value.isFinite else { return }
        let value = min(9, max(0, value))
        switch selectedKind {
        case .smooth: settings.smoothLevel = value
        case .whiteness: settings.whitenessLevel = value
        case .ruddy: settings.ruddyLevel = value
        }
        settings.save(for: preferencesKey)
        settings.apply()
        updateSlider()
    }
}

private final class BeautyOptionControl: UIControl {
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = LiveText(.control, tone: .secondary, alignment: .center)

    override var isSelected: Bool { didSet { updateAppearance() } }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.iconBackground.transform =
                    self.isHighlighted ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
            }
        }
    }

    init(title: String, assetName: String) {
        super.init(frame: .zero)

        accessibilityLabel = title

        iconBackground.layer.cornerRadius = BeautyStyle.iconRadius
        iconBackground.layer.borderWidth = 1
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = LiveKitResources.image(named: assetName)?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        addSubview(titleLabel)

        iconBackground.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.centerX.equalToSuperview()
            make.size.equalTo(44)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(56)
            make.height.equalTo(14)
        }

        updateAppearance()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateAppearance() {
        iconBackground.backgroundColor = isSelected ? BeautyStyle.selectedFill : BeautyStyle.idleFill
        iconBackground.layer.borderColor = (isSelected ? BeautyStyle.accent : BeautyStyle.idleBorder).cgColor
        iconView.tintColor = isSelected ? .white : BeautyStyle.idleForeground
        titleLabel.tone = isSelected ? .primary : .secondary
    }
}

private enum BeautyStyle {
    static let selectedFill: UIColor = UIColor(red: 0.18, green: 0.48, blue: 0.92, alpha: 0.32)
    static let accent: UIColor = UIColor(red: 0.31, green: 0.64, blue: 1, alpha: 1)
    static let idleFill: UIColor = UIColor.white.withAlphaComponent(0.08)
    static let idleBorder: UIColor = UIColor.white.withAlphaComponent(0.12)
    static let idleForeground: UIColor = UIColor.white.withAlphaComponent(0.82)
}

// Styles owned by this component or feature. Values preserve the existing design.
extension BeautyStyle { static let iconRadius: CGFloat = 22 }

/// One processor for the SDK's shared camera, retained by mounted Live entry points.
/// DeviceStore remains the owner of capture; this object only installs/removes preprocessing.
final class AdvancedBeautySession: NSObject, TRTCVideoFrameDelegate {
    static let shared = AdvancedBeautySession()
    static let changed = Notification.Name("TUILiveKit.advancedBeautySessionChanged")
    private static let service = "TUICore_TEBeautyService"
    private let owners = NSHashTable<AnyObject>.weakObjects()
    private var subscriptions = Set<AnyCancellable>()
    private var preferencesKey: String?
    private(set) var panel: UIView?
    private(set) var isProcessing = false
    private let frameLock = NSRecursiveLock()
    private var acceptsFrames = false
    private var registrationFailed = false

    func acquire(_ owner: AnyObject) {
        owners.add(owner)
        guard subscriptions.isEmpty else { return }
        DeviceStore.shared.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: Notification.Name("TUILiveKit.advancedBeautyAvailabilityChanged"))
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.registrationFailed = false
                self?.refresh()
            }.store(in: &subscriptions)
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification] {
            NotificationCenter.default.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.refresh()
            }.store(in: &subscriptions)
        }
        refresh()
    }

    func release(_ owner: AnyObject) {
        owners.remove(owner)
        guard owners.allObjects.isEmpty else { return }
        subscriptions.removeAll()
        discardPanel()
        registrationFailed = false
    }

    func save() { _ = TUICore.callService(Self.service, method: "TUILiveKit.AdvancedBeauty.Save", param: nil) }

    func refresh() {
        guard !owners.allObjects.isEmpty else { return }
        let key = BeautyPreferences.currentKey.map { $0 + ".advanced" }
        if key != preferencesKey {
            discardPanel()
            preferencesKey = key
            registrationFailed = false
        }
        let authorized =
            TUICore.callService(Self.service, method: "TUILiveKit.AdvancedBeauty.IsAvailable", param: nil) as? Bool
            == true
        guard authorized, key != nil else {
            if panel != nil { discardPanel() }
            BeautyPreferences.load(for: BeautyPreferences.currentKey).apply()
            return
        }
        guard DeviceStore.shared.state.value.cameraStatus == .on, UIApplication.shared.applicationState != .background
        else {
            stopProcessing()
            registrationFailed = false
            return
        }
        guard !isProcessing, !registrationFailed else { return }
        if panel == nil {
            let extensions = TUICore.getExtensionList(
                "TUICore_TEBeautyExtension_GetBeautyPanel",
                param: ["width": UIScreen.main.bounds.width, "height": CGFloat(230), "preferencesKey": key!])
            panel = extensions.first?.data?["TUICore_TEBeautyExtension_GetBeautyPanel"] as? UIView
        }
        guard panel != nil else {
            registrationFailed = true
            return
        }
        _ = TUICore.callService(
            Self.service, method: "TUILiveKit.AdvancedBeauty.SetProcessing", param: ["enabled": true])
        frameLock.lock()
        acceptsFrames = true
        frameLock.unlock()
        let result = TRTCCloud.sharedInstance().setLocalVideoProcessDelegete(
            self, pixelFormat: ._32BGRA, bufferType: .pixelBuffer)
        guard result == 0 else {
            registrationFailed = true
            discardPanel()
            BeautyPreferences.load(for: BeautyPreferences.currentKey).apply()
            LiveKitLog.warn("Advanced beauty frame callback registration failed: \(result)")
            return
        }
        isProcessing = true
        BaseBeautyStore.shared.setSmoothLevel(smoothLevel: 0)
        BaseBeautyStore.shared.setWhitenessLevel(whitenessLevel: 0)
        BaseBeautyStore.shared.setRuddyLevel(ruddyLevel: 0)
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    private func stopProcessing() {
        frameLock.lock()
        acceptsFrames = false
        frameLock.unlock()
        if isProcessing {
            TRTCCloud.sharedInstance().setLocalVideoProcessDelegete(
                nil, pixelFormat: ._32BGRA, bufferType: .pixelBuffer)
        }
        isProcessing = false
        frameLock.lock()
        save()
        _ = TUICore.callService(
            Self.service, method: "TUILiveKit.AdvancedBeauty.SetProcessing", param: ["enabled": false])
        frameLock.unlock()
    }

    private func discardPanel() {
        stopProcessing()
        frameLock.lock()
        panel?.removeFromSuperview()
        panel = nil
        frameLock.unlock()
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    func onProcessVideoFrame(_ srcFrame: TRTCVideoFrame, dstFrame: TRTCVideoFrame) -> UInt32 {
        frameLock.lock()
        defer { frameLock.unlock() }
        dstFrame.pixelBuffer = srcFrame.pixelBuffer
        guard acceptsFrames, let buffer = srcFrame.pixelBuffer else { return 0 }
        let input = NSValue(pointer: Unmanaged.passUnretained(buffer).toOpaque())
        if let output = TUICore.callService(
            Self.service, method: "TUILiveKit.AdvancedBeauty.ProcessRetainedPixelBuffer",
            param: ["TUICore_TEBeautyService_ProcessVideoFrame_PixelValue": input]) as? NSValue,
            let pointer = output.pointerValue
        {
            dstFrame.pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(pointer).takeRetainedValue()
        }
        return 0
    }
}
