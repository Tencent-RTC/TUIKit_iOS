//
//  TimerView.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import AtomicXCore
import Combine
import RTCRoomEngine
import SnapKit

class TimerView: UIView {
    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        updateTimerView()
        subscribeCallListStatus()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    private let timerLabel: UILabel = {
        let timerLabel = UILabel()
        timerLabel.font = UIFont.boldSystemFont(ofSize: 15.0)
        timerLabel.backgroundColor = UIColor.clear
        timerLabel.textAlignment = .center
        timerLabel.textColor = UIColor(hex: "#D5E0F2")
        return timerLabel
    }()
    
    private var cancellables = Set<AnyCancellable>()
    private var isViewReady: Bool = false
    
    // MARK: UI Specification Processing
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
}

// MARK: Layout
extension TimerView {
    private func constructViewHierarchy() {
        addSubview(timerLabel)
    }
    
    private func activateConstraints() {
        timerLabel.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    private func updateTimerView() {
        timerLabel.text = CallStore.shared.state.value.selfInfo.status == .accept ?
        GCDTimer.secondToHMSString(second: Int(CallStore.shared.state.value.activeCall.duration)) : CallKitLocalization.localized("waitAccept")

        if CallStore.shared.state.value.activeCall.chatGroupId.isEmpty == true && CallStore.shared.state.value.activeCall.inviteeIds.count == 1 {
            if CallStore.shared.state.value.selfInfo.status == .accept {
                timerLabel.isHidden = false
            } else {
                timerLabel.isHidden = true
            }
            return
        }
        
        if !(CallStore.shared.state.value.activeCall.chatGroupId.isEmpty == true && CallStore.shared.state.value.activeCall.inviteeIds.count == 1) {
           
            if CallStore.shared.state.value.selfInfo.status == .waiting && !(CallStore.shared.state.value.selfInfo.id == CallStore.shared.state.value.activeCall.inviterId) {
                timerLabel.isHidden = true
            } else {
                timerLabel.isHidden = false
            }
            return
        }
    }
}

// MARK: Subscribe
extension TimerView {
    func subscribeCallListStatus() {
        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.activeCall.duration))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateTimerView()
            }
            .store(in: &cancellables)

        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateTimerView()
            }
            .store(in: &cancellables)
    }
}
