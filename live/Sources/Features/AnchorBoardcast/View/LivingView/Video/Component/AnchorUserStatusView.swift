//
//  UserStatusView.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/31.
//

import Foundation
import TUICore
import Combine
import RTCRoomEngine
import RTCCommon
import AtomicXCore

class AnchorUserStatusView: UIView {
    private let store: AnchorStore
    private var cancellableSet = Set<AnyCancellable>()
    private var muteAudio: Bool = true
    private var isViewReady: Bool = false
    private let seatInfo: SeatInfo
    
    init(seatInfo: SeatInfo, store: AnchorStore) {
        self.seatInfo = seatInfo
        self.store = store
        super.init(frame: .zero)
        muteAudio = seatInfo.userInfo.microphoneStatus == .off
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        updateAudioStatus()
    }
    
    private lazy var userNameLabel: UILabel = {
        let user = UILabel()
        user.textColor = .white
        user.backgroundColor = UIColor.clear
        user.textAlignment = TUIGlobalization.getRTLOption() ? .right : .left
        user.numberOfLines = 1
        user.font = .customFont(ofSize: 9)
        return user
    }()
    
    private lazy var voiceMuteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("live_audio_mute_icon")
        return imageView
    }()
    
    private func constructViewHierarchy() {
        addSubview(userNameLabel)
        addSubview(voiceMuteImageView)
    }
    
    private func activateConstraints() {
        voiceMuteImageView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.width.height.equalTo(muteAudio ? 14 : 0)
            make.centerY.equalToSuperview()
        }
        
        userNameLabel.snp.remakeConstraints { make in
            make.leading.equalTo(voiceMuteImageView.snp.trailing).offset(muteAudio ? 2 : 0)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-8)
        }
    }
    
    private func setupViewStyle() {
        backgroundColor = .g2.withAlphaComponent(0.4)
        layer.cornerRadius = 9
        layer.masksToBounds = true
        userNameLabel.text = seatInfo.userInfo.userName.isEmpty ? seatInfo.userInfo.userID : seatInfo.userInfo.userName
    }
    
    private func updateAudioStatus() {
        voiceMuteImageView.isHidden = !muteAudio
        activateConstraints()
    }
}
