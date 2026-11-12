import AtomicXCore
import AVFAudio
import Combine
import SnapKit
import UIKit

final class CallControlPanel: UIView {

    var onSpeakerBubbleToggle: (() -> Void)?
    var onMoreBubbleToggle: (() -> Void)?
    var onExpand: (() -> Void)?

    var speakerAnchor: UIView? {
        cells[.speaker]?.button
    }

    var moreAnchor: UIView? {
        cells[.more]?.button
    }

    private enum ButtonID {
        case microphone
        case speaker
        case camera
        case transcription
        case more
        case hangup
        case flip
    }

    private final class Cell: UIView {
        let button = UIButton(type: .custom)
        let label = UILabel()

        init(buttonSize: CGFloat = CallKitTheme.controlButtonSize, showsLabel: Bool = true) {
            super.init(frame: .zero)
            button.layer.cornerRadius = buttonSize / 2
            button.clipsToBounds = true
            button.imageView?.contentMode = .scaleAspectFit
            let inset = buttonSize * 16.0 / CallKitTheme.controlButtonSize
            button.imageEdgeInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
            label.font = CallKitTheme.controlLabelFont
            label.textColor = .white
            label.textAlignment = .center
            addSubview(button)
            button.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.size.equalTo(buttonSize)
                if !showsLabel {
                    make.bottom.equalToSuperview()
                }
            }
            if showsLabel {
                addSubview(label)
                label.snp.makeConstraints { make in
                    make.top.equalTo(button.snp.bottom).offset(CallKitTheme.controlLabelGap)
                    make.leading.trailing.bottom.equalToSuperview()
                }
            }
            snp.makeConstraints { make in
                make.width.equalTo(CallKitTheme.controlCellWidth)
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setOn(_ isOn: Bool) {
            button.backgroundColor = isOn ? .white : CallKitTheme.controlOffBackground
            button.tintColor = isOn ? CallKitTheme.controlForeground : CallKitTheme.controlOffForeground
        }

        func setGhost() {
            button.backgroundColor = CallKitTheme.controlOffBackground
            button.tintColor = .white
        }
    }

    private var cells: [ButtonID: Cell] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var pendingMicTarget: Bool?
    private var isTwoRowLayout = false
    private var isCollapsed = false
    private var barBackgroundVisible = false


    private let barBackgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.layer.cornerRadius = 22
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.28
        view.layer.shadowRadius = 15
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        let tint = UIView()
        tint.backgroundColor = CallKitTheme.hairlineOnDark
        view.contentView.addSubview(tint)
        tint.snp.makeConstraints { make in make.edges.equalToSuperview() }
        return view
    }()
    private let expandButton = UIButton(type: .custom)

    private var isVideo: Bool { CallStore.shared.state.value.isVideoCall }
    private var isMulti: Bool { CallStore.shared.state.value.isMultiCall }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        subscribeDeviceState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        barBackgroundView.isHidden = !barBackgroundVisible
        addSubview(barBackgroundView)
        barBackgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }

        let content = isCollapsed ? setupCollapsedRow() : setupRegularRows()
        addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalToSuperview().offset((isCollapsed || barBackgroundVisible) ? 14 : 0)
            make.leading.trailing.equalToSuperview().inset(isCollapsed ? 24 : 0)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        let actions: [ButtonID: () -> Void] = [
            .microphone: { [weak self] in self?.handleMicTap() },
            .speaker: { [weak self] in self?.onSpeakerBubbleToggle?() },
            .transcription: { [weak self] in self?.handleTranscriptionTap() },
            .hangup: { CallLauncher.shared.hangup() },
            .camera: { [weak self] in self?.handleCameraTap() },
            .more: { [weak self] in self?.onMoreBubbleToggle?() },
            .flip: { DeviceStore.shared.switchCamera(isFront: !DeviceStore.shared.state.value.isFrontCamera) },
        ]
        actions.forEach { id, action in
            cells[id]?.button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }

        cells[.transcription]?.label.text = CallKitResources.text("callkit.call.cc")
        cells[.hangup]?.label.text = CallKitResources.text("callkit.call.hangup")
        cells[.hangup]?.button.backgroundColor = CallKitTheme.callRed
        if let hangupButton = cells[.hangup]?.button {
            hangupButton.contentHorizontalAlignment = .fill
            hangupButton.contentVerticalAlignment = .fill
            hangupButton.imageEdgeInsets = .zero
            hangupButton.setImage(CallKitResources.image(named: "callkit_icon_reject"), for: .normal)
        }

        cells[.transcription]?.isHidden = false
        refreshMic()
        refreshSpeaker()
        refreshCamera()
        refreshTranscription()
    }

    private func setupRegularRows() -> UIStackView {
        let twoRow = isVideo || isMulti
        isTwoRowLayout = twoRow
        addCell(.microphone, icon: "callkit_icon_mic")
        addCell(.speaker, icon: "callkit_icon_speaker")
        addCell(.transcription, icon: "callkit_icon_cc")
        addCell(.hangup, icon: nil, showsLabel: !twoRow)
        if twoRow {
            addCell(.camera, icon: "callkit_icon_cam")
            addCell(.more, icon: "callkit_icon_more", buttonSize: 52, showsLabel: false)
            addCell(.flip, icon: "callkit_icon_flip", buttonSize: 52, showsLabel: false)
            cells[.more]?.setGhost()
            cells[.flip]?.setGhost()
        }
        let rows = twoRow
            ? [makeRow([.microphone, .speaker, .camera, .transcription]), makeRow([.more, .hangup, .flip])]
            : [makeRow([.microphone, .speaker, .transcription, .hangup])]

        let column = UIStackView(arrangedSubviews: rows)
        column.axis = .vertical
        column.spacing = 26
        return column
    }

    private func setupCollapsedRow() -> UIStackView {
        let collapsedButtonSize: CGFloat = 46
        addCell(.microphone, icon: "callkit_icon_mic", buttonSize: collapsedButtonSize, showsLabel: false)
        addCell(.speaker, icon: "callkit_icon_speaker", buttonSize: collapsedButtonSize, showsLabel: false)
        addCell(.camera, icon: "callkit_icon_cam", buttonSize: collapsedButtonSize, showsLabel: false)
        addCell(.transcription, icon: "callkit_icon_cc", buttonSize: collapsedButtonSize, showsLabel: false)
        addCell(.hangup, icon: nil, buttonSize: collapsedButtonSize, showsLabel: false)

        expandButton.setImage(CallKitResources.image(named: "callkit_icon_expand")?.withRenderingMode(.alwaysTemplate), for: .normal)
        expandButton.tintColor = .white
        expandButton.imageEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        expandButton.addTarget(self, action: #selector(handleExpandTap), for: .touchUpInside)

        let arrowColumn = UIView()
        arrowColumn.addSubview(expandButton)
        expandButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(collapsedButtonSize)
        }
        arrowColumn.snp.makeConstraints { make in
            make.width.equalTo(20)
            make.height.equalTo(collapsedButtonSize)
        }

        let keysRow = makeRow([.microphone, .speaker, .camera, .transcription, .hangup])
        let row = UIStackView(arrangedSubviews: [arrowColumn, keysRow])
        row.alignment = .center
        return row
    }

    func setCollapsed(_ collapsed: Bool) {
        guard collapsed != isCollapsed else { return }
        isCollapsed = collapsed
        rebuildLayout()
    }

    func setBarBackground(_ visible: Bool) {
        guard visible != barBackgroundVisible else { return }
        barBackgroundVisible = visible
        rebuildLayout()
    }

    private func rebuildLayout() {
        subviews.forEach { $0.removeFromSuperview() }
        cells.removeAll()
        setupViews()
    }

    private func addCell(_ id: ButtonID, icon: String?, buttonSize: CGFloat = CallKitTheme.controlButtonSize, showsLabel: Bool = true) {
        let cell = Cell(buttonSize: buttonSize, showsLabel: showsLabel)
        if let icon {
            cell.button.setImage(CallKitResources.image(named: icon)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        cells[id] = cell
    }

    private func makeRow(_ ids: [ButtonID]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: ids.compactMap { cells[$0] }.map { cell in
            let container = UIView()
            container.addSubview(cell)
            cell.snp.makeConstraints { make in
                make.centerX.top.bottom.equalToSuperview()
            }
            return container
        })
        stack.distribution = .fillEqually
        stack.alignment = .top
        return stack
    }

    private func subscribeDeviceState() {
        DeviceStore.shared.state
            .subscribe(StatePublisherSelector { "\($0.microphoneStatus.rawValue)|\($0.currentSpeaker.deviceId)|\($0.cameraStatus.rawValue)" })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if let target = self.pendingMicTarget,
                   (DeviceStore.shared.state.value.microphoneStatus == .on) == target {
                    self.pendingMicTarget = nil
                }
                self.refreshMic()
                self.refreshSpeaker()
                self.refreshCamera()
            }
            .store(in: &cancellables)

        CallKitConfig.shared.transcriptionChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refreshTranscription() }
            .store(in: &cancellables)

        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.allParticipants.count })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildIfNeeded() }
            .store(in: &cancellables)
    }

    private func rebuildIfNeeded() {
        guard !isCollapsed else { return }
        let twoRow = isVideo || isMulti
        guard twoRow != isTwoRowLayout else { return }
        rebuildLayout()
    }

    @objc private func handleExpandTap() {
        onExpand?()
    }

    private var isMicOn: Bool {
        DeviceStore.shared.state.value.microphoneStatus == .on
    }

    private var isCameraOn: Bool {
        DeviceStore.shared.state.value.cameraStatus == .on
    }

    private var currentRouteId: String {
        DeviceStore.shared.state.value.currentSpeaker.deviceId
    }

    private var isSpeakerOn: Bool {
        currentRouteId == "speaker_1"
    }

    private var isBluetoothRoute: Bool {
        isExternalRoute && CallAudioRouteKind.isBluetooth(deviceId: currentRouteId,
                                                          outputs: AVAudioSession.sharedInstance().currentRoute.outputs)
    }

    private var isExternalRoute: Bool {
        !currentRouteId.isEmpty && currentRouteId != "speaker_0" && currentRouteId != "speaker_1"
    }

    private func refreshToggle(_ id: ButtonID, on: Bool, icons: (on: String, off: String), texts: (on: String, off: String)) {
        let cell = cells[id]
        cell?.setOn(on)
        cell?.button.setImage(CallKitResources.image(named: on ? icons.on : icons.off)?.withRenderingMode(.alwaysTemplate), for: .normal)
        cell?.label.text = CallKitResources.text(on ? texts.on : texts.off)
    }

    private func refreshMic() {
        let on = pendingMicTarget ?? isMicOn
        refreshToggle(.microphone, on: on, icons: ("callkit_icon_mic", "callkit_icon_micoff"),
                      texts: ("callkit.call.mic_on", "callkit.call.mic_off"))
    }

    private func refreshCamera() {
        refreshToggle(.camera, on: isCameraOn, icons: ("callkit_icon_cam", "callkit_icon_camoff"),
                      texts: ("callkit.call.camera_on", "callkit.call.camera_off"))
    }

    private func refreshSpeaker() {
        let cell = cells[.speaker]
        cell?.setOn(true)
        cell?.button.setImage(CallKitResources.image(named: "callkit_icon_device"), for: .normal)
        if isSpeakerOn {
            cell?.label.text = CallKitResources.text("callkit.call.speaker_on")
        } else if isBluetoothRoute {
            cell?.label.text = CallKitResources.text("callkit.call.bluetooth_on")
        } else if isExternalRoute {
            cell?.label.text = DeviceStore.shared.state.value.currentSpeaker.deviceName
        } else {
            cell?.label.text = CallKitResources.text("callkit.call.earpiece_on")
        }
    }

    private func refreshTranscription() {
        cells[.transcription]?.setOn(CallKitConfig.shared.enableAITranscriber)
    }

    private func handleMicTap() {
        let currentUiOn = pendingMicTarget ?? isMicOn
        let target = !currentUiOn
        pendingMicTarget = target
        refreshMic()
        if target {
            DeviceStore.shared.openLocalMicrophone { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if case .failure(let error) = result {
                        CallKitLog.error("openLocalMicrophone failed: code=\(error.code) message=\(error.message)")
                        self.pendingMicTarget = nil
                        self.refreshMic()
                    }
                }
            }
        } else {
            DeviceStore.shared.closeLocalMicrophone()
        }
    }

    private func handleTranscriptionTap() {
        CallKitConfig.shared.updateAITranscriber(!CallKitConfig.shared.enableAITranscriber)
    }

    private func handleCameraTap() {
        guard !isCameraOn else { return DeviceStore.shared.closeLocalCamera() }
        DeviceStore.shared.openLocalCamera(isFront: DeviceStore.shared.state.value.isFrontCamera) { result in
            guard case .failure(let error) = result else { return }
            CallKitLog.error("openLocalCamera failed: code=\(error.code) message=\(error.message)")
        }
    }
}
