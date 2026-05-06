//
//  ScreenShareGuideView.swift
//  TUILiveKit
//
//  Created by chensshi on 2026/3/23.
//

import UIKit
import ReplayKit

private let kTUIKitReplay = "TRTC"

class ScreenShareGuideView: UIView {
    
    var onCancel: (() -> Void)?
    var onStartBroadcast: (() -> Void)?
    
    private var screenCaptureObservation: NSKeyValueObservation?
    var onScreenCaptureStarted: (() -> Void)?
    
    // MARK: - UI Elements
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .selectAppText
        label.textColor = .white
        label.font = .customFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var systemPickerMockView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        view.layer.cornerRadius = 14
        view.layer.masksToBounds = true

        let recordIcon = RecordIconView()
        view.addSubview(recordIcon)
        recordIcon.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
            make.width.height.equalTo(24)
        }
        
        let liveScreenLabel = UILabel()
        liveScreenLabel.text = .liveScreenText
        liveScreenLabel.textColor = .white
        liveScreenLabel.font = .customFont(ofSize: 12, weight: .regular)
        liveScreenLabel.textAlignment = .center
        view.addSubview(liveScreenLabel)
        liveScreenLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(recordIcon.snp.bottom).offset(6)
        }
        
        let divider1 = UIView()
        divider1.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        view.addSubview(divider1)
        divider1.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(liveScreenLabel.snp.bottom).offset(10)
            make.height.equalTo(0.5)
        }
        
        // TUIKitReplay row
        let rowContainer = UIView()
        view.addSubview(rowContainer)
        rowContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(divider1.snp.bottom)
            make.height.equalTo(50)
        }
        
        let appIcon = UIView()
        appIcon.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        appIcon.layer.cornerRadius = 7
        rowContainer.addSubview(appIcon)
        appIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(26)
        }
        
        let cameraIcon = UIImageView()
        cameraIcon.image = UIImage(systemName: "video.fill")
        cameraIcon.tintColor = .white
        appIcon.addSubview(cameraIcon)
        cameraIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(16)
            make.height.equalTo(12)
        }
        
        let appNameLabel = UILabel()
        appNameLabel.text = kTUIKitReplay
        appNameLabel.textColor = .white
        appNameLabel.font = .customFont(ofSize: 12, weight: .regular)
        rowContainer.addSubview(appNameLabel)
        appNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(appIcon.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        
        let checkIcon = UIImageView()
        checkIcon.image = UIImage(systemName: "checkmark")
        checkIcon.tintColor = .white
        rowContainer.addSubview(checkIcon)
        checkIcon.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }
        
        let divider2 = UIView()
        divider2.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        view.addSubview(divider2)
        divider2.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(rowContainer.snp.bottom)
            make.height.equalTo(0.5)
        }
        
        // Start live button
        let startLabel = UILabel()
        startLabel.text = .startLiveText
        startLabel.textColor = .white
        startLabel.font = .customFont(ofSize: 12, weight: .regular)
        startLabel.textAlignment = .center
        view.addSubview(startLabel)
        startLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(divider2.snp.bottom).offset(14)
            make.bottom.equalToSuperview().offset(-14)
        }
        
        return view
    }()
    
    private lazy var bottomDivider: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        return view
    }()
    
    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(.cancelText, for: .normal)
        btn.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        btn.titleLabel?.font = .customFont(ofSize: 14, weight: .regular)
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return btn
    }()
    
    private lazy var confirmButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(.goToEnableText, for: .normal)
        btn.setTitleColor(UIColor(red: 0.25, green: 0.52, blue: 1.0, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = .customFont(ofSize: 14, weight: .medium)
        btn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return btn
    }()
    
    private lazy var buttonDivider: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        return view
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupUI()
        startObservingScreenCapture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        screenCaptureObservation?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(systemPickerMockView)
        containerView.addSubview(bottomDivider)
        containerView.addSubview(cancelButton)
        containerView.addSubview(buttonDivider)
        containerView.addSubview(confirmButton)
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        systemPickerMockView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        bottomDivider.snp.makeConstraints { make in
            make.top.equalTo(systemPickerMockView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(bottomDivider.snp.bottom)
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(52)
        }
        
        buttonDivider.snp.makeConstraints { make in
            make.leading.equalTo(cancelButton.snp.trailing)
            make.top.equalTo(bottomDivider.snp.bottom)
            make.bottom.equalToSuperview()
            make.width.equalTo(0.5)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.leading.equalTo(buttonDivider.snp.trailing)
            make.trailing.equalToSuperview()
            make.top.equalTo(bottomDivider.snp.bottom)
            make.bottom.equalToSuperview()
            make.width.equalTo(cancelButton)
            make.height.equalTo(52)
        }
    }
    
    // MARK: - Screen Capture Observation
    
    private func startObservingScreenCapture() {
        screenCaptureObservation = UIScreen.main.observe(\.isCaptured, options: [.new]) { [weak self] _, change in
            guard let self = self, let isCaptured = change.newValue, isCaptured else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onScreenCaptureStarted?()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        onCancel?()
    }
    
    @objc private func confirmTapped() {
        onStartBroadcast?()
    }
}

// MARK: - RecordIconView

private class RecordIconView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = rect.width / 2 - 1.5
        let innerRadius = rect.width * 0.22
        
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2.5)
        ctx.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ctx.strokePath()
        
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.addArc(center: center, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ctx.fillPath()
    }
}

// MARK: - Localized Strings

private extension String {
    static let selectAppText = internalLocalized("common_select_app_to_live")
    static let liveScreenText = internalLocalized("common_live_screen")
    static let startLiveText = internalLocalized("common_start_live")
    static let cancelText = internalLocalized("common_cancel")
    static let goToEnableText = internalLocalized("common_go_to_enable")
}
