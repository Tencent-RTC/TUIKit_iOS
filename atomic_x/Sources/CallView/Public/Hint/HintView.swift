//
//  HintView.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import AtomicXCore
import Combine
import RTCRoomEngine
import SnapKit

class HintView: UIView {
    // MARK: Init
    override init(frame: CGRect) {
        needShowAcceptHit = (CallStore.shared.state.value.selfInfo.status == .accept) ? false : true
        super.init(frame: frame)
        updateStatusText()
        updateHintView()
        subscribeCallListState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    private let callStatusLabel: UILabel = {
        let callStatusLabel = UILabel(frame: CGRect.zero)
        callStatusLabel.textColor = UIColor(hex: "#FFFFFF")
        callStatusLabel.font = UIFont.systemFont(ofSize: 15.0)
        callStatusLabel.backgroundColor = UIColor.clear
        callStatusLabel.textAlignment = .center
        return callStatusLabel
    }()
    private var needShowAcceptHit: Bool
    private var cancellables = Set<AnyCancellable>()
    
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
        if CallStore.shared.state.value.activeCall.chatGroupId.isEmpty == true && CallStore.shared.state.value.activeCall.inviteeIds.count == 1 {
            callStatusLabel.isHidden = false
        } else if !(CallStore.shared.state.value.activeCall.chatGroupId.isEmpty == true && CallStore.shared.state.value.activeCall.inviteeIds.count == 1) &&
                    !(CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId) &&
                    CallStore.shared.state.value.selfInfo.status == .waiting {
            callStatusLabel.isHidden = false
        } else {
            callStatusLabel.isHidden = true
        }
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
            break
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
            break
        case .none:
            break
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
