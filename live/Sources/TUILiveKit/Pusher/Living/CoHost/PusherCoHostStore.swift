import AtomicXCore
import Combine
import Foundation
import ImSDK_Plus

@MainActor final class PusherCoHostStore {
    enum FollowStatus: Equatable, Hashable { case unknown, notFollowing, following, mutual }

    struct User: Equatable, Hashable {
        let liveID: String
        let userID: String
        let userName: String
        let avatarURL: String
        var followStatus: FollowStatus = .unknown

        var isFollowing: Bool { followStatus == .following || followStatus == .mutual }
        var isMutual: Bool { followStatus == .mutual }
    }

    struct State: Equatable {
        var candidates: [User] = []
        var connected: [User] = []
        var invitees: [User] = []
        var applicant: User?
        var applicantDeadline: Date?
        var pendingLiveIDs: Set<String> = []
        var isLoading = false
        var hasMore = true
        var loadError: String?
        var isConnected = false
        var isExiting = false
        var connectionStartedAt: Date?

        func isInvited(liveID: String) -> Bool { invitees.contains { $0.liveID == liveID } }
        func isBusy(liveID: String) -> Bool { isExiting || pendingLiveIDs.contains(liveID) }
    }

    var onStateChanged: ((State) -> Void)? { didSet { onStateChanged?(state) } }
    var onToast: ((String) -> Void)?
    private(set) var state = State()

    private let liveID: String
    private var sdkStore: CoHostStore?
    private var activationID: UUID?
    private var cancellables = Set<AnyCancellable>()
    private var operations: [String: UUID] = [:]
    // Keep cancellation attempts until the service confirms them. The SDK removes invites optimistically.
    private var unconfirmedCancellations: [String: User] = [:]
    private var candidateRequestID: UUID?
    private var nextCursor = ""
    private var applicantID: UUID?
    private var respondingApplicantID: UUID?
    private var applicantTimeout: DispatchWorkItem?
    private var expiredApplicantLiveID: String?
    private var followStatus: [String: FollowStatus] = [:]
    private var followRequests: [String: UUID] = [:]
    private var friendshipListener: PusherCoHostFriendshipListener?

    init(liveID: String) { self.liveID = liveID }

    deinit { applicantTimeout?.cancel() }

    func activate() {
        guard activationID == nil else { return }
        let activationID = UUID()
        self.activationID = activationID
        let sdkStore = CoHostStore.create(liveID: liveID)
        self.sdkStore = sdkStore
        sdkStore.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self, self.activationID == activationID, let sdkStore = self.sdkStore else { return }
            self.apply(sdkStore.state.value)
        }.store(in: &cancellables)
        sdkStore.coHostEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard let self, self.activationID == activationID else { return }
            self.handle(event)
        }.store(in: &cancellables)
        let listener = PusherCoHostFriendshipListener(owner: self)
        friendshipListener = listener
        V2TIMManager.sharedInstance()?.addFriendListener(listener: listener)
    }

    func deactivate() {
        activationID = nil
        applicantTimeout?.cancel()
        applicantTimeout = nil
        cancellables.removeAll()
        if let friendshipListener { V2TIMManager.sharedInstance()?.removeFriendListener(listener: friendshipListener) }
        friendshipListener = nil
        sdkStore = nil
        operations.removeAll()
        unconfirmedCancellations.removeAll()
        candidateRequestID = nil
        nextCursor = ""
        applicantID = nil
        respondingApplicantID = nil
        expiredApplicantLiveID = nil
        followStatus.removeAll()
        followRequests.removeAll()
        state = State()
        notify()
    }

    func refresh() {
        guard !state.isLoading else { return }
        followStatus.removeAll()
        followRequests.removeAll()
        fetchCandidates(cursor: "")
    }

    func loadMore() {
        guard state.hasMore, !state.isLoading else { return }
        fetchCandidates(cursor: nextCursor)
    }

    func invite(liveID: String) {
        guard let sdkStore, liveID != self.liveID, !state.isInvited(liveID: liveID),
            !state.connected.contains(where: { $0.liveID == liveID })
        else { return }
        perform(liveID: liveID) { completion in
            sdkStore.requestHostConnection(
                targetHost: liveID, layoutTemplate: .hostDynamicGrid, timeout: 10, completion: completion)
        }
    }

    func cancelInvitation(liveID: String) {
        guard let sdkStore, !state.isBusy(liveID: liveID),
            let user = state.invitees.first(where: { $0.liveID == liveID })
        else { return }
        unconfirmedCancellations[liveID] = user
        perform(
            liveID: liveID,
            completion: { [weak self] succeeded in
                guard let self else { return }
                if succeeded { self.unconfirmedCancellations[liveID] = nil }
                self.apply(sdkStore.state.value)
            }
        ) { completion in sdkStore.cancelHostConnection(toHostLiveID: liveID, completion: completion) }
    }

    func acceptInvitation() { respondToInvitation(accept: true) }
    func rejectInvitation() { respondToInvitation(accept: false) }

    func exitConnection() {
        guard let sdkStore, let activationID, state.isConnected, !state.isExiting, state.pendingLiveIDs.isEmpty else {
            return
        }
        state.isExiting = true
        notify()
        cancelInvitationsAndExit(state.invitees, sdkStore: sdkStore, activationID: activationID)
    }

    private func cancelInvitationsAndExit(_ invitees: [User], sdkStore: CoHostStore, activationID: UUID) {
        guard let invitee = invitees.first else {
            finishExit(sdkStore: sdkStore, activationID: activationID)
            return
        }
        unconfirmedCancellations[invitee.liveID] = invitee
        sdkStore.cancelHostConnection(toHostLiveID: invitee.liveID) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activationID == activationID else { return }
                switch result {
                case .success:
                    self.unconfirmedCancellations[invitee.liveID] = nil
                    self.apply(sdkStore.state.value)
                    self.cancelInvitationsAndExit(
                        Array(invitees.dropFirst()), sdkStore: sdkStore, activationID: activationID)
                case .failure(let error):
                    self.state.isExiting = false
                    self.apply(sdkStore.state.value)
                    self.onToast?(LiveKitErrorText.message(error))
                }
            }
        }
    }

    private func finishExit(sdkStore: CoHostStore, activationID: UUID) {
        sdkStore.exitHostConnection { [weak self] result in
            Task { @MainActor in
                guard let self, self.activationID == activationID else { return }
                self.state.isExiting = false
                if case .failure(let error) = result { self.onToast?(LiveKitErrorText.message(error)) }
                self.notify()
            }
        }
    }

    private func respondToInvitation(accept: Bool) {
        guard let sdkStore, let applicant = state.applicant, let applicantID, !state.isBusy(liveID: applicant.liveID)
        else { return }
        if let deadline = state.applicantDeadline, deadline <= Date() {
            expireApplicant(requestID: applicantID)
            return
        }
        guard sdkStore.state.value.applicant?.liveID == applicant.liveID else {
            apply(sdkStore.state.value)
            return
        }
        applicantTimeout?.cancel()
        applicantTimeout = nil
        respondingApplicantID = applicantID
        perform(
            liveID: applicant.liveID,
            completion: { [weak self] _ in
                guard let self, self.applicantID == applicantID else { return }
                self.respondingApplicantID = nil
                self.apply(sdkStore.state.value)
                if self.applicantID == applicantID { self.scheduleApplicantTimeout(requestID: applicantID) }
            }
        ) { completion in
            if accept {
                sdkStore.acceptHostConnection(fromHostLiveID: applicant.liveID, completion: completion)
            } else {
                sdkStore.rejectHostConnection(fromHostLiveID: applicant.liveID, completion: completion)
            }
        }
    }

    private func perform(
        liveID: String, completion: ((Bool) -> Void)? = nil, operation: (@escaping CompletionClosure) -> Void
    ) {
        guard let activationID, !liveID.isEmpty, !state.isBusy(liveID: liveID) else { return }
        let operationID = UUID()
        operations[liveID] = operationID
        state.pendingLiveIDs.insert(liveID)
        notify()
        operation { [weak self] result in
            Task { @MainActor in
                guard let self, self.activationID == activationID, self.operations[liveID] == operationID else {
                    return
                }
                self.operations[liveID] = nil
                self.state.pendingLiveIDs.remove(liveID)
                switch result {
                case .success: completion?(true)
                case .failure(let error):
                    completion?(false)
                    self.onToast?(LiveKitErrorText.message(error))
                }
                self.notify()
            }
        }
    }

    private func fetchCandidates(cursor: String) {
        guard let sdkStore, let activationID else { return }
        let requestID = UUID()
        candidateRequestID = requestID
        state.isLoading = true
        state.loadError = nil
        notify()
        sdkStore.getCoHostCandidates(cursor: cursor) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activationID == activationID, self.candidateRequestID == requestID else { return }
                self.candidateRequestID = nil
                self.state.isLoading = false
                switch result {
                case .success:
                    self.nextCursor = sdkStore.state.value.candidatesCursor
                    self.state.hasMore = !self.nextCursor.isEmpty && self.nextCursor != cursor
                    self.apply(sdkStore.state.value)
                    self.checkFollowStatus(userIDs: self.state.candidates.map(\.userID))
                case .failure(let error): self.state.loadError = LiveKitErrorText.message(error)
                }
                self.notify()
            }
        }
    }

    private func apply(_ sdkState: CoHostState) {
        let existing = Dictionary(state.candidates.map { ($0.liveID, $0) }, uniquingKeysWith: { first, _ in first })
        func users(_ values: [SeatUserInfo]) -> [User] {
            var seen = Set<String>()
            return values.compactMap { value in
                guard !value.liveID.isEmpty, value.liveID != liveID, seen.insert(value.liveID).inserted else {
                    return nil
                }
                let previous = existing[value.liveID]
                let userID = value.userID.isEmpty ? previous?.userID ?? "" : value.userID
                let name = value.userName.isEmpty ? previous?.userName ?? userID : value.userName
                return User(
                    liveID: value.liveID, userID: userID, userName: name,
                    avatarURL: value.avatarURL.isEmpty ? previous?.avatarURL ?? "" : value.avatarURL,
                    followStatus: followStatus[userID] ?? .unknown)
            }
        }
        state.connected = users(sdkState.connected)
        let connectedIDs = Set(state.connected.map(\.liveID))
        connectedIDs.forEach { unconfirmedCancellations[$0] = nil }
        state.invitees = users(sdkState.invitees)
        let invitedIDs = Set(state.invitees.map(\.liveID))
        state.invitees += unconfirmedCancellations.values.filter { !invitedIDs.contains($0.liveID) }.sorted {
            $0.liveID < $1.liveID
        }
        state.candidates = users(sdkState.connected + sdkState.candidates + sdkState.invitees)
        let candidateIDs = Set(state.candidates.map(\.liveID))
        state.candidates += state.invitees.filter { !candidateIDs.contains($0.liveID) }
        let isConnected = sdkState.coHostStatus == .connected
        if isConnected != state.isConnected {
            state.connectionStartedAt = isConnected ? Date() : nil
            state.isConnected = isConnected
        }
        if let applicant = sdkState.applicant, let user = users([applicant]).first {
            if expiredApplicantLiveID != user.liveID { updateApplicant(user) }
        } else if respondingApplicantID == nil {
            resetApplicant()
            expiredApplicantLiveID = nil
        }
        notify()
    }

    private func handle(_ event: CoHostEvent) {
        switch event {
        case .onCoHostRequestReceived(let inviter, _):
            expiredApplicantLiveID = nil
            updateApplicant(
                User(
                    liveID: inviter.liveID, userID: inviter.userID,
                    userName: inviter.userName.isEmpty ? inviter.userID : inviter.userName,
                    avatarURL: inviter.avatarURL, followStatus: followStatus[inviter.userID] ?? .unknown))
        case .onCoHostRequestCancelled(let inviter, _): clearApplicant(liveID: inviter.liveID)
        case .onCoHostRequestTimeout(let inviter, let invitee):
            clearApplicant(liveID: inviter.liveID)
            let targetID = inviter.liveID == liveID ? invitee.liveID : inviter.liveID
            unconfirmedCancellations[targetID] = nil
            operations[targetID] = nil
            state.pendingLiveIDs.remove(targetID)
            onToast?(LiveKitResources.localizedString("tuilivekit.pusher.cohost.request_timeout"))
        case .onCoHostRequestRejected(let invitee):
            unconfirmedCancellations[invitee.liveID] = nil
            onToast?(LiveKitResources.localizedString("tuilivekit.pusher.cohost.request_rejected"))
        case .onCoHostRequestAccepted(let invitee): unconfirmedCancellations[invitee.liveID] = nil
        case .onCoHostUserJoined, .onCoHostUserLeft: break
        }
        if let sdkStore { apply(sdkStore.state.value) }
        notify()
    }

    private func clearApplicant(liveID: String) {
        guard state.applicant?.liveID == liveID else { return }
        operations[liveID] = nil
        state.pendingLiveIDs.remove(liveID)
        resetApplicant()
    }

    private func resetApplicant() {
        applicantTimeout?.cancel()
        applicantTimeout = nil
        state.applicant = nil
        state.applicantDeadline = nil
        applicantID = nil
        respondingApplicantID = nil
    }

    private func updateApplicant(_ user: User) {
        let isNew = state.applicant?.liveID != user.liveID || state.applicant?.userID != user.userID
        state.applicant = user
        guard isNew, activationID != nil else { return }
        applicantTimeout?.cancel()
        let requestID = UUID()
        applicantID = requestID
        respondingApplicantID = nil
        state.applicantDeadline = Date().addingTimeInterval(10)
        scheduleApplicantTimeout(requestID: requestID)
        checkFollowStatus(userIDs: [user.userID])
    }

    private func scheduleApplicantTimeout(requestID: UUID) {
        guard let activationID, let deadline = state.applicantDeadline else { return }
        applicantTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.activationID == activationID else { return }
                self.expireApplicant(requestID: requestID)
            }
        }
        applicantTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSinceNow), execute: timeout)
    }

    private func expireApplicant(requestID: UUID) {
        guard applicantID == requestID, respondingApplicantID == nil, let applicant = state.applicant, let sdkStore
        else { return }
        // Re-read the SDK before rejecting so a delayed timer cannot reject a later caller.
        let currentApplicant = sdkStore.state.value.applicant
        let stillPending = currentApplicant?.liveID == applicant.liveID && currentApplicant?.userID == applicant.userID
        expiredApplicantLiveID = applicant.liveID
        clearApplicant(liveID: applicant.liveID)
        notify()
        guard stillPending else {
            apply(sdkStore.state.value)
            return
        }
        sdkStore.rejectHostConnection(fromHostLiveID: applicant.liveID) { result in
            if case .failure(let error) = result {
                LiveKitLog.error("[PusherCoHost] expired invitation rejection failed code=\(error.code)")
            }
        }
    }

    fileprivate func refreshFollowStatus(userIDs: [String]) {
        var visibleIDs = Set(state.candidates.map(\.userID))
        if let applicant = state.applicant { visibleIDs.insert(applicant.userID) }
        let relevant = userIDs.filter { visibleIDs.contains($0) }
        relevant.forEach {
            followStatus[$0] = nil
            followRequests[$0] = nil
        }
        checkFollowStatus(userIDs: relevant)
    }

    private func checkFollowStatus(userIDs: [String]) {
        guard let activationID, let manager = V2TIMManager.sharedInstance() else { return }
        let ids = Set(userIDs).filter { !$0.isEmpty && followStatus[$0] == nil && followRequests[$0] == nil }
        guard !ids.isEmpty else { return }
        let batch = Array(ids.prefix(100))
        let remaining = Array(ids.dropFirst(100))
        let requestID = UUID()
        batch.forEach { followRequests[$0] = requestID }
        manager.checkFollowType(
            userIDList: batch,
            succ: { [weak self] results in
                Task { @MainActor in
                    guard let self, self.activationID == activationID else { return }
                    for result in results ?? [] {
                        guard let userID = result.userID, self.followRequests[userID] == requestID,
                            result.resultCode == 0
                        else { continue }
                        switch result.followType {
                        case .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST: self.followStatus[userID] = .mutual
                        case .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST: self.followStatus[userID] = .following
                        default: self.followStatus[userID] = .notFollowing
                        }
                    }
                    batch.filter { self.followRequests[$0] == requestID }.forEach { self.followRequests[$0] = nil }
                    if let sdkStore = self.sdkStore { self.apply(sdkStore.state.value) }
                    self.checkFollowStatus(userIDs: remaining)
                }
            },
            fail: { [weak self] _, _ in
                Task { @MainActor in
                    guard let self, self.activationID == activationID else { return }
                    batch.filter { self.followRequests[$0] == requestID }.forEach { self.followRequests[$0] = nil }
                    self.onToast?(LiveKitResources.localizedString("tuilivekit.pusher.cohost.follow_query_failed"))
                }
            })
    }

    private func notify() { onStateChanged?(state) }
}

private final class PusherCoHostFriendshipListener: NSObject, V2TIMFriendshipListener {
    private weak var owner: PusherCoHostStore?

    init(owner: PusherCoHostStore) {
        self.owner = owner
        super.init()
    }

    func onMyFollowingListChanged(userInfoList: [V2TIMUserFullInfo]!, isAdd: Bool) { refresh(userInfoList) }

    func onMyFollowersListChanged(userInfoList: [V2TIMUserFullInfo]!, isAdd: Bool) { refresh(userInfoList) }

    private func refresh(_ users: [V2TIMUserFullInfo]?) {
        let ids = (users ?? []).compactMap(\.userID)
        Task { @MainActor [weak owner] in owner?.refreshFollowStatus(userIDs: ids) }
    }
}
