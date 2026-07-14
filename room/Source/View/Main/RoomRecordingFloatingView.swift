//
//  RoomRecordingFloatingView.swift
//  TUIRoomKit
//
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore
import AtomicX

/// Recording status floating view.
///
/// - Visible only while the room is recording.
/// - Owner / admin can tap the pill to expand a card containing a "Stop" action;
///   general users only see the pill (no chevron, no tap effect).
/// - When expanded, an invisible overlay catches taps outside the card and
///   collapses the view; taps inside the card itself do nothing.
public class RoomRecordingFloatingView: UIView {
    
    // MARK: - Properties
    private let roomStore: RoomStore = RoomStore.shared
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    private var isExpanded: Bool = false
    private var canManage: Bool = false
    private var isBlinking: Bool = false
    private weak var stopConfirmAlertView: AtomicAlertView?
    
    private static let blinkAnimationKey = "roomRecordingBlink"
    
    private weak var dismissOverlay: UIControl?
    
    // MARK: - UI Components
    private lazy var pillView: UIControl = {
        let view = UIControl()
        view.backgroundColor = RoomColors.recordingFloatingBg
        view.layer.cornerRadius = 8
        view.addTarget(self, action: #selector(onPillTapped), for: .touchUpInside)
        return view
    }()
    
    private lazy var pillDot: UIView = makeRecordingDot()
    private lazy var pillLabel: UILabel = makeRecordingLabel()
    private lazy var pillArrow: UIImageView = {
        let iv = UIImageView(image: ResourceLoader.loadImage("room_recording_arrow"))
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()
    
    private lazy var cardView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.recordingFloatingBg
        view.layer.cornerRadius = 8
        view.isHidden = true
        return view
    }()
    
    private lazy var cardHeader: UIControl = {
        let control = UIControl()
        control.addTarget(self, action: #selector(onHeaderTapped), for: .touchUpInside)
        return control
    }()
    
    private lazy var cardDot: UIView = makeRecordingDot()
    private lazy var cardLabel: UILabel = makeRecordingLabel()
    private lazy var cardArrow: UIImageView = {
        let iv = UIImageView(image: ResourceLoader.loadImage("room_recording_arrow"))
        iv.contentMode = .scaleAspectFit
        iv.transform = CGAffineTransform(rotationAngle: .pi)
        iv.isUserInteractionEnabled = false
        return iv
    }()
    
    private lazy var stopButton: UIControl = {
        let control = UIControl()
        control.addTarget(self, action: #selector(onStopTapped), for: .touchUpInside)
        return control
    }()
    
    private lazy var stopIcon: UIImageView = {
        let iv = UIImageView(image: ResourceLoader.loadImage("room_recording_stop"))
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()
    
    private lazy var stopLabel: UILabel = {
        let label = UILabel()
        label.text = .end
        label.textColor = RoomColors.g7
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var stopContentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [stopIcon, stopLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        return stack
    }()
    
    // MARK: - Initialization
    public init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        addSubview(pillView)
        pillView.addSubview(pillDot)
        pillView.addSubview(pillLabel)
        pillView.addSubview(pillArrow)
        
        addSubview(cardView)
        cardView.addSubview(cardHeader)
        cardHeader.addSubview(cardDot)
        cardHeader.addSubview(cardLabel)
        cardHeader.addSubview(cardArrow)
        cardView.addSubview(stopButton)
        stopButton.addSubview(stopContentStack)
    }
    
    private func setupConstraints() {
        pillView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.height.equalTo(30)
            make.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        pillDot.snp.makeConstraints { make in
            make.size.equalTo(8)
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
        }
        pillLabel.snp.makeConstraints { make in
            make.leading.equalTo(pillDot.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-8).priority(.medium)
        }
        pillArrow.snp.makeConstraints { make in
            make.size.equalTo(16)
            make.leading.equalTo(pillLabel.snp.trailing).offset(4)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
        
        cardView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.trailing.greaterThanOrEqualToSuperview()
            make.bottom.equalToSuperview().priority(.required)
        }
        cardHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(30)
        }
        cardDot.snp.makeConstraints { make in
            make.size.equalTo(8)
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
        }
        cardLabel.snp.makeConstraints { make in
            make.leading.equalTo(cardDot.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
        }
        cardArrow.snp.makeConstraints { make in
            make.size.equalTo(16)
            make.leading.equalTo(cardLabel.snp.trailing).offset(4)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
        stopButton.snp.makeConstraints { make in
            make.top.equalTo(cardHeader.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        stopContentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
        stopIcon.snp.makeConstraints { make in
            make.size.equalTo(40)
        }
    }
    
    private func setupBindings() {
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .map { $0?.role ?? .generalUser }
            .removeDuplicates()
            .combineLatest(
                roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
                    .map { $0?.recordingInfo.status ?? .none }
                    .removeDuplicates()
            )
            .receive(on: RunLoop.main)
            .sink { [weak self] role, status in
                guard let self = self else { return }
                updateState(role: role, status: status)
            }
            .store(in: &cancellableSet)
    }
    
    // MARK: - State
    private func updateState(role: ParticipantRole, status: RecordingStatus) {
        canManage = role == .owner || role == .admin
        pillArrow.isHidden = !canManage
        
        let recording = status == .recording
        isHidden = !recording
        if recording {
            startBlink()
        } else {
            stopBlink()
            collapse()
        }
        if !canManage {
            collapse()
            dismissStopConfirmAlertView()
        }
    }

    private func dismissStopConfirmAlertView() {
        stopConfirmAlertView?.dismiss()
        stopConfirmAlertView = nil
    }
    
    private func startBlink() {
        guard !isBlinking else { return }
        isBlinking = true
        addBlinkAnimation(to: pillDot.layer)
        addBlinkAnimation(to: cardDot.layer)
    }
    
    private func stopBlink() {
        guard isBlinking else { return }
        isBlinking = false
        pillDot.layer.removeAnimation(forKey: Self.blinkAnimationKey)
        cardDot.layer.removeAnimation(forKey: Self.blinkAnimationKey)
        pillDot.layer.opacity = 1.0
        cardDot.layer.opacity = 1.0
    }
    
    private func addBlinkAnimation(to layer: CALayer) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = 0.6
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: Self.blinkAnimationKey)
    }
    
    // MARK: - Expand / Collapse
    private func expand() {
        guard !isExpanded, canManage else { return }
        isExpanded = true
        pillView.isHidden = true
        cardView.isHidden = false
        installDismissOverlay()
    }
    
    private func collapse() {
        if isExpanded {
            isExpanded = false
            pillView.isHidden = false
            cardView.isHidden = true
        }
        removeDismissOverlay()
    }
    
    private func installDismissOverlay() {
        guard dismissOverlay == nil, let host = superview else { return }
        let overlay = UIControl()
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(onOverlayTapped), for: .touchUpInside)
        host.insertSubview(overlay, belowSubview: self)
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        host.bringSubviewToFront(self)
        dismissOverlay = overlay
    }
    
    private func removeDismissOverlay() {
        dismissOverlay?.removeFromSuperview()
        dismissOverlay = nil
    }
    
    // MARK: - Actions
    @objc private func onPillTapped() {
        guard canManage else { return }
        expand()
    }
    
    @objc private func onHeaderTapped() {
        collapse()
    }
    
    @objc private func onOverlayTapped() {
        collapse()
    }
    
    @objc private func onStopTapped() {
        collapse()
        showStopConfirm()
    }
    
    private func showStopConfirm() {
        dismissStopConfirmAlertView()
        let cancelButtonConfig = AlertButtonConfig(text: .cancel, type: .grey, isBold: false) { view in
            view.dismiss()
        }
        let confirmButtonConfig = AlertButtonConfig(text: .recordStop, type: .red, isBold: false) { [weak self] view in
            guard let self = self else { return }
            stopRecording()
            view.dismiss()
        }
        let config = AlertViewConfig(title: .recordStopTitle,
                                     content: .recordStopTips,
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: confirmButtonConfig)
        let alert = AtomicAlertView(config: config)
        stopConfirmAlertView = alert
        alert.show()
    }
    
    private func stopRecording() {
        roomStore.stopRecording { [weak self] result in
            guard let self = self else { return }
            if case .failure(let err) = result {
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
        }
    }
    
    // MARK: - Helpers
    private func makeRecordingDot() -> UIView {
        let dot = UIView()
        dot.backgroundColor = RoomColors.recordingDot
        dot.layer.cornerRadius = 4
        return dot
    }
    
    private func makeRecordingLabel() -> UILabel {
        let label = UILabel()
        label.text = .recording
        label.textColor = RoomColors.g7
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        return label
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            removeDismissOverlay()
            stopBlink()
        }
    }
}

fileprivate extension String {
    static let cancel = "roomkit_cancel".localized
    static let recording = "roomkit_cloud_record_recording".localized
    static let end = "roomkit_end".localized
    static let recordStop = "roomkit_cloud_record_stop".localized
    static let recordStopTitle = "roomkit_cloud_record_stop_title".localized
    static let recordStopTips = "roomkit_cloud_record_stop_tips".localized
}
