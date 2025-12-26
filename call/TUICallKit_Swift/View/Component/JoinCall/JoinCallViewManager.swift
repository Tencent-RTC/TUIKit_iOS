//
//  JoinCallViewManager.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import UIKit
import RTCRoomEngine
import ImSDK_Plus
import TUICore
import Combine
import AtomicXCore

class JoinCallViewManager: NSObject, V2TIMGroupListener, JoinCallViewDelegate {
    
    private override init() {
        super.init()
        V2TIMManager.sharedInstance().addGroupListener(listener: self)
        subscribeCallState()
    }
    
    // MARK: Private
    private var cancellables = Set<AnyCancellable>()
    private var joinGroupCallView = JoinCallView()
    private var roomId = TUIRoomId()
    private var groupId: String = ""
    private var callId: String = ""
    private var callMediaType: CallMediaType? = nil
    
    private var recordExpansionStatus: Bool = false
    
    static let shared = JoinCallViewManager()
    
    deinit {
        cancellables.forEach { $0.cancel() }
        V2TIMManager.sharedInstance().removeGroupListener(listener: self)
    }
    
    func getGroupAttributes(_ groupID: String) {
        self.groupId = groupID
        self.recordExpansionStatus = false
        let selfStatus = CallStore.shared.state.value.selfInfo.status
        guard selfStatus == .none else {
            return
        }
        V2TIMManager.sharedInstance().getGroupAttributes(groupID, keys: nil) { [weak self] groupAttributeList in
            guard let self = self, let attributeList = groupAttributeList as? [String: String] else {
                return
            }
            self.processGroupAttributeData(attributeList)
        } fail: { code, message in
        }
    }
    
    func setJoinGroupCallView(_ view: JoinCallView) {
        joinGroupCallView = view
        joinGroupCallView.delegate = self
        joinGroupCallView.isHidden = true
    }
    
    // MARK: - Private Method
    private func processGroupAttributeData(_ groupAttributeList: [String: String]) {
        guard let jsonStr = groupAttributeList["inner_attr_kit_info"], !jsonStr.isEmpty,
              let jsonData = jsonStr.data(using: .utf8),
              let groupAttributeDic = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
              checkBusinessType(groupAttributeDic) else {
            hiddenJoinGroupCallView()
            return
        }
        
        handleRoomId(groupAttributeDic)
        handleCallMediaType(groupAttributeDic)
        handleCallId(groupAttributeDic)
        
        guard let userIdList = getUserIdList(groupAttributeDic), !userIdList.isEmpty else {
            hiddenJoinGroupCallView()
            return
        }
        
        let selfId = CallStore.shared.state.value.selfInfo.id
        if userIdList.contains(selfId) {
            hiddenJoinGroupCallView()
            return
        }
        
        handleUsersInfo(userIdList)
    }
    
    private func checkBusinessType(_ groupAttributeValue: [String: Any]) -> Bool {
        guard let businessType = groupAttributeValue["business_type"] as? String else {
            return false
        }
        return businessType == "callkit"
    }
    
    private func handleRoomId(_ groupAttributeValue: [String: Any]) {
        guard let strRoomId = groupAttributeValue["room_id"] as? String, !strRoomId.isEmpty else {
            return
        }
        
        if groupAttributeValue["room_id_type"] as? Int == 2 {
            roomId.strRoomId = strRoomId
        } else if let intRoomId = UInt32(strRoomId) {
            roomId.intRoomId = intRoomId
        } else {
            roomId.strRoomId = strRoomId
        }
    }
    
    private func handleCallMediaType(_ groupAttributeValue: [String: Any]) {
        guard let callMediaTypeStr = groupAttributeValue["call_media_type"] as? String, !callMediaTypeStr.isEmpty else {
            return
        }
        
        if callMediaTypeStr == "audio" {
            self.callMediaType = .audio
        } else if callMediaTypeStr == "video" {
            self.callMediaType = .video
        }
    }
    
    private func handleCallId(_ groupAttributeValue: [String: Any]) {
        self.callId = groupAttributeValue["call_id"] as? String ?? ""
    }
    
    private func getUserIdList(_ groupAttributeValue: [String: Any]) -> [String]? {
        guard let userInfoList = groupAttributeValue["user_list"] as? [[String: Any]] else {
            return nil
        }
        return userInfoList.compactMap { $0["userid"] as? String }
    }
    
    private func handleUsersInfo(_ userIdList: [String]) {
        V2TIMManager.sharedInstance().getUsersInfo(userIdList) { [weak self] infoList in
            guard let self = self, let userInfoList = infoList else { return }
    
            let participants = userInfoList.map { userInfo -> CallParticipantInfo in
                var participant = CallParticipantInfo()
                participant.id = userInfo.userID ?? ""
                participant.avatarURL = userInfo.faceURL ?? ""
                participant.name = userInfo.nickName ?? ""
                return participant
            }
            
            if participants.count > 0 {
                self.showJoinGroupCallView()
                self.joinGroupCallView.updateView(with: participants, callMediaType: self.callMediaType)
            } else {
                self.hiddenJoinGroupCallView()
            }
        } fail: { code, message in
        }
    }
    
    private func showJoinGroupCallView() {
        joinGroupCallView.isHidden = false
        updatePageContent()
        postUpdateNotification()
    }
    
    func hiddenJoinGroupCallView() {
        joinGroupCallView.isHidden = true
        if let parentView = joinGroupCallView.superview {
            parentView.frame = CGRect(x: 0, y: 0, width: parentView.bounds.width, height: 0)
            postUpdateNotification()
        }
    }
    
    func updatePageContent() {
        DispatchQueue.main.async {
            let height = self.recordExpansionStatus ? kJoinGroupCallViewExpandHeight : kJoinGroupCallViewDefaultHeight
            self.joinGroupCallView.frame.size.height = height
            if let parentView = self.joinGroupCallView.superview {
                parentView.frame.size.height = height
            }
        }
    }
    
    func postUpdateNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(TUICore_TUIChatExtension_ChatViewTopArea_ChangedNotification), object: nil)
        }
    }
    
    func updatePageContent(isExpand: Bool) {
        if recordExpansionStatus != isExpand {
            recordExpansionStatus = isExpand
        }
        updatePageContent()
        postUpdateNotification()
    }
    
    func joinCall() {
        hiddenJoinGroupCallView() 
        guard !callId.isEmpty else { return }
        TUICallKit.createInstance().join(callId: callId, completion: nil)
    }
    
    // MARK: - V2TIMGroupListener
    func onGroupAttributeChanged(_ groupID: String!, attributes: NSMutableDictionary!) {
        guard let attributes = attributes as? [String: String],
              groupId == groupID else {
            return
        }
        
        let selfStatus = CallStore.shared.state.value.selfInfo.status
        if selfStatus != .none {
            self.hiddenJoinGroupCallView()
            return
        }
        processGroupAttributeData(attributes)
    }
}

// MARK: Subscribe
extension JoinCallViewManager {
    func subscribeCallState() {
        let statusSelector = StatePublisherSelector<CallState, CallParticipantStatus>(keyPath: \CallState.selfInfo.status)
        
        CallStore.shared.state
            .subscribe(statusSelector)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }
                if newStatus == .none && !self.groupId.isEmpty {
                    self.getGroupAttributes(self.groupId)
                }
            }
            .store(in: &cancellables)
    }
}
