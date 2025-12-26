//
//  RecentCallsCellViewModel.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import Foundation
import UIKit
import RTCRoomEngine
import ImSDK_Plus
import TUICore
import RTCCommon
import Combine
import AtomicXCore

class RecentCallsCellViewModel: ObservableObject {
    
    @Published var avatarImage: UIImage?
    @Published var faceURL: String = ""
    @Published var titleLabelStr: String = ""
    
    var mediaTypeImageStr: String = ""
    var resultLabelStr: String = ""
    var timeLabelStr: String = ""
    
    var callInfo: CallInfo
    
    init(_ info: CallInfo) {
        callInfo = info
        
        configAvatarImage(callInfo)
        configResult(callInfo.result)
        configMediaTypeImageName(callInfo.mediaType)
        configTitle(callInfo)
        configTime(callInfo)
    }
    
    private func configAvatarImage(_ callInfo: CallInfo) {
        var userIds = callInfo.inviteeIds
        userIds.append(callInfo.inviterId)
        
        let selfUserId = CallStore.shared.state.value.selfInfo.id
        userIds = userIds.filter { $0 != selfUserId }
        
        if (!callInfo.chatGroupId.isEmpty || userIds.count >= 2) {
            var inviteList = callInfo.inviteeIds
            inviteList.insert(callInfo.inviterId, at: 0)
            configGroupAvatarImage(inviteList)
        } else {
            configSingleAvatarImage(callInfo)
        }
    }
    
    private func configGroupAvatarImage(_ inviteList: [String]) {
        if inviteList.isEmpty {
            DispatchQueue.main.async {
                self.avatarImage = TUICoreDefineConvert.getDefaultGroupAvatarImage()
            }
            return
        }
        
        let inviteStr = inviteList.sorted().joined(separator: "#")
        
        getCacheAvatarForInviteStr(inviteStr) { [weak self] avatar in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let avatar = avatar {
                    self.avatarImage = avatar
                } else {
                    V2TIMManager.sharedInstance().getUsersInfo(inviteList, succ: { infoList in
                        var avatarsList = [String]()
                        
                        infoList?.forEach { userFullInfo in
                            if let faceURL = userFullInfo.faceURL, !faceURL.isEmpty {
                                avatarsList.append(faceURL)
                            } else {
                                avatarsList.append("http://placeholder")
                            }
                        }
                        TUIGroupAvatar.createGroupAvatar(avatarsList, finished: { [weak self] image in
                            guard let self = self else { return }
                            DispatchQueue.main.async {
                                self.avatarImage = image
                            }
                            self.cacheGroupCallAvatar(image, inviteStr: inviteStr)
                        })
                    }, fail: nil)
                }
            }
        }
    }
    
    private func configSingleAvatarImage(_ callInfo: CallInfo) {
        DispatchQueue.main.async {
            self.avatarImage = TUICoreDefineConvert.getDefaultAvatarImage()
        }
        var useId = callInfo.inviterId
        
        let selfUserId = CallStore.shared.state.value.selfInfo.id
        if callInfo.inviterId == selfUserId {
            guard let firstInvite = callInfo.inviteeIds.first else { return }
            useId = firstInvite
        }
        
        if !useId.isEmpty {
            V2TIMManager.sharedInstance().getUsersInfo([useId], succ: { [weak self] infoList in
                guard let self = self else { return }
                if let userFullInfo = infoList?.first {
                    if let faceURL = userFullInfo.faceURL, !faceURL.isEmpty, faceURL.hasPrefix("http") {
                        DispatchQueue.main.async {
                            self.faceURL = faceURL
                        }
                    }
                }
            }, fail: nil)
        }
    }
    
    private func configResult(_ callResultType: CallDirection) {
        switch callResultType {
        case .missed:
            resultLabelStr = TUICallKitLocalize(key: "TUICallKit.Recents.missed") ?? "Missed"
        case .incoming:
            resultLabelStr = TUICallKitLocalize(key: "TUICallKit.Recents.incoming") ?? "Incoming"
        case .outgoing:
            resultLabelStr = TUICallKitLocalize(key: "TUICallKit.Recents.outgoing") ?? "Outgoing"
        case .unknown:
            break
        }
    }
    
    private func configMediaTypeImageName(_ callMediaType: CallMediaType?) {
        if callMediaType == .audio {
            mediaTypeImageStr = "ic_recents_audio"
        } else if callMediaType == .video {
            mediaTypeImageStr = "ic_recents_video"
        }
    }
    
    func configTitle(_ callInfo: CallInfo) {
        var userIds = callInfo.inviteeIds
        userIds.append(callInfo.inviterId)
        
        let selfUserId = CallStore.shared.state.value.selfInfo.id
        userIds = userIds.filter { $0 != selfUserId }

        DispatchQueue.main.async {
            self.titleLabelStr = ""
        }
        
        UserManager.getUserInfosFromIM(userIDs: userIds) { [weak self] infoList in
            guard let self = self else { return }
            let titleArray = infoList.map { $0.remark.count > 0
                ? $0.remark
                : $0.name.count > 0 ? $0.name : $0.id }
            DispatchQueue.main.async {
                self.titleLabelStr = titleArray.joined(separator: ",")
            }
        }
    }
    
    private func configTime(_ callInfo: CallInfo) {
        let beginTime: TimeInterval = callInfo.startTime
        if beginTime <= 0 {
            return
        }
        timeLabelStr = TUITool.convertDate(toStr: Date(timeIntervalSince1970: beginTime))
    }
    
    // MARK: - Cache
    private func getCacheAvatarForInviteStr(_ inviteStr: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = "group_call_avatar_\(inviteStr)"
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""
        let filePath = "\(cachePath)/\(cacheKey)"
        
        DispatchQueue.global(qos: .background).async {
            if FileManager.default.fileExists(atPath: filePath),
               let data = FileManager.default.contents(atPath: filePath),
               let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
    
    private func cacheGroupCallAvatar(_ avatar: UIImage, inviteStr: String) {
        let cacheKey = "group_call_avatar_\(inviteStr)"
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""
        let filePath = "\(cachePath)/\(cacheKey)"
        
        DispatchQueue.global(qos: .background).async {
            if let data = avatar.pngData() {
                FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil)
            }
        }
    }
}
