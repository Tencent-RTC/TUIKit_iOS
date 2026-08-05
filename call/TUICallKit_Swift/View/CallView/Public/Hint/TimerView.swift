//
//  TimerView.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import AtomicXCore
import AtomicX
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
        timerLabel.textColor = UIColor("D5E0F2")
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
        let state = CallStore.shared.state.value
        let status = state.selfInfo.status
        let activeCall = state.activeCall
        let selfInfo = state.selfInfo
        let isOneToOne = activeCall.chatGroupId.isEmpty && activeCall.inviteeIds.count == 1

        switch status {
        case .accept:
            timerLabel.text = GCDTimer.secondToHMSString(second: Int(activeCall.duration))
        case .waiting:
            timerLabel.text = CallKitLocalization.localized("waitAccept")
        default:
            timerLabel.text = ""
        }

        switch status {
        case .accept:
            timerLabel.isHidden = false
        case .waiting:
            if isOneToOne {
                timerLabel.isHidden = true
            } else {
                let isInviter = selfInfo.id == activeCall.inviterId
                timerLabel.isHidden = !isInviter
            }
        default:
            timerLabel.isHidden = true
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
