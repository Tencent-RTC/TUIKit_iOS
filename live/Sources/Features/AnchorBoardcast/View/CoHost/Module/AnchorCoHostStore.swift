//
//  Modules.swift
//  AFNetworking
//
//  Created by aby on 2024/11/18.
//

import AtomicXCore
import AtomicX
import Combine
import Foundation
import RTCCommon

class AnchorCoHostStore {
    let toastSubject: PassthroughSubject<(String, ToastStyle), Never>

    let observableState: ObservableState<AnchorCoHostState>
    var state: AnchorCoHostState {
        observableState.state
    }
    
    private var listCount = 20
    private typealias Context = AnchorStore.Context
    private weak var context: Context?
    private var cancellableSet: Set<AnyCancellable> = []
    
    private let liveID: String
    
    init(context: AnchorStore.Context) {
        self.context = context
        self.toastSubject = context.toastSubject
        self.observableState = ObservableState(initialState: AnchorCoHostState())
        self.liveID = context.liveID
        
        context.coHostStore.getCoHostCandidates(cursor: "", completion: nil)
        
        context.subscribeState(StatePublisherSelector(keyPath: \CoHostState.candidates))
            .removeDuplicates()
            .combineLatest(context.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected)).removeDuplicates(),
                           context.subscribeState(StatePublisherSelector(keyPath: \CoHostState.invitees)).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] candidates, connected, invitees in
                guard let self = self else { return }
                let (connectedUsers, recommendedUsers) = getUserList(candidates: candidates, connected: connected, invitees: invitees)
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
                        toastSubject.send((.requestRejectedText.replacingOccurrences(of: "xxx", with: invitee.displayName), .info))
                case .onCoHostRequestTimeout(inviter: let inviter, invitee: _):
                    if inviter.userID == LoginStore.shared.state.value.loginUserInfo?.userID {
                        toastSubject.send((.requestTimeoutText, .info))
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
    
    func getUserList(candidates: [SeatUserInfo], connected: [SeatUserInfo], invitees: [SeatUserInfo]) -> (connected: [AnchorCoHostUserInfo], recommended: [AnchorCoHostUserInfo]) {
        let connectedLiveList = candidates.filter { candidates in
            let ownerID = candidates.userID
            let liveID = candidates.liveID
            return connected.contains(where: { $0.liveID == liveID && $0.userID == ownerID })
        }
        
        let recommendedUsers: [AnchorCoHostUserInfo] = candidates.filter { candidate in
            let ownerID = candidate.userID
            let liveID = candidate.liveID
            return !connectedLiveList.contains(where: { $0.liveID == liveID && $0.userID == ownerID })
        }.map {
            let liveInfo = $0
            let connectionStatus: AnchorConnectionStatus
            if invitees.contains(where: { $0.liveID == liveInfo.liveID }) {
                connectionStatus = .inviting
            } else {
                connectionStatus = .none
            }
            return AnchorCoHostUserInfo(userInfo: $0, connectionStatus: connectionStatus)
        }
        return (connected: connectedLiveList.map { AnchorCoHostUserInfo(userInfo: $0, connectionStatus: .connected) }, recommended: recommendedUsers)
    }
}

// MARK: - Common

extension AnchorCoHostStore {
    func onError(_ error: InternalError) {
        toastSubject.send((error.localizedMessage,.error))
    }
    
    func subscribeCoHostState<Value>(_ selector: StateSelector<AnchorCoHostState, Value>) -> AnyPublisher<Value, Never> {
        return observableState.subscribe(selector)
    }
}

private extension String {
    static let requestRejectedText = internalLocalized("common_request_rejected")
    static let requestTimeoutText = internalLocalized("common_connect_invitation_timeout")
}
