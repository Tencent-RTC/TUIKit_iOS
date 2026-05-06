//
//  WebinarRoomView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/1/30.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore
import RTCRoomEngine

struct VideoView {
    var userID: String = ""
    var videoView: UIView = UIView()
}

// MARK: - WebinarRoomView Component
class WebinarRoomView: UIView, BaseView {
    public weak var routerContext: RouterContext?
    private let roomID: String
    
    // MARK: - UI Components
    private var mixVideoView = VideoView()
    private var multiStreamView = VideoView()
    
    private lazy var avatarBackgroundView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = RoomColors.avatarBackgroundColor
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.layer.cornerRadius = 32
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let roomEngine = TUIRoomEngine.sharedInstance()
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private var pushVideoParticipant: RoomParticipant?
    private var cancellableSet = Set<AnyCancellable>()
    
    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("\(type(of: self)) deinit")
        roomEngine.removeObserver(self)
        clearVideoView()
    }
    
    // MARK: - BaseView Implementation
    public func setupViews() {
        addSubview(mixVideoView.videoView)
        addSubview(multiStreamView.videoView)
        addSubview(avatarBackgroundView)
        avatarBackgroundView.addSubview(avatarImageView)
    }
    
    public func setupConstraints() {
        mixVideoView.videoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        multiStreamView.videoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        avatarBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 64, height: 64))
        }
    }
    
    public func setupStyles() {
        backgroundColor = .clear
    }
    
    public func setupBindings() {
        // MARK: - Real Data Binding
        roomEngine.addObserver(self)
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                let seatList = roomEngine.querySeatList()
                guard let firstSeatUserID = seatList.first?.userId else {
                    return
                }
                let pushVideoUser = participantList.first { $0.userID == firstSeatUserID }
                guard let pushVideoUser = pushVideoUser, pushVideoUser != pushVideoParticipant else { return }
                RoomKitLog.info("pushVideoUser state changed, userID: \(pushVideoUser.userID), cameraStatus: \(pushVideoUser.cameraStatus)")
                pushVideoParticipant = pushVideoUser
                avatarImageView.kf.setImage(with: URL(string: pushVideoUser.avatarURL),
                                            placeholder: ResourceLoader.loadImage("avatar_placeholder"))
                avatarBackgroundView.isHidden = pushVideoUser.cameraStatus == .on
            }
            .store(in: &cancellableSet)
    }
    
    private func clearVideoView() {
        if !mixVideoView.userID.isEmpty {
            roomEngine.setRemoteVideoView(userId: mixVideoView.userID, streamType: .cameraStream, view: nil)
        }
        
        if !multiStreamView.userID.isEmpty {
            roomEngine.setRemoteVideoView(userId: multiStreamView.userID, streamType: .cameraStream, view: nil)
        }
    }
}

extension WebinarRoomView: TUIRoomObserver {
    func onUserVideoStateChanged(userId: String, streamType: TUIVideoStreamType, hasVideo: Bool, reason: TUIChangeReason) {
        RoomKitLog.info("onUserVideoStateChanged userID: \(userId), streamType: \(streamType), hasVideo: \(hasVideo), reason: \(reason)")
        let isMixUser = userId.contains("_feedback_")
        if userId == LoginStore.shared.state.value.loginUserInfo?.userID {
            return
        }
        
        if hasVideo {
            if isMixUser {
                mixVideoView.userID = userId
                roomEngine.setRemoteVideoView(userId: userId, streamType: .cameraStream, view: mixVideoView.videoView)
            } else {
                multiStreamView.userID = userId
                roomEngine.setRemoteVideoView(userId: userId, streamType: .cameraStream, view: multiStreamView.videoView)
            }
            roomEngine.startPlayRemoteVideo(userId: userId,
                                            streamType: .cameraStream) { userID in
                RoomKitLog.info("self: \(self) onPlaying userID: \(userID)")
            } onLoading: { userID in
                RoomKitLog.info("self: \(self) onLoading userID: \(userID)")
            } onError: { userID, error, message in
                RoomKitLog.error("self: \(self) onError userID: \(userID), error: \(error), message: \(message)")
            }
        } else {
            roomEngine.stopPlayRemoteVideo(userId: userId, streamType: .cameraStream)
        }
    }
}
