//
//  PictureInPictureTogglePanel.swift
//  TUILiveKit
//
//  Created by gg on 2025/12/9.
//

import AtomicXCore
import AVKit
import Combine
import RTCCommon
import UIKit

class PictureInPictureTogglePanel: RTCBaseView {
    private let liveID: String
    private var cancellableSet: Set<AnyCancellable> = []
    
    private var liveListStore: LiveListStore {
        return LiveListStore.shared
    }
    
    // MARK: - UI Components

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .titleText
        label.font = .customFont(ofSize: 18, weight: .medium)
        label.textColor = .g7
        return label
    }()
    
    private lazy var pipSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.onTintColor = .b1
        switchControl.isOn = PictureInPictureStore.shared.state.state.enablePictureInPictureToggle && hasPictureInPicturePermission()
        switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        return switchControl
    }()
    
    private lazy var pipTitleLabel: UILabel = {
        let label = UILabel()
        label.text = .pipTitleText
        label.font = .customFont(ofSize: 16, weight: .medium)
        label.textColor = .g7
        return label
    }()
    
    private lazy var pipDescLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = .pipDescText
        label.font = .customFont(ofSize: 14, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.549)
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Initialization
    
    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - RTCBaseView Override
    
    override func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(pipTitleLabel)
        addSubview(pipSwitch)
        addSubview(pipDescLabel)
    }
    
    override func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375Height())
            make.centerX.equalToSuperview()
        }
        
        pipTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16.scale375Width())
            make.top.equalTo(titleLabel.snp.bottom).offset(12.scale375Height())
        }
        
        pipSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16.scale375Width())
            make.centerY.equalTo(pipTitleLabel)
        }
        
        pipDescLabel.snp.makeConstraints { make in
            make.top.equalTo(pipTitleLabel.snp.bottom).offset(12.scale375Height())
            make.leading.equalTo(pipTitleLabel)
            make.trailing.lessThanOrEqualTo(pipSwitch.snp.trailing)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    override func setupViewStyle() {
        backgroundColor = .bgOperateColor
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
    @objc private func switchValueChanged(_ sender: UISwitch) {
        var isEnabled = sender.isOn
        if isEnabled, !hasPictureInPicturePermission() {
            isEnabled = false
            showAtomicToast(text: .pipPermissionTitleText)
        }
        PictureInPictureStore.shared.enablePictureInPicture(enable: isEnabled, liveID: liveID)
    }
    
    private func hasPictureInPicturePermission() -> Bool {
        if #available(iOS 15.0, *) {
            return AVPictureInPictureController.isPictureInPictureSupported()
        }
        return false
    }
}

// MARK: - Localized Strings

private extension String {
    static let titleText = internalLocalized("common_video_settings_item_pip")
    static let pipTitleText = internalLocalized("common_pip_toggle")
    static let pipDescText = internalLocalized("common_pip_toggle_description")
    
    static let pipPermissionTitleText = internalLocalized("common_server_error_insufficient_operation_permissions")
}
