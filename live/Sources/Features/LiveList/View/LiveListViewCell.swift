//
//  LiveListVIewCell.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/4/15.
//

import AtomicXCore
import TUICore

class LiveListViewCell: UICollectionViewCell {
    static let identifier = "LiveListViewCell"
    
    var coreView: LiveCoreView?
    
    private lazy var imageBgView: UIImageView = {
        let view = UIImageView(frame: .zero)
        return view
    }()
    
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: effect)
        blurView.isHidden = true
        return blurView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        addSubview(imageBgView)
        addSubview(blurView)
        imageBgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if coreView?.isEnteredRoom ?? false {
            coreView = nil
            return
        }
        stopPreload()
        coreView?.safeRemoveFromSuperview()
        coreView = nil
    }
    
    func addBlurEffect() {
        blurView.isHidden = false
    }
    
    func removeBlurEffect() {
        blurView.isHidden = true
    }
    
    func updateView(liveInfo: LiveInfo) {
        imageBgView.sd_setImage(with: URL(string: liveInfo.coverURL),
                                placeholderImage: internalImage("live_edit_info_default_cover_image"))
    }
    
    func startPreload(roomId: String, isMuteAudio: Bool = true) {
        if let playingLiveID = coreView?.playingLiveID, playingLiveID == roomId {
            if let mute = coreView?.isMuteAudio, mute != isMuteAudio {
                mutePreviewVideoStream(isMute: isMuteAudio)
            }
            return
        }
        if FloatWindow.shared.isShowingFloatWindow(), FloatWindow.shared.getCurrentRoomId() == roomId {
            LiveKitLog.info("\(#file)", "\(#line)", "float window view is showing, startPreload ignore, roomId: \(roomId)")
            return
        }
        if let coreView = coreView, !coreView.isEnteredRoom {
            coreView.stopAndRemoveFromSuperView()
        }
        let coreView = LiveCoreView.getCachedCoreView(liveID: roomId, type: .playView)
        self.coreView = coreView
        insertSubview(coreView, aboveSubview: blurView)
        coreView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        coreView.startPreviewLiveStream(roomId: roomId, isMuteAudio: isMuteAudio) { [weak self] _ in
            guard let self = self else { return }
            self.coreView?.playingLiveID = roomId
            self.coreView?.isMuteAudio = isMuteAudio
        } onLoading: { _ in
        } onError: { _, _, _ in
            LiveKitLog.info("\(#file)", "\(#line)", "startPreviewLiveStream failed: \(roomId)")
        }
    }
    
    func stopPreload() {
        guard let coreView = coreView, let roomId = coreView.playingLiveID else { return }
        if FloatWindow.shared.isShowingFloatWindow(), FloatWindow.shared.getCurrentRoomId() == roomId {
            LiveKitLog.info("\(#file)", "\(#line)", "float window view is showing, stopPreload ignore, roomId: \(String(describing: roomId))")
            return
        }
        if coreView.isEnteredRoom {
            return
        }
        coreView.stopPreviewLiveStream(roomId: roomId)
        coreView.playingLiveID = nil
        coreView.isMuteAudio = nil
    }
    
    func mutePreviewVideoStream(isMute: Bool) {
        guard let roomId = coreView?.playingLiveID else { return }
        if FloatWindow.shared.isShowingFloatWindow(), let ownerId = FloatWindow.shared.getRoomOwnerId(), ownerId == LoginStore.shared.state.value.loginUserInfo?.userID {
            LiveKitLog.info("\(#file)", "\(#line)", "Anchor FloatWindow is showing, unmutePreviewVideoStream ignore, roomId:\(roomId)")
            return
        }
        LiveKitLog.info("\(#file)", "\(#line)", "unmutePreviewVideoStream roomId:\(roomId)")
        coreView?.startPreviewLiveStream(roomId: roomId, isMuteAudio: isMute) { [weak self] _ in
            guard let self = self else { return }
            coreView?.isMuteAudio = isMute
        } onLoading: { _ in
        } onError: { _, _, _ in
            LiveKitLog.info("\(#file)", "\(#line)", "startPreviewLiveStream failed: \(roomId)")
        }
    }
}

private var playingLiveIDKeyTag: UInt8 = 0
private var isMuteAudioKeyTag: UInt8 = 0
extension LiveCoreView {
    var playingLiveID: String? {
        set {
            objc_setAssociatedObject(self, &playingLiveIDKeyTag, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, &playingLiveIDKeyTag) as? String
        }
    }
    
    var isMuteAudio: Bool? {
        set {
            objc_setAssociatedObject(self, &isMuteAudioKeyTag, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        get {
            objc_getAssociatedObject(self, &isMuteAudioKeyTag) as? Bool
        }
    }
    
    var isEnteredRoom: Bool {
        LiveListStore.shared.state.value.currentLive.liveID == playingLiveID
    }
    
    func stopAndRemoveFromSuperView() {
        if let liveID = playingLiveID {
            stopPreviewLiveStream(roomId: liveID)
            playingLiveID = nil
            isMuteAudio = nil
        }
        if superview != nil {
            removeFromSuperview()
        }
    }
}
