//
//  Modules.swift
//  AFNetworking
//
//  Created by aby on 2024/11/18.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon

class AnchorCoHostManager {
    let toastSubject: PassthroughSubject<String, Never>
    
    let observableState: ObservableState<AnchorCoHostState>
    var state: AnchorCoHostState {
        observableState.state
    }
    
    private var listCount = 20
    private typealias Context = AnchorManager.Context
    private weak var context: Context?
    private var cancellableSet: Set<AnyCancellable> = []
    
    private let liveListStore: LiveListStore
    private let liveID: String
    
    init(context: AnchorManager.Context) {
        self.context = context
        self.toastSubject = context.toastSubject
        self.observableState = ObservableState(initialState: AnchorCoHostState())
        self.liveListStore = context.liveListStore
        self.liveID = context.liveID
        
        liveListStore.fetchLiveList(cursor: liveListStore.state.value.liveListCursor, count: listCount, completion: nil)
        
        context.subscribeState(StatePublisherSelector(keyPath: \LiveListState.liveList))
            .removeDuplicates()
            .combineLatest(context.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected)).removeDuplicates(),
                           context.subscribeState(StatePublisherSelector(keyPath: \CoHostState.invitees)).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] liveList, connected, invitees in
                guard let self = self else { return }
                let (connectedUsers, recommendedUsers) = getUserList(liveList: liveList, connected: connected, invitees: invitees)
                observableState.update { state in
                    state.connectedUsers = connectedUsers
                    state.recommendedUsers = recommendedUsers
                }
            }
            .store(in: &cancellableSet)
        
        context.coHostStore.coHostEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onCoHostRequestRejected(invitee: let invitee):
                    toastSubject.send(.requestRejectedText.replacingOccurrences(of: "xxx", with: invitee.displayName))
                case .onCoHostRequestTimeout(inviter: let inviter, invitee: _):
                    if inviter.userID == liveID {
                        toastSubject.send(.requestTimeoutText)
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
    
    func getUserList(liveList: [LiveInfo], connected: [SeatUserInfo], invitees: [SeatUserInfo]) -> (connected: [AnchorCoHostUserInfo], recommended: [AnchorCoHostUserInfo]) {
        let connectedLiveList: [LiveInfo] = liveList.filter { liveInfo in
            let ownerID = liveInfo.liveOwner.userID
            let liveID = liveInfo.liveID
            return connected.contains(where: { $0.liveID == liveID && $0.userID == ownerID })
        }
        
        let recommendedUsers: [AnchorCoHostUserInfo] = liveList.filter { liveInfo in
            let ownerID = liveInfo.liveOwner.userID
            let liveID = liveInfo.liveID
            return !connectedLiveList.contains(where: { $0.liveID == liveID && $0.liveOwner.userID == ownerID })
        }.map {
            let liveInfo = $0
            let connectionStatus: AnchorConnectionStatus
            if invitees.contains(where: { $0.liveID == liveInfo.liveID }) {
                connectionStatus = .inviting
            } else {
                connectionStatus = .none
            }
            return AnchorCoHostUserInfo(liveID: $0.liveID, userInfo: $0.liveOwner, connectionStatus: connectionStatus)
        }
        return (connected: connectedLiveList.map { AnchorCoHostUserInfo(liveID: $0.liveID, userInfo: $0.liveOwner, connectionStatus: .connected) }, recommended: recommendedUsers)
    }
}

// MARK: - Common

extension AnchorCoHostManager {
    func onError(_ error: InternalError) {
        toastSubject.send(error.localizedMessage)
    }
    
    func subscribeCoHostState<Value>(_ selector: StateSelector<AnchorCoHostState, Value>) -> AnyPublisher<Value, Never> {
        return observableState.subscribe(selector)
    }
}

private extension String {
    static let requestRejectedText = internalLocalized("xxx rejected")
    static let requestTimeoutText = internalLocalized("Invitation has timed out")
}
