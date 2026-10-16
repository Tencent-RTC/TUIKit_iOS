import AtomicXCore
import Combine
import Foundation

@MainActor
protocol PusherCoGuestActionHandling: AnyObject {
    func selectLayout(_ layout: PusherCoGuestStore.Layout)
    func acceptApplication(userID: String)
    func invite(userID: String)
    func cancelInvitation(userID: String)
    func disconnect(userID: String)
    func endAllConnections()
    func markApplicantsSeen()
    func toggleRemoteMicrophone(userID: String)
}

/// Business source of truth for host-side co-guest: subscribes to AtomicXCore
/// `CoGuestState` / `LiveSeatState` and exposes seat layout, applicants,
/// connected guests, invitable candidates and in-flight operation guards.
@MainActor
final class PusherCoGuestStore: PusherCoGuestActionHandling {
    enum Layout: CaseIterable, Equatable {
        case floating
        case grid2
        case fixed
        case grid9

        private var configuration: (titleKey: String, assetName: String, guestCapacity: Int, showsEmptySeats: Bool) {
            switch self {
            case .floating: return ("tuilivekit.pusher.coguest.layout.floating", "livekit_coguest_layout_floating", 6, false)
            case .grid2: return ("tuilivekit.pusher.coguest.layout.grid2", "livekit_coguest_layout_grid2", 8, false)
            case .fixed: return ("tuilivekit.pusher.coguest.layout.fixed", "livekit_coguest_layout_fixed", 6, true)
            case .grid9: return ("tuilivekit.pusher.coguest.layout.grid9", "livekit_coguest_layout_grid9", 8, true)
            }
        }

        var title: String { LiveKitResources.localizedString(configuration.titleKey) }
        var assetName: String { configuration.assetName }
        // Preserve the existing SeatLayoutTemplate IDs when using the new API.
        var layoutTemplate: CoGuestLayoutTemplate {
            switch self {
            case .floating: return CoGuestLayoutTemplate(templateId: 601)
            case .grid2: return CoGuestLayoutTemplate(templateId: 600)
            case .fixed: return CoGuestLayoutTemplate(templateId: 801)
            case .grid9: return CoGuestLayoutTemplate(templateId: 800)
            }
        }
        var guestCapacity: Int { configuration.guestCapacity }
        var showsEmptySeats: Bool { configuration.showsEmptySeats }

    }

    struct User: Equatable, Hashable {
        let userID: String
        let userName: String
        let avatarURL: String
        let microphoneStatus: DeviceStatus
        let allowOpenMicrophone: Bool
        let cameraStatus: DeviceStatus
        let allowOpenCamera: Bool
    }

    struct State: Equatable {
        var layout: Layout = .grid2
        var connected: [User] = []
        var applicants: [User] = []
        var candidates: [User] = []
        var invitees: [User] = []
        var pendingUserIDs: Set<String> = []
        var isUpdatingLayout = false
        var hasUnreadApplicant = false

        var isFull: Bool {
            connected.count >= layout.guestCapacity
        }
    }

    var onStateChanged: ((State) -> Void)? {
        didSet { onStateChanged?(state) }
    }

    private(set) var state = State()
    var onToast: ((String) -> Void)?

    private let liveID: String
    private let sdkStore: CoGuestStore
    private let seatStore: LiveSeatStore
    private var cancellables = Set<AnyCancellable>()
    private var sessionID = UUID()
    private var isActive = false
    private var isConnected = false
    private var layoutOperationID: UUID?
    private var pendingDesiredLayout: Layout? = .grid2
    private var seenApplicantIDs: Set<String> = []
    private var seatUsers: [String: SeatUserInfo] = [:]

    init(
        liveID: String,
        seatStore: LiveSeatStore
    ) {
        self.liveID = liveID
        self.seatStore = seatStore
        sdkStore = CoGuestStore.create(liveID: liveID)
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        pendingDesiredLayout = state.layout
        let sessionID = self.sessionID

        sdkStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sdkState in
                guard let self, self.isActive, self.sessionID == sessionID else { return }
                self.apply(sdkState)
            }
            .store(in: &cancellables)

        seatStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seatState in
                guard let self, self.isActive, self.sessionID == sessionID else { return }
                self.apply(seatState)
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        sessionID = UUID()
        isActive = false
        isConnected = false
        layoutOperationID = nil
        pendingDesiredLayout = nil
        cancellables.removeAll()
        state = State(layout: state.layout)
        seenApplicantIDs.removeAll()
        seatUsers.removeAll()
        notify()
    }

    func markApplicantsSeen() {
        seenApplicantIDs = Set(state.applicants.map(\.userID))
        guard state.hasUnreadApplicant else { return }
        state.hasUnreadApplicant = false
        notify()
    }

    func selectLayout(_ layout: Layout) {
        guard isActive, layout != state.layout, !state.isUpdatingLayout else { return }
        guard state.connected.count <= layout.guestCapacity else {
            onToast?(LiveKitResources.localizedString("tuilivekit.pusher.coguest.error.capacity"))
            return
        }
        let previousLayout = state.layout
        pendingDesiredLayout = layout

        guard isConnected else { return }
        updateLayout(layout, rollbackLayout: previousLayout)
    }

    func didConnect() {
        guard isActive else { return }
        isConnected = true
        synchronizeLayoutIfNeeded()
    }

    func synchronizeLayoutIfNeeded() {
        guard isActive, isConnected,
              !state.isUpdatingLayout,
              let desiredLayout = pendingDesiredLayout else { return }
        updateLayout(desiredLayout, rollbackLayout: state.layout)
    }

    private func updateLayout(_ layout: Layout, rollbackLayout: Layout) {
        let operationID = UUID()
        layoutOperationID = operationID
        state.isUpdatingLayout = true
        notify()

        sdkStore.setLayoutTemplate(template: layout.layoutTemplate) { [weak self] result in
            Task { @MainActor in
                guard let self, self.layoutOperationID == operationID else { return }
                self.layoutOperationID = nil
                self.state.isUpdatingLayout = false
                self.pendingDesiredLayout = nil
                switch result {
                case .success:
                    self.state.layout = layout
                case .failure(let error):
                    self.state.layout = rollbackLayout
                    LiveKitLog.error("[PusherCoGuest] set layout failed template=\(layout.layoutTemplate.templateId) code=\(error.code) message=\(error.message)")
                    self.onToast?(self.layoutErrorMessage(error))
                }
                self.notify()
            }
        }
    }

    private func layoutErrorMessage(_ error: ErrorInfo) -> String {
        let key: String
        switch error.code {
        case -5, 7008, 9506, 100012: // SDK, IM and server-side rate limits.
            key = "tuilivekit.pusher.coguest.error.layout_too_frequent"
        case -2:
            key = "tuilivekit.pusher.coguest.error.layout_unavailable"
        case -3, 6013:
            key = "tuilivekit.pusher.coguest.error.layout_not_ready"
        case -4:
            key = "tuilivekit.pusher.coguest.error.layout_unsupported"
        case -7:
            key = "tuilivekit.pusher.coguest.error.layout_room_unsupported"
        case 6014:
            key = "tuilivekit.pusher.coguest.error.layout_login_required"
        case 9508, 9512, 9523...9525:
            key = "tuilivekit.pusher.coguest.error.layout_network"
        case 9510, 9518...9521:
            key = "tuilivekit.pusher.coguest.error.layout_timeout"
        case 100004:
            key = "tuilivekit.pusher.coguest.error.layout_room_missing"
        case 100006:
            key = "tuilivekit.pusher.coguest.error.layout_permission_denied"
        default:
            // Includes generic failure (-1), invalid response (-6), missing
            // throttle configuration (-8), and unrecognized upstream errors.
            key = "tuilivekit.pusher.coguest.error.layout_failed"
        }
        return LiveKitResources.localizedString(key)
    }

    func acceptApplication(userID: String) {
        guard !state.isFull else {
            showCapacityError()
            return
        }
        perform(userID: userID) { [sdkStore] completion in
            sdkStore.acceptApplication(userID: userID) { result in
                completion(result)
            }
        }
    }

    func invite(userID: String) {
        guard !state.isFull else {
            showCapacityError()
            return
        }
        perform(userID: userID) { [sdkStore] completion in
            sdkStore.inviteToSeat(
                userID: userID,
                seatIndex: -1,
                timeout: 30,
                extraInfo: nil,
                completion: completion
            )
        }
    }

    func cancelInvitation(userID: String) {
        perform(userID: userID) { [sdkStore] completion in
            sdkStore.cancelInvitation(inviteeID: userID, completion: completion)
        }
    }

    func disconnect(userID: String) {
        perform(userID: userID) { [seatStore] completion in
            seatStore.kickUserOutOfSeat(userID: userID, completion: completion)
        }
    }

    func toggleRemoteMicrophone(userID: String) {
        guard isActive, !state.pendingUserIDs.contains(userID),
              let connectedUser = state.connected.first(where: { $0.userID == userID }),
              let user = seatStore.state.value.seatList.first(where: {
                  $0.userInfo.userID == userID
              })?.userInfo else { return }
        if user.allowOpenMicrophone, user.microphoneStatus != .on {
            onToast?(LiveKitResources.localizedString("tuilivekit.pusher.coguest.microphone_manual_open"))
            return
        }
        let toastName = microphoneToastName(for: connectedUser)
        let successMessage = user.allowOpenMicrophone
            ? LiveKitResources.localizedFormat("tuilivekit.pusher.coguest.microphone_closed", toastName)
            : LiveKitResources.localizedFormat("tuilivekit.pusher.coguest.microphone_unlocked", toastName)
        perform(userID: userID, successMessage: successMessage) { [seatStore] callback in
            if !user.allowOpenMicrophone {
                seatStore.openRemoteMicrophone(userID: userID, policy: .unlockOnly, completion: callback)
            } else {
                seatStore.closeRemoteMicrophone(userID: userID, completion: callback)
            }
        }
    }

    private func microphoneToastName(for user: User) -> String {
        let normalizedName = user.userName.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let name = normalizedName.isEmpty ? user.userID : normalizedName
        // Swift Character boundaries preserve emoji and composed characters.
        let prefix = name.prefix(8)
        return prefix.endIndex == name.endIndex ? name : String(prefix) + "…"
    }

    /// Ends every guest connection. Each seat is released individually because
    /// AtomicXCore exposes no bulk kick API; `perform` already de-duplicates
    /// users that are still being processed.
    func endAllConnections() {
        state.connected.forEach { disconnect(userID: $0.userID) }
    }

    private func perform(
        userID: String,
        successMessage: String? = nil,
        action: (@escaping CompletionClosure) -> Void
    ) {
        guard isActive, !userID.isEmpty, !state.pendingUserIDs.contains(userID) else { return }
        state.pendingUserIDs.insert(userID)
        notify()

        let sessionID = self.sessionID
        action { [weak self] result in
            Task { @MainActor in
                guard let self, self.isActive, self.sessionID == sessionID else { return }
                self.state.pendingUserIDs.remove(userID)
                if case .failure(let error) = result {
                    self.onToast?(LiveKitErrorText.message(error))
                }
                self.notify()
                if case .success = result, let successMessage {
                    self.onToast?(successMessage)
                }
            }
        }
    }

    private func apply(_ sdkState: CoGuestState) {
        let loginUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let connected = sdkState.connected.compactMap { user -> User? in
            guard !user.userID.isEmpty,
                  user.userID != loginUserID,
                  user.liveID.isEmpty || user.liveID == liveID else { return nil }
            if case .owner = user.role { return nil }
            return User(user, seatUser: seatUsers[user.userID])
        }
        let connectedIDs = Set(connected.map(\.userID))
        let applicants = unique(sdkState.applicants.map(User.init))
            .filter { !connectedIDs.contains($0.userID) && $0.userID != loginUserID }
        let applicantIDs = Set(applicants.map(\.userID))
        let invitees = unique(sdkState.invitees.map(User.init))
            .filter { !connectedIDs.contains($0.userID) && $0.userID != loginUserID }
        let inviteeIDs = Set(invitees.map(\.userID))
        let candidates = unique(sdkState.candidates.map(User.init))
            .filter {
                !connectedIDs.contains($0.userID) &&
                    !applicantIDs.contains($0.userID) &&
                    !inviteeIDs.contains($0.userID) &&
                    $0.userID != loginUserID
            }

        state.connected = unique(connected)
        state.applicants = applicants
        state.invitees = invitees
        state.candidates = candidates
        // Drop stale entries so that a user who cancels and applies again is
        // treated as a fresh, unread request.
        seenApplicantIDs.formIntersection(applicantIDs)
        state.hasUnreadApplicant = applicants.contains { !seenApplicantIDs.contains($0.userID) }
        notify()
    }

    private func apply(_ seatState: LiveSeatState) {
        var users: [String: SeatUserInfo] = [:]
        seatState.seatList.forEach { seat in
            guard !seat.userInfo.userID.isEmpty else { return }
            users[seat.userInfo.userID] = seat.userInfo
        }
        seatUsers = users
        let connected = state.connected.map { user in
            guard let seatUser = seatUsers[user.userID] else { return user }
            return user.merging(seatUser)
        }
        guard connected != state.connected else { return }
        state.connected = connected
        notify()
    }

    private func unique(_ users: [User]) -> [User] {
        var seen = Set<String>()
        return users.filter { !$0.userID.isEmpty && seen.insert($0.userID).inserted }
    }

    private func showCapacityError() {
        onToast?(LiveKitResources.localizedFormat(
            "tuilivekit.pusher.coguest.error.max_capacity",
            state.layout.guestCapacity
        ))
    }

    private func notify() {
        onStateChanged?(state)
    }
}

private extension PusherCoGuestStore.User {
    init(_ user: LiveUserInfo) {
        userID = user.userID
        userName = user.userName.isEmpty ? user.userID : user.userName
        avatarURL = user.avatarURL
        microphoneStatus = .off
        allowOpenMicrophone = true
        cameraStatus = .off
        allowOpenCamera = true
    }

    init(_ user: SeatUserInfo, seatUser: SeatUserInfo? = nil) {
        let deviceUser = seatUser ?? user
        userID = user.userID
        userName = user.userName.isEmpty ? user.userID : user.userName
        avatarURL = user.avatarURL
        microphoneStatus = deviceUser.microphoneStatus
        allowOpenMicrophone = deviceUser.allowOpenMicrophone
        cameraStatus = deviceUser.cameraStatus
        allowOpenCamera = deviceUser.allowOpenCamera
    }

    func merging(_ seatUser: SeatUserInfo) -> Self {
        Self(
            userID: userID,
            userName: userName,
            avatarURL: avatarURL,
            microphoneStatus: seatUser.microphoneStatus,
            allowOpenMicrophone: seatUser.allowOpenMicrophone,
            cameraStatus: seatUser.cameraStatus,
            allowOpenCamera: seatUser.allowOpenCamera
        )
    }
}
