//
//  HintView.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import AtomicXCore
import AtomicX
import Combine
import RTCRoomEngine
import SnapKit

class HintView: UIView {
    /// UX-specified: hold the end-call hint text on screen so users have time to read it.
    private static let endHintHoldDuration: TimeInterval = 0.9
    /// UX-specified: duration of the push transition between old and new hint text.
    private static let endHintTransitionDuration: CFTimeInterval = 0.25
    private static let endHintTransitionKey = "endHintTransition"

    // MARK: Init
    override init(frame: CGRect) {
        needShowAcceptHit = (CallStore.shared.state.value.selfInfo.status == .accept) ? false : true
        super.init(frame: frame)
        clipsToBounds = true
        updateStatusText()
        updateHintView()
        subscribeCallListState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    private static let hintFontSize: CGFloat = 19.0

    private let callStatusLabel: UILabel = {
        let callStatusLabel = UILabel(frame: CGRect.zero)
        callStatusLabel.textColor = UIColor("FFFFFF")
        callStatusLabel.font = UIFont.systemFont(ofSize: HintView.hintFontSize)
        callStatusLabel.backgroundColor = UIColor.clear
        callStatusLabel.textAlignment = .center
        return callStatusLabel
    }()
    private var needShowAcceptHit: Bool
    private var cancellables = Set<AnyCancellable>()
    private var holdWorkItem: DispatchWorkItem?

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        holdWorkItem?.cancel()
        holdWorkItem = nil
    }
    
    // MARK: UI Specification Processing
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
}

// MARK: Layout
extension HintView {
    func constructViewHierarchy() {
        addSubview(callStatusLabel)
    }
    
    func activateConstraints() {
        callStatusLabel.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    func setNetworkQualityViewHidden(_ hidden: Bool) {
        if hidden {
            updateStatusText()
        } else {
            updateNetworkQualityText()
        }
    }

    func updateHintView() {
        let state = CallStore.shared.state.value
        let isOneToOne = state.activeCall.chatGroupId.isEmpty && state.activeCall.inviteeIds.count == 1
        let isInvitee = state.selfInfo.id != state.activeCall.inviterId
        let isWaiting = state.selfInfo.status == .waiting
        callStatusLabel.isHidden = !(isOneToOne || (isInvitee && isWaiting))
    }

    func updateNetworkQualityText() {
        let state = CallStore.shared.state.value
        let selfId = state.selfInfo.id
        guard !selfId.isEmpty else {
            updateStatusText()
            return
        }
        if let localQuality = state.networkQualities[selfId], localQuality.rawValue >= 4 {
            self.callStatusLabel.text = CallKitLocalization.localized("Self.NetworkLowQuality")
            return
        }
        for (userId, quality) in state.networkQualities where userId != selfId {
            if quality.rawValue >= 4 {
                self.callStatusLabel.text = CallKitLocalization.localized("OtherParty.NetworkLowQuality")
                return
            }
        }
        updateStatusText()
    }
    
    func updateStatusText() {
        switch CallStore.shared.state.value.selfInfo.status {
        case .waiting:
            self.callStatusLabel.text = self.getCurrentWaitingText()
        case .accept:
            if needShowAcceptHit {
                self.callStatusLabel.text = CallKitLocalization.localized("accept")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    self.needShowAcceptHit = false
                    self.updateStatusText()
                }
            } else {
                self.callStatusLabel.text = ""
            }
        default:
            break
        }
    }
    
    func getCurrentWaitingText() -> String {
        if !(CallStore.shared.state.value.activeCall.chatGroupId.isEmpty == true && CallStore.shared.state.value.activeCall.inviteeIds.count == 1) {
            return  CallKitLocalization.localized("Group.inviteToGroupCall")
        }
        var waitingText = String()
        switch CallStore.shared.state.value.activeCall.mediaType {
        case .audio:
            if CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId {
                waitingText = CallKitLocalization.localized("waitAccept")
            } else {
                waitingText = CallKitLocalization.localized("inviteToAudioCall")
            }
        case .video:
            if CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId {
                waitingText = CallKitLocalization.localized("waitAccept")
            } else {
                waitingText = CallKitLocalization.localized("inviteToVideoCall")
            }
        case nil:
            break
        }
        return waitingText
    }
}

// MARK: Subscribe
extension HintView {
    func subscribeCallListState() {
        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateStatusText()
                self.updateHintView()
            }
            .store(in: &cancellables)
        
        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.networkQualities))
            .removeDuplicates { $0 == $1 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateNetworkQualityText()
            }
            .store(in: &cancellables)
    }
}

// MARK: End Call Transition
extension HintView {
    func playEndCallTransition(text: String, holdDuration: TimeInterval = HintView.endHintHoldDuration, onComplete: @escaping () -> Void) {
        if holdWorkItem != nil { return }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        let transition = CATransition()
        transition.type = .push
        transition.subtype = .fromBottom
        transition.duration = HintView.endHintTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        callStatusLabel.layer.add(transition, forKey: HintView.endHintTransitionKey)
        callStatusLabel.text = text
        callStatusLabel.isHidden = false

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.holdWorkItem = nil
            onComplete()
        }
        holdWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + HintView.endHintTransitionDuration + holdDuration, execute: work)
    }

    func cancelEndCallTransition() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        callStatusLabel.layer.removeAnimation(forKey: HintView.endHintTransitionKey)
        callStatusLabel.text = ""
        callStatusLabel.isHidden = false
    }
}
