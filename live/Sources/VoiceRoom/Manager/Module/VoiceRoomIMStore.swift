//
//  VoiceRoomIMStore.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/30.
//

import Foundation
import RTCRoomEngine
import ImSDK_Plus
import RTCCommon
import Combine

struct VoiceRoomIMState {
    var myFollowingUserList: Set<TUIUserInfo> = []
}

class VoiceRoomIMStore: NSObject {
    typealias CompletionClosure = (Result<Void, InternalError>) -> Void
    
    private let imManager = V2TIMManager.sharedInstance()
    
    var state: VoiceRoomIMState {
        observerState.state
    }
    
    private let observerState = ObservableState<VoiceRoomIMState>(initialState: VoiceRoomIMState())

    override init() {
        super.init()
        imManager?.addFriendListener(listener: self)
    }
    
    func subscribeState<Value>(_ selector: StateSelector<VoiceRoomIMState, Value>) -> AnyPublisher<Value, Never> {
        return observerState.subscribe(selector)
    }
    
    func resetState() {
        update { state in
            state.myFollowingUserList = []
        }
    }
    
    func followUser(_ user: TUIUserInfo, completion: CompletionClosure?) {
        LiveKitLog.info("\(#file)", "\(#line)", "followUser[userId:\(user.userId)]")
        guard let imManager = self.imManager else { return }
        imManager.followUser(userIDList: [user.userId]) { [weak self] result in
            guard let self = self else { return }
            updateFollowUserList(user: user, isFollow: true)
            completion?(.success(()))
        } fail: { err, message in
            let error = InternalError(code: Int(err), message: message ?? "")
            completion?(.failure(error))
        }
        
    }
    
    func unfollowUser(_ user: TUIUserInfo, completion: CompletionClosure?) {
        guard let imManager = self.imManager else { return }
        LiveKitLog.info("\(#file)", "\(#line)", "unfollowUser[userId:\(user.userId)]")
        imManager.unfollowUser(userIDList: [user.userId]) { [weak self] result in
            guard let self = self else { return }
            updateFollowUserList(user: user, isFollow: false)
            completion?(.success(()))
        } fail: { err, message in
            let error = InternalError(code: Int(err), message: message ?? "")
            completion?(.failure(error))
        }

    }
    
    func checkFollowType(_ userId: String, completion: CompletionClosure?) {
        guard let imManager = self.imManager else { return }
        LiveKitLog.info("\(#file)", "\(#line)", "checkFollowType[userId:\(userId)]")
        imManager.checkFollowType(userIDList: [userId], succ: { [weak self] result in
            guard let self = self else { return }
            guard let followType = result?.first?.followType else { return }
            let user: TUIUserInfo = TUIUserInfo()
            user.userId = userId
            let isFollow = followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST || followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST
            updateFollowUserList(user: user, isFollow: isFollow)
            completion?(.success(()))
        }, fail: { err, message in
            let error = InternalError(code: Int(err), message: message ?? "")
            completion?(.failure(error))
        })
        
    }
    
    private func updateFollowUserList(user: TUIUserInfo, isFollow: Bool) {
        update { state in
            if isFollow {
                if !state.myFollowingUserList.map({ $0.userId }).contains(user.userId) {
                    state.myFollowingUserList.insert(user)
                }
            } else {
                let followUserList = state.myFollowingUserList.filter({ $0.userId == user.userId })
                followUserList.forEach { user in
                    state.myFollowingUserList.remove(user)
                }
            }
        }
    }
}

extension VoiceRoomIMStore: V2TIMFriendshipListener {
    func onMyFollowingListChanged(userInfoList: [V2TIMUserFullInfo], isAdd: Bool) {
        update { state in
            if isAdd {
                let newUserIds = Set(userInfoList.map { $0.userID })
                state.myFollowingUserList = state.myFollowingUserList.filter { !newUserIds.contains($0.userId) }
                let newFollowingUsers = userInfoList.map { TUIUserInfo(userFullInfo: $0) }
                state.myFollowingUserList.formUnion(newFollowingUsers)
            } else {
                let userIdsToRemove = Set(userInfoList.map { $0.userID })
                state.myFollowingUserList = state.myFollowingUserList.filter { !userIdsToRemove.contains($0.userId) }
            }
        }
    }
}

extension VoiceRoomIMStore {
    typealias stateUpdateClosure = (inout VoiceRoomIMState) -> Void

    func update(closure: stateUpdateClosure) {
        observerState.update(reduce: closure)
    }
}


