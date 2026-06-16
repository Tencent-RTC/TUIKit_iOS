//
//  CallTranscriberView.swift
//  AtomicX
//
//  Created on 2026/1/29.
//

import UIKit
import AtomicX
import SnapKit
import AtomicXCore
import Combine

final class CallTranscriberView: UIView {
    
    var isEnabled: Bool = true {
        didSet {
            guard oldValue != isEnabled else { return }
            updateTranscriberState()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var currentCallID = ""
    private var transcriberCancelables = Set<AnyCancellable>()
    private var isCallAccepted = false
    private var isTranscriberEmpty = true
    private var isTranscriptionRunning = false
    
    private lazy var transcriberButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(CallKitBundle.getBundleImage(name: "icon_ai_transcriber_off"), for: .normal)
        button.setBackgroundImage(CallKitBundle.getBundleImage(name: "icon_ai_transcriber_on"), for: .selected)
        button.isSelected = false
        button.isHidden = true
        button.addTarget(self, action: #selector(transcriberButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var emptyHintLabel: UILabel = {
        let label = UILabel()
        label.text = CallKitBundle.localizedString(forKey: "ai_transcriber_empty_hint")
        label.textColor = UIColor(0xFFFFFF, alpha: 0.6)
        label.font = .systemFont(ofSize: 18)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    private var transcriberStore: AITranscriberStore?
    
    private lazy var transcriberView: TranscriberView = {
        let transcriberView = TranscriberView(frame: .zero)
        transcriberView.isHidden = true
        return transcriberView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            guard cancellables.isEmpty else { return }
            subscribeCallState()
        } else {
            cancellables.removeAll()
            transcriberCancelables.removeAll()
            currentCallID = ""
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        return hitView == self ? nil : hitView
    }
}

extension CallTranscriberView {
    private func constructViewHierarchy() {
        addSubview(transcriberView)
        addSubview(emptyHintLabel)
        addSubview(transcriberButton)
    }
    
    private func activateConstraints() {
        transcriberView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.95)
            make.bottom.equalToSuperview()
        }
        
        emptyHintLabel.snp.makeConstraints { make in
            make.center.equalTo(transcriberView)
            make.leading.trailing.equalTo(transcriberView).inset(12)
        }
        
        transcriberButton.snp.makeConstraints { make in
            make.size.equalTo(24.scale375Width())
            make.top.equalToSuperview().offset(6.scale375Height())
            make.leading.equalToSuperview().offset(52.scale375Width())
        }
    }
}

extension CallTranscriberView {
    @objc private func transcriberButtonTapped() {
        let callID = CallStore.shared.state.value.activeCall.callId
        let store = AITranscriberStore.create(roomID: callID)
        if isTranscriptionRunning {
            store.stopTranscription(completion: nil)
            transcriberView.clearMessages()
        } else {
            store.startRealtimeTranscriber(config: TranscriberSettings.config, completion: nil)
        }
        
        CallViewStore.shared.toggleTranscriberPanel()
    }
}

extension CallTranscriberView {
    private func subscribeCallState() {
        CallStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \.selfInfo))
            .map { $0.status == .accept }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isAccepted in
                self?.handleCallAcceptStateChanged(isAccepted)
            }
            .store(in: &cancellables)
        
        CallStore.shared.state
            .subscribe(StatePublisherSelector<CallState, String>(keyPath: \.activeCall.callId))
            .receive(on: RunLoop.main)
            .sink { [weak self] callId in
                guard let self = self else { return }
                if callId.isEmpty {
                    currentCallID = ""
                    transcriberCancelables.removeAll()
                    transcriberStore = nil
                    resetTranscriberState()
                    return
                }
                
                if currentCallID != callId {
                    currentCallID = callId
                    transcriberCancelables.removeAll()
                    let transcriberStore = AITranscriberStore.create(roomID: currentCallID)
                    self.transcriberStore = transcriberStore
                    transcriberView.bindTranscriberStore(roomID: currentCallID)
                    subscribeTranscriberState()
                }
            }
            .store(in: &cancellables)
        
        CallViewStore.shared.observerState
            .subscribe(StatePublisherSelector(keyPath: \.isShowTranscriberPanel))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTranscriberState()
            }
            .store(in: &cancellables)
    }
}

extension CallTranscriberView {
    
    private func subscribeTranscriberState() {
        transcriberStore?.state.subscribe(StatePublisherSelector(keyPath: \.realtimeMessageList))
            .receive(on: RunLoop.main)
            .map { $0.isEmpty }
            .sink { [weak self] isEmpty in
                guard let self = self else { return }
                isTranscriberEmpty = isEmpty
                updateTranscriberState()
            }
            .store(in: &transcriberCancelables)
        
        transcriberStore?.state.subscribe(StatePublisherSelector(keyPath: \.isTranscriptionRunning))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isRunning in
                guard let self = self else { return }
                isTranscriptionRunning = isRunning
                if !isRunning {
                    transcriberView.clearMessages()
                }
                updateTranscriberState()
            }
            .store(in: &transcriberCancelables)
    }
    
    private func resetTranscriberState() {
        isTranscriberEmpty = true
        isTranscriptionRunning = false
        transcriberView.clearMessages()
        updateTranscriberState()
    }
    
    private func handleCallAcceptStateChanged(_ isAccepted: Bool) {
        isCallAccepted = isAccepted
        updateTranscriberState()
    }
    
    private func updateTranscriberState() {
        let isShowPanel = CallViewStore.shared.state.isShowTranscriberPanel
        let shouldShowButton = isCallAccepted && isEnabled
        let shouldShowContent = shouldShowButton && isShowPanel
        
        transcriberButton.isHidden = !shouldShowButton
        transcriberButton.isSelected = isShowPanel
        transcriberView.isHidden = !shouldShowContent
        emptyHintLabel.isHidden = !(shouldShowContent && isTranscriberEmpty)
    }
}
