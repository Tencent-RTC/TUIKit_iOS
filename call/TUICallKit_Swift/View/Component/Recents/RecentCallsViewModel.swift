//
//  RecentCallsViewModel.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import Foundation
import UIKit
import RTCRoomEngine
import TUICore
import RTCCommon
import Combine
import AtomicXCore

enum RecentCallsType: Int {
    case all
    case missed
}

enum RecentCallsUIStyle: Int {
    case classic
    case minimalist
}

class RecentCallsViewModel: ObservableObject {
    
    @Published var dataSource: [RecentCallsCellViewModel] = []
    var allDataSource: [RecentCallsCellViewModel] = []
    var missedDataSource: [RecentCallsCellViewModel] = []
    
    var recordCallsUIStyle: RecentCallsUIStyle = .minimalist
    var recordCallsType: RecentCallsType = .all
    
    typealias SuccClosureType = @convention(block) (UIViewController) -> Void
    typealias FailClosureType = @convention(block) (Int, String) -> Void
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        subscribeRecentCalls()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func queryRecentCalls() {
        CallStore.shared.queryRecentCalls(cursor: "", count: 100, completion: nil)
    }
    
    private func subscribeRecentCalls() {
        let selector = StatePublisherSelector(keyPath: \CallState.recentCalls)
        CallStore.shared.state.subscribe(selector)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] callInfos in
                guard let self = self else { return }
                var viewModelList: [RecentCallsCellViewModel] = []
                callInfos.forEach { callInfo in
                    let viewModel = RecentCallsCellViewModel(callInfo)
                    viewModelList.append(viewModel)
                }
                self.updateDataSource(viewModelList.reversed())
            }
            .store(in: &cancellables)
        }
    
    func updateDataSource(_ viewModelList: [RecentCallsCellViewModel]) {
        if viewModelList.isEmpty {
            cleanAllSource()
            reloadDataSource()
            return
        }
        cleanAllSource()
        allDataSource = viewModelList
        viewModelList.forEach { viewModel in
            if viewModel.callInfo.result == .missed {
                missedDataSource.append(viewModel)
            }
        }
        reloadDataSource()
    }
    
    func switchRecordCallsType(_ type: RecentCallsType) {
        recordCallsType = type
        reloadDataSource()
    }
    
    func reloadDataSource() {
        switch recordCallsType {
        case .all:
            dataSource = allDataSource
        case .missed:
            dataSource = missedDataSource
        }
    }
    
    func cleanAllSource() {
        dataSource.removeAll()
        allDataSource.removeAll()
        missedDataSource.removeAll()
    }
    
    func cleanSource(viewModel: RecentCallsCellViewModel) {
        allDataSource.removeAll() { $0.callInfo.callId == viewModel.callInfo.callId }
        missedDataSource.removeAll() { $0.callInfo.callId == viewModel.callInfo.callId }
    }
    
    func cleanSource(callId: String) {
        allDataSource.removeAll() { $0.callInfo.callId == callId }
        missedDataSource.removeAll() { $0.callInfo.callId == callId }
    }
    
    func repeatCall(_ indexPath: IndexPath) {
        guard indexPath.row < dataSource.count else { return }
        let callInfo = dataSource[indexPath.row].callInfo
        guard let mediaType = callInfo.mediaType else { return }
        var userIds = callInfo.inviteeIds
        userIds.append(callInfo.inviterId)
        let selfUserId = CallStore.shared.state.value.selfInfo.id
        userIds = userIds.filter { $0 != selfUserId }
        
        if (callInfo.chatGroupId.isEmpty && userIds.count <= 1) {
            repeatSingleCall(callInfo, userIds)
        } else {
            CallStore.shared.calls(participantIds: userIds, callMediaType: mediaType, params: nil, completion: nil)
        }
    }
    
    func repeatSingleCall(_ callInfo: CallInfo, _ otherUserIds: [String]) {
        guard let mediaType = callInfo.mediaType else { return }
        let targetUserId: String
        let selfUserId = CallStore.shared.state.value.selfInfo.id
        
        if callInfo.inviterId != selfUserId {
            targetUserId = callInfo.inviterId
        } else {
            guard let userid = otherUserIds.first else { return }
            targetUserId = userid
        }
        CallStore.shared.calls(participantIds: [targetUserId], callMediaType: mediaType, params: nil, completion: nil)
    }
    
    func deleteAllRecordCalls() {
        var callIdList: [String] = []
        
        if recordCallsType == .all {
            callIdList = getCallIdList(allDataSource)
        } else if recordCallsType == .missed {
            callIdList = getCallIdList(missedDataSource)
        }
        
        CallStore.shared.deleteRecentCalls(callIdList: callIdList) { [weak self] result in
            guard let self = self else { return }
            switch result {
                case .success:
                    callIdList.forEach { self.cleanSource(callId: $0) }
                    self.reloadDataSource()
                case .failure:
                    break
                }
            }
    }
    
    func getCallIdList(_ cellViewModelArray: [RecentCallsCellViewModel]) -> [String] {
        var callIdList: [String] = []
        
        if cellViewModelArray.isEmpty {
            return callIdList
        }
        
        cellViewModelArray.forEach { obj in
            callIdList.append(obj.callInfo.callId)
        }
        
        return callIdList
    }
    
    func deleteRecordCall(_ indexPath: IndexPath) {
        if indexPath.row < 0 || indexPath.row >= dataSource.count {
            return
        }
        let viewModel = dataSource[indexPath.row]
        
        CallStore.shared.deleteRecentCalls(callIdList: [viewModel.callInfo.callId], completion: nil)
    }
    
    func jumpUserInfoController(indexPath: IndexPath, navigationController: UINavigationController) {
        if indexPath.row < 0 || indexPath.row >= dataSource.count {
            return
        }
        let cellViewModel = dataSource[indexPath.row]
        let callInfo = cellViewModel.callInfo
        
        let groupId = callInfo.chatGroupId
        var userId = callInfo.inviterId

        if callInfo.inviterId == CallStore.shared.state.value.selfInfo.id {
            guard let firstUserId = callInfo.inviteeIds.first else { return }
            userId = firstUserId
        }
        
        if !groupId.isEmpty {
            let param: [String: Any] = [TUICore_TUIContactObjectFactory_GetGroupInfoVC_GroupID: groupId]
            if RecentCallsUIStyle.classic == recordCallsUIStyle {
                navigationController.push(TUICore_TUIContactObjectFactory_GetGroupInfoVC_Classic, param: param, forResult: nil)
            } else {
                navigationController.push(TUICore_TUIContactObjectFactory_GetGroupInfoVC_Minimalist, param: param, forResult: nil)
            }
        } else if !userId.isEmpty {
            getUserOrFriendProfileVCWithUserID(userId: userId) { viewController in
                navigationController.pushViewController(viewController, animated: true)
            } fail: { code, desc in
                Toast.showToast("error:\(Int(code)), msg: \(desc)")
            }
        }
    }
    
    func getUserOrFriendProfileVCWithUserID(userId: String, succ: @escaping SuccClosureType, fail: @escaping FailClosureType) {
        let param: NSDictionary = [
            TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_UserIDKey: userId,
            TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_SuccKey: succ,
            TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_FailKey: fail,
        ]
        
        if RecentCallsUIStyle.classic == self.recordCallsUIStyle {
            TUICore.createObject(TUICore_TUIContactObjectFactory,
                                 key: TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod, param: param as? [AnyHashable : Any])
        } else {
            TUICore.createObject(TUICore_TUIContactObjectFactory_Minimalist,
                                 key: TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod, param: param as? [AnyHashable : Any])
        }
    }
}
