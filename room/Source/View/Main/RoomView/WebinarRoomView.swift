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
import TXLiteAVSDK_Professional

struct VideoView {
    var userID: String = ""
    var videoView: UIView = UIView()
}

protocol WebinarRoomViewDelegate: AnyObject {
    func onRoomViewLayoutChanged(isLandscape: Bool, canvas: WebinarCanvas)
}

// MARK: - WebinarRoomView Component
class WebinarRoomView: UIView, BaseView {
    public weak var routerContext: RouterContext?
    public weak var delegate: WebinarRoomViewDelegate?
    private let roomID: String
    private let videoLandscapeTemplateID = 201
    private let roomEngine = TUIRoomEngine.sharedInstance()
    
    // MARK: - UI Components
    private var mixVideoView = VideoView()
    private var multiStreamViewContainer = UIView()
    private var widgetViewContainer = UIView()
    
    private var videoViewMap: [String : UIView] = [:]
    private var widgetViewMap: [String : RoomWidgetView] = [:]
    private var lastSeatList: [WebinarSeatInfo] = []
    private var canvasTemplateID: Int?
    private var canvasFillMode: Int?
    
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
        addSubview(multiStreamViewContainer)
        addSubview(widgetViewContainer)
    }
    
    public func setupConstraints() {
        mixVideoView.videoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        multiStreamViewContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        widgetViewContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    public func setupStyles() {
        backgroundColor = .clear
    }
    
    public func setupBindings() {
        // MARK: - Real Data Binding
        roomEngine.addObserver(self)
    }
    
    private func clearVideoView() {
        lastSeatList = []
        if !mixVideoView.userID.isEmpty {
            roomEngine.setRemoteVideoView(userId: mixVideoView.userID, streamType: .cameraStream, view: nil)
        }
        
        if !videoViewMap.isEmpty {
            videoViewMap.forEach { info in
                if info.key == LoginStore.shared.state.value.loginUserInfo?.userID {
                    roomEngine.setLocalVideoView(view: nil)
                } else {
                    roomEngine.setRemoteVideoView(userId: info.key, streamType: .cameraStream, view: nil)
                }
            }
        }
        
        multiStreamViewContainer.subviews.forEach { subView in
            subView.removeFromSuperview()
        }
        
        widgetViewContainer.subviews.forEach { subView in
            subView.removeFromSuperview()
        }
        
        videoViewMap.removeAll()
        widgetViewMap.removeAll()
    }
    
    private func updateRoomViewLayoutSize() {
        queryRoomCanvas { [weak self] canvas in
            guard let self = self else { return }
            guard let canvas = canvas else { return }
            let templateID = canvas.templateID
            canvasFillMode = canvas.fillMode
            if templateID == canvasTemplateID { return }
            delegate?.onRoomViewLayoutChanged(isLandscape: templateID == videoLandscapeTemplateID, canvas: canvas)
            canvasTemplateID = templateID
        }
    }
    
    private func queryRoomCanvas(completion: @escaping (WebinarCanvas?) -> Void) {
        let jsonObject: [String: Any] = [
            "api": "querySeatLayout",
            "params": [
                "roomId": roomID
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            RoomKitLog.error("callExperimentalAPI querySeatLayout failed: JSON serialization error")
            completion(nil)
            return
        }
        
        roomEngine.callExperimentalAPI(jsonStr: jsonStr) { jsonData in
            RoomKitLog.info("callExperimentalAPI querySeatLayout response: \(jsonData)")
            let canvas = convertJsonToWebinarCanvas(jsonString: jsonData)
            completion(canvas)
        }
    }
    
    private func getSeatRegionBySeatIndex(seatList: [WebinarSeatInfo], seatInfo: WebinarSeatInfo) -> WebinarSeatInfo? {
        let result = seatList.filter { $0.index == seatInfo.index }
        return result.first
    }
}

extension WebinarRoomView {
    private func setLocalVideoView(deviceStatus: DeviceStatus, videoView: UIView) {
        if deviceStatus == .on {
            roomEngine.setLocalVideoView(view: videoView)
        } else {
            roomEngine.setLocalVideoView(view: nil)
        }
    }
    
    private func setVideoRenderMode(userID: String, fillMode: Int?) {
        let params = TRTCRenderParams()
        params.fillMode = fillMode == 0 ? .fit : .fill
        roomEngine.getTRTCCloud().setRemoteRenderParams(userID, streamType: .big, params: params)
    }
}

extension WebinarRoomView {
    private func compareSeatRegionIsSame(oldSeatInfo: WebinarSeatInfo?, newSeatInfo: WebinarSeatInfo?) -> Bool {
        if oldSeatInfo == nil || newSeatInfo == nil {
            return false
        }
        return oldSeatInfo == newSeatInfo
    }
    
    private func getVideoViewByUserID(userID: String) -> UIView {
        RoomKitLog.info("getVideoViewByUserID:userID\(userID)")
        if let videoView = videoViewMap[userID] {
            return videoView
        }
        let videoView = UIView()
        videoViewMap.updateValue(videoView, forKey: userID)
        return videoView
    }
    
    private func getWidgetViewByUserID(participant: RoomParticipant) -> UIView {
        RoomKitLog.info("getWidgetViewByUserID:userID\(participant.userID)")
        if let widgetView = widgetViewMap[participant.userID] {
            return widgetView
        }
        
        let widgetView = RoomWidgetView()
        widgetView.setParticipant(participant: participant)
        widgetViewMap.updateValue(widgetView, forKey: participant.userID)
        return widgetView
    }
    
    private func addSeatRegionView(seatInfo: WebinarSeatInfo) {
        addVideoView(seatInfo: seatInfo)
        addWidgetsView(seatInfo: seatInfo)
    }
    
    private func addVideoView(seatInfo: WebinarSeatInfo) {
        RoomKitLog.info("addVideoView:seatInfo\(seatInfo)")
        if seatInfo.region.w <= 0 || seatInfo.region.h <= 0 {
            return
        }
        
        let userID = seatInfo.participant.userID
        let videoView = getVideoViewByUserID(userID: userID)
        if LoginStore.shared.state.value.loginUserInfo?.userID == userID {
            setLocalVideoView(deviceStatus: seatInfo.participant.cameraStatus, videoView: videoView)
        } else if !userID.isEmpty {
            roomEngine.setRemoteVideoView(userId: userID, streamType: .cameraStream, view: videoView)
            setVideoRenderMode(userID: userID, fillMode: canvasFillMode)
        }
        
        if multiStreamViewContainer.subviews.contains(videoView) {
            return
        }
        
        multiStreamViewContainer.addSubview(videoView)
        videoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func addWidgetsView(seatInfo: WebinarSeatInfo) {
        RoomKitLog.info("addWidgetsView:seatInfo\(seatInfo)")
        if seatInfo.region.w <= 0 || seatInfo.region.h <= 0 {
            return
        }
        
        let widgetView = getWidgetViewByUserID(participant: seatInfo.participant)
        widgetViewContainer.addSubview(widgetView)
        widgetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func removeSeatRegionView(seatInfo: WebinarSeatInfo) {
        removeVideoView(seatInfo: seatInfo)
        removeWidgetsView(seatInfo: seatInfo)
    }
    
    private func removeVideoView(seatInfo: WebinarSeatInfo) {
        RoomKitLog.info("removeVideoView:seatInfo\(seatInfo)")
        if let videoView = videoViewMap[seatInfo.participant.userID], multiStreamViewContainer.subviews.contains(videoView) {
            videoView.removeFromSuperview()
        }
        videoViewMap.removeValue(forKey: seatInfo.participant.userID)
    }
    
    private func removeWidgetsView(seatInfo: WebinarSeatInfo) {
        RoomKitLog.info("removeWidgetsView:seatInfo\(seatInfo)")
        if let widgetView = widgetViewMap[seatInfo.participant.userID], widgetViewContainer.subviews.contains(widgetView) {
            widgetView.removeFromSuperview()
        }
        widgetViewMap.removeValue(forKey: seatInfo.participant.userID)
    }
    
    private func updateVideoAndWidgetView(oldSeatInfo: WebinarSeatInfo, newSeatInfo: WebinarSeatInfo) {
        RoomKitLog.info("updateVideoAndWidgetView: oldSeatInfo:\(oldSeatInfo),newSeatInfo:\(newSeatInfo)")
        updateVideoView(oldSeatInfo: oldSeatInfo, newSeatInfo: newSeatInfo)
        updateWidgetsView(oldSeatInfo: oldSeatInfo, newSeatInfo: newSeatInfo)
    }
    
    private func updateVideoView(oldSeatInfo: WebinarSeatInfo, newSeatInfo: WebinarSeatInfo) {
        RoomKitLog.info("updateVideoView: oldSeatInfo:\(oldSeatInfo),newSeatInfo:\(newSeatInfo)")
        let videoView = getVideoViewByUserID(userID: newSeatInfo.participant.userID)
        if newSeatInfo.region.w <= 0 || newSeatInfo.region.h <= 0 {
            if multiStreamViewContainer.subviews.contains(videoView) {
                videoView.removeFromSuperview()
            }
            return
        }
        if LoginStore.shared.state.value.loginUserInfo?.userID == newSeatInfo.participant.userID {
            setLocalVideoView(deviceStatus: newSeatInfo.participant.cameraStatus, videoView: videoView)
        } else {
            let userID = newSeatInfo.participant.userID
            roomEngine.setRemoteVideoView(userId: userID, streamType: .cameraStream, view: videoView)
            setVideoRenderMode(userID: userID, fillMode: canvasFillMode)
        }
        if oldSeatInfo.region != newSeatInfo.region {
            if multiStreamViewContainer.subviews.contains(videoView) {
                videoView.removeFromSuperview()
            }
            multiStreamViewContainer.addSubview(videoView)
        }
        
    }
    
    private func updateWidgetsView(oldSeatInfo: WebinarSeatInfo, newSeatInfo: WebinarSeatInfo) {
        RoomKitLog.info("updateWidgetsView: oldSeatInfo:\(oldSeatInfo),newSeatInfo:\(newSeatInfo)")
        removeWidgetsView(seatInfo: oldSeatInfo)
        addWidgetsView(seatInfo: newSeatInfo)
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
                let videoView = getVideoViewByUserID(userID: userId)
                roomEngine.setRemoteVideoView(userId: userId, streamType: .cameraStream, view: videoView)
                setVideoRenderMode(userID: userId, fillMode: canvasFillMode)
            }
            roomEngine.startPlayRemoteVideo(userId: userId,
                                            streamType: .cameraStream) { userID in
                RoomKitLog.info("onPlaying userID: \(userID)")
            } onLoading: { userID in
                RoomKitLog.info("onLoading userID: \(userID)")
            } onError: { userID, error, message in
                RoomKitLog.error("onError userID: \(userID), error: \(error), message: \(message)")
            }
        } else {
            roomEngine.stopPlayRemoteVideo(userId: userId, streamType: .cameraStream)
        }
    }
    
    func onSeatListChanged(roomId: String, seatList: [TUISeatFullInfo], newlySeatedUsers: [TUIUserInfo], newlyLeftUsers: [TUIUserInfo]) {
        RoomKitLog.info("onSeatListChanged roomId: \(roomId), seatList: \(convertSeatListToString(seatList))")
        updateRoomViewLayoutSize()
        let seatList = seatList.map { [weak self] seatInfo in
            guard let self = self else { return WebinarSeatInfo() }
            return convertToWebinarSeatInfo(seatFullInfo: seatInfo)
        }
        
        for oldSeatInfo in lastSeatList {
            let newRegion = getSeatRegionBySeatIndex(seatList: seatList, seatInfo: oldSeatInfo)
            if newRegion == nil {
                removeSeatRegionView(seatInfo: oldSeatInfo)
            }
        }
        
        for newSeatInfo in seatList {
            if lastSeatList.isEmpty {
                addSeatRegionView(seatInfo: newSeatInfo)
                continue
            }
            
            let oldSeatInfo = getSeatRegionBySeatIndex(seatList: lastSeatList, seatInfo: newSeatInfo)
            RoomKitLog.info("updateSeatLayout, isSame:\(oldSeatInfo == newSeatInfo),oldSeatInfo:\(oldSeatInfo),newSeatInfo:\(newSeatInfo)")
            
            if let oldSeatInfo = oldSeatInfo {
                if !compareSeatRegionIsSame(oldSeatInfo: oldSeatInfo, newSeatInfo: newSeatInfo) {
                    updateVideoAndWidgetView(oldSeatInfo: oldSeatInfo, newSeatInfo: newSeatInfo)
                }
            } else {
                addSeatRegionView(seatInfo: newSeatInfo)
            }
        }
        
        lastSeatList = seatList
    }
}
