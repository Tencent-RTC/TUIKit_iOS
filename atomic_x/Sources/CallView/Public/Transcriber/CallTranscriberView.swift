//
//  CallTranscriberView.swift
//  AtomicX
//
//  Created on 2026/1/29.
//

import UIKit
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
    private var isCallAccepted = false
    
    private lazy var transcriberButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(CallKitBundle.getBundleImage(name: "icon_ai_transcriber_off"), for: .normal)
        button.setBackgroundImage(CallKitBundle.getBundleImage(name: "icon_ai_transcriber_on"), for: .selected)
        button.isSelected = false
        button.isHidden = true
        button.addTarget(self, action: #selector(transcriberButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let transcriberView = TranscriberView(frame: .zero)
    
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
        addSubview(transcriberButton)
    }
    
    private func activateConstraints() {
        transcriberView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.95)
            make.bottom.equalToSuperview()
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
        transcriberButton.isSelected.toggle()
        updateTranscriberState()
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
    }
}

extension CallTranscriberView {
    private func handleCallAcceptStateChanged(_ isAccepted: Bool) {
        isCallAccepted = isAccepted
        transcriberButton.isSelected = isAccepted && isEnabled
        updateTranscriberState()
    }
    
    private func updateTranscriberState() {
        let shouldShowButton = isCallAccepted && isEnabled
        let shouldShowTranscriber = shouldShowButton && transcriberButton.isSelected
        
        transcriberButton.isHidden = !shouldShowButton
        transcriberView.isHidden = !shouldShowTranscriber
    }
}
