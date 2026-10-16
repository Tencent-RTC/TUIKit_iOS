import AtomicXCore
import Combine
import Foundation
import ImSDK_Plus

@MainActor
final class PusherAudienceStore {
    struct User: Equatable, Hashable {
        let userID: String
        let userName: String
        let avatarURL: String
        let level: Int
    }

    enum FollowStatus: Equatable {
        case unknown
        case notFollowing
        case following
    }

    enum Action: Equatable {
        case follow
        case unfollow
        case mute
        case unmute
        case remove
    }

    struct State: Equatable {
        var users: [User] = []
        var count = 0
        var mutedUserIDs: Set<String> = []
        var followStatusByUserID: [String: FollowStatus] = [:]
        var pendingActionByUserID: [String: Action] = [:]

        func followStatus(for userID: String) -> FollowStatus {
            followStatusByUserID[userID] ?? .unknown
        }
    }

    var onStateChanged: ((State) -> Void)? {
        didSet { onStateChanged?(state) }
    }
    var onAudienceEntered: ((AudienceWelcome) -> Void)?
    var onActionCompleted: ((String, Action, Bool) -> Void)?

    private(set) var state = State()

    private let sdkStore: LiveAudienceStore
    private var cancellables = Set<AnyCancellable>()
    private var operationIDs: [String: UUID] = [:]
    private var activationID: UUID?
    private var friendshipListener: PusherAudienceFriendshipListener?

    init(liveID: String) {
        sdkStore = LiveAudienceStore.create(liveID: liveID)
    }

    func activate() {
        guard activationID == nil else { return }
        let activationID = UUID()
        self.activationID = activationID

        sdkStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sdkState in
                guard let self, self.activationID == activationID else { return }
                self.apply(sdkState)
            }
            .store(in: &cancellables)

        sdkStore.liveAudienceEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.activationID == activationID else { return }
                guard case let .onAudienceJoined(audience) = event else { return }
                self.onAudienceEntered?(AudienceWelcome(
                    userID: audience.userID,
                    userName: audience.userName.isEmpty ? audience.userID : audience.userName,
                    level: max(0, audience.level)
                ))
            }
            .store(in: &cancellables)

        let listener = PusherAudienceFriendshipListener(owner: self)
        V2TIMManager.sharedInstance()?.addFriendListener(listener: listener)
        friendshipListener = listener
    }

    func deactivate(resetState: Bool) {
        activationID = nil
        cancellables.removeAll()
        operationIDs.removeAll()
        if let friendshipListener {
            V2TIMManager.sharedInstance()?.removeFriendListener(listener: friendshipListener)
        }
        friendshipListener = nil
        state.pendingActionByUserID.removeAll()
        state.followStatusByUserID.removeAll()
        if resetState {
            state.users.removeAll()
            state.count = 0
            state.mutedUserIDs.removeAll()
        }
        notify()
    }

    func refresh() {
        guard activationID != nil else { return }
        sdkStore.fetchAudienceList(completion: nil)
    }

    func refreshFollowStatus(userID: String) {
        guard activationID != nil, !userID.isEmpty else { return }
        state.followStatusByUserID[userID] = .unknown
        notify()
        checkFollowStatus(userIDs: [userID])
    }

    func toggleFollow(userID: String) {
        guard let imManager = V2TIMManager.sharedInstance() else { return }
        let action: Action
        switch state.followStatus(for: userID) {
        case .following: action = .unfollow
        case .notFollowing: action = .follow
        case .unknown:
            refreshFollowStatus(userID: userID)
            return
        }
        performAction(
            userID: userID,
            action: action,
            operation: { completion in
                if action == .follow {
                    imManager.followUser(
                        userIDList: [userID],
                        succ: { _ in completion(true) },
                        fail: { _, _ in completion(false) }
                    )
                } else {
                    imManager.unfollowUser(
                        userIDList: [userID],
                        succ: { _ in completion(true) },
                        fail: { _, _ in completion(false) }
                    )
                }
            },
            onSuccess: { store in
                store.state.followStatusByUserID[userID] = action == .follow
                    ? .following
                    : .notFollowing
            }
        )
    }

    func toggleMessagePermission(userID: String) {
        let isMuted = state.mutedUserIDs.contains(userID)
        let action: Action = isMuted ? .unmute : .mute
        performAction(
            userID: userID,
            action: action,
            operation: { [sdkStore] completion in
                sdkStore.disableSendMessage(userID: userID, isDisable: !isMuted) { result in
                    if case .success = result { completion(true) } else { completion(false) }
                }
            },
            onSuccess: { $0.refresh() }
        )
    }

    func removeFromRoom(userID: String) {
        performAction(
            userID: userID,
            action: .remove,
            operation: { [sdkStore] completion in
                sdkStore.kickUserOutOfRoom(userID: userID) { result in
                    if case .success = result { completion(true) } else { completion(false) }
                }
            },
            onSuccess: { $0.refresh() }
        )
    }

    fileprivate func handleFollowingListChanged(userIDs: [String]) {
        guard activationID != nil else { return }
        let relevantIDs = userIDs.filter { state.followStatusByUserID[$0] != nil }
        guard !relevantIDs.isEmpty else { return }
        checkFollowStatus(userIDs: relevantIDs)
    }

    private func performAction(
        userID: String,
        action: Action,
        operation: (@escaping (Bool) -> Void) -> Void,
        onSuccess: @escaping (PusherAudienceStore) -> Void
    ) {
        guard let operationID = beginOperation(userID: userID, action: action) else { return }
        let activationID = activationID
        operation { [weak self] succeeded in
            Task { @MainActor in
                guard let self,
                      self.activationID == activationID,
                      self.operationIDs[userID] == operationID else { return }
                if succeeded { onSuccess(self) }
                self.finishOperation(userID: userID, action: action, succeeded: succeeded)
            }
        }
    }

    @discardableResult
    private func beginOperation(userID: String, action: Action) -> UUID? {
        guard activationID != nil,
              !userID.isEmpty,
              operationIDs[userID] == nil else { return nil }
        let operationID = UUID()
        operationIDs[userID] = operationID
        state.pendingActionByUserID[userID] = action
        notify()
        return operationID
    }

    private func finishOperation(userID: String, action: Action, succeeded: Bool) {
        operationIDs[userID] = nil
        state.pendingActionByUserID[userID] = nil
        notify()
        onActionCompleted?(userID, action, succeeded)
    }

    private func checkFollowStatus(userIDs: [String]) {
        guard let activationID, !userIDs.isEmpty else { return }
        guard let imManager = V2TIMManager.sharedInstance() else { return }
        imManager.checkFollowType(
            userIDList: userIDs,
            succ: { [weak self] results in
                Task { @MainActor in
                    guard let self, self.activationID == activationID, let results else { return }
                    for result in results {
                        guard let userID = result.userID, !userID.isEmpty else { continue }
                        self.state.followStatusByUserID[userID] = Self.isFollowing(result.followType)
                            ? .following
                            : .notFollowing
                    }
                    self.notify()
                }
            },
            fail: { _, _ in }
        )
    }

    private func apply(_ sdkState: LiveAudienceState) {
        let users = sdkState.audienceList.compactMap { user -> User? in
            guard !user.userID.isEmpty else { return nil }
            return User(
                userID: user.userID,
                userName: user.userName,
                avatarURL: user.avatarURL,
                level: max(0, user.level)
            )
        }
        let count = Int(min(sdkState.audienceCount, UInt(Int.max)))
        let mutedUserIDs = Set(sdkState.messageBannedUserList.map(\.userID).filter { !$0.isEmpty })
        guard users != state.users || count != state.count || mutedUserIDs != state.mutedUserIDs else {
            return
        }
        state.users = users
        state.count = count
        state.mutedUserIDs = mutedUserIDs
        notify()
    }

    private static func isFollowing(_ followType: V2TIMFollowType) -> Bool {
        followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST
            || followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST
    }

    private func notify() {
        onStateChanged?(state)
    }
}

private final class PusherAudienceFriendshipListener: NSObject, V2TIMFriendshipListener {
    private weak var owner: PusherAudienceStore?

    init(owner: PusherAudienceStore) {
        self.owner = owner
        super.init()
    }

    func onMyFollowingListChanged(userInfoList: [V2TIMUserFullInfo]!, isAdd: Bool) {
        let userIDs = (userInfoList ?? []).compactMap { info -> String? in
            let userID = info.userID ?? ""
            return userID.isEmpty ? nil : userID
        }
        guard !userIDs.isEmpty else { return }
        Task { @MainActor [weak owner] in
            owner?.handleFollowingListChanged(userIDs: userIDs)
        }
    }
}
