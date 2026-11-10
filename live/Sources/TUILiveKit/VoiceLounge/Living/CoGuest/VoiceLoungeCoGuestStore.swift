import AVFoundation
import AtomicXCore
import Combine
import Foundation

@MainActor final class VoiceLoungeCoGuestStore {
    enum GuestStatus: Equatable {
        case idle
        case applying
        case onSeat
    }

    enum InvitationEvent {
        case received(LiveUserInfo)
        case cancelled
    }

    var onToast: ((String) -> Void)?

    var invitationEvents: AnyPublisher<InvitationEvent, Never> { invitationSubject.eraseToAnyPublisher() }
    private let invitationSubject = PassthroughSubject<InvitationEvent, Never>()

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }
    private let changeSubject = PassthroughSubject<Void, Never>()

    private(set) var guestStatus: GuestStatus = .idle {
        didSet {
            guard guestStatus != oldValue else { return }
            changeSubject.send()
        }
    }
    private(set) var applicants: [LiveUserInfo] = []
    private(set) var pendingUserIDs: Set<String> = []
    private(set) var inviteeIDs: Set<String> = []
    private(set) var applicantSeatIndex: [String: Int] = [:]
    private(set) var connectedUsers: [SeatUserInfo] = []
    private var recentlyCancelled: [String: TimeInterval] = [:]
    private var seatingHoldUntil: [String: TimeInterval] = [:]

    var seatingHoldUserIDs: Set<String> {
        let now = ProcessInfo.processInfo.systemUptime
        return Set(seatingHoldUntil.filter { $0.value > now }.keys)
    }

    private var store: CoGuestStore?
    private var barrageStore: BarrageStore?
    static let seatIntentBusinessID = "vl_seat_apply"
    static let micOpenBusinessID = "vl_mic_open"
    static let pauseBusinessID = "vl_pause"

    var onMicOpenRequested: (() -> Void)?
    var onHostPauseChanged: ((Bool) -> Void)?
    private var liveID = ""
    private var role: VoiceLoungeRole = .audience
    private var cancellables = Set<AnyCancellable>()
    private let applyTimeout: TimeInterval = 60
    private let inviteTimeout: TimeInterval = 30
    private var pendingInviterID: String?

    private var selfUserID: String { LoginStore.shared.state.value.loginUserInfo?.userID ?? "" }

    // MARK: - Lifecycle
    func activate(liveID: String, role: VoiceLoungeRole) {
        guard !liveID.isEmpty else { return }
        if self.liveID == liveID, store != nil { return }
        deactivate()
        self.liveID = liveID
        self.role = role
        let store = CoGuestStore.create(liveID: liveID)
        self.store = store
        let barrageStore = BarrageStore.create(liveID: liveID)
        self.barrageStore = barrageStore

        store.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in self?.apply(state) }.store(
            in: &cancellables)

        switch role {
        case .audience:
            store.guestEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
                self?.handleGuestEvent(event)
            }.store(in: &cancellables)
        case .host:
            store.hostEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
                self?.handleHostEvent(event)
            }.store(in: &cancellables)
        }
        barrageStore.CustomMessageEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            self?.handleCustomMessage(event)
        }.store(in: &cancellables)
    }

    func deactivate() {
        if role == .audience, let store {
            switch guestStatus {
            case .applying: store.cancelApplication(completion: nil)
            case .onSeat: store.disConnect(completion: nil)
            case .idle: break
            }
            if let inviterID = pendingInviterID { store.rejectInvitation(inviterID: inviterID, completion: nil) }
        }
        if role == .audience, guestStatus == .onSeat { DeviceStore.shared.closeLocalMicrophone() }
        cancellables.removeAll()
        store = nil
        barrageStore = nil
        liveID = ""
        applicants = []
        pendingUserIDs = []
        inviteeIDs = []
        applicantSeatIndex = [:]
        connectedUsers = []
        recentlyCancelled = [:]
        seatingHoldUntil = [:]
        pendingInviterID = nil
        guestStatus = .idle
        changeSubject.send()
    }

    // MARK: - Audience
    func apply(seatIndex: Int, quiet: Bool = false) {
        guard role == .audience, guestStatus == .idle, let store else { return }
        guestStatus = .applying
        store.applyForSeat(seatIndex: seatIndex, timeout: applyTimeout, extraInfo: "{\"mediaType\":\"audio\"}") {
            [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    if !quiet { self.onToast?(.applied) }
                    self.announceSeatIntent(seatIndex)
                case .failure(let error):
                    LiveKitLog.error(
                        "[VoiceLoungeCoGuest] applyForSeat failed: code=\(error.code), message=\(error.message)")
                    self.onToast?(VoiceLoungeErrorText.coGuestApply(error))
                    if self.guestStatus == .applying { self.guestStatus = .idle }
                }
            }
        }
    }

    func switchApplication(to seatIndex: Int) {
        guard role == .audience, guestStatus == .applying, let store else { return }
        store.cancelApplication { [weak self] _ in
            Task { @MainActor in
                guard let self, self.guestStatus == .applying else { return }
                self.guestStatus = .idle
                self.apply(seatIndex: seatIndex, quiet: true)
            }
        }
    }

    private func announceSeatIntent(_ seatIndex: Int) {
        barrageStore?.sendCustomMessage(
            businessID: Self.seatIntentBusinessID, data: "{\"seat\":\(max(-1, seatIndex))}", completion: nil)
    }

    func cancelApplication() {
        guard role == .audience, guestStatus == .applying, let store else { return }
        store.cancelApplication(completion: nil)
        guestStatus = .idle
        onToast?(.retracted)
    }

    func leaveSeat() {
        guard role == .audience, guestStatus == .onSeat, let store else { return }
        store.disConnect { [weak self] result in
            Task { @MainActor in
                if case .failure(let error) = result { self?.onToast?(VoiceLoungeErrorText.coGuest(error)) }
            }
        }
        DeviceStore.shared.closeLocalMicrophone()
        guestStatus = .idle
        onToast?(.left)
    }

    func acceptInvitation() {
        guard role == .audience, let store, let inviterID = pendingInviterID else { return }
        pendingInviterID = nil
        if guestStatus == .applying {
            store.cancelApplication(completion: nil)
            guestStatus = .idle
        }
        store.acceptInvitation(inviterID: inviterID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.guestStatus = .onSeat
                    self.onToast?(.joinedByInvite)
                    Self.openMicrophone()
                case .failure(let error): self.onToast?(VoiceLoungeErrorText.coGuest(error))
                }
            }
        }
    }

    func rejectInvitation() {
        guard role == .audience, let store, let inviterID = pendingInviterID else { return }
        pendingInviterID = nil
        store.rejectInvitation(inviterID: inviterID, completion: nil)
    }

    // MARK: - Host

    func invite(userID: String, seatIndex: Int) {
        perform(userID: userID, successMessage: .invited) { [inviteTimeout] store, completion in
            store.inviteToSeat(
                userID: userID, seatIndex: seatIndex, timeout: inviteTimeout, extraInfo: nil, completion: completion)
        }
    }

    func cancelInvitation(userID: String) {
        perform(userID: userID) { store, completion in store.cancelInvitation(inviteeID: userID, completion: completion)
        }
    }

    func accept(userID: String) {
        holdSeating(for: userID)
        perform(userID: userID) { store, completion in store.acceptApplication(userID: userID, completion: completion) }
    }

    private static let seatingHoldDuration: TimeInterval = 10

    private func holdSeating(for userID: String) {
        seatingHoldUntil[userID] = ProcessInfo.processInfo.systemUptime + Self.seatingHoldDuration
    }

    private func perform(
        userID: String, successMessage: String? = nil, action: (CoGuestStore, @escaping CompletionClosure) -> Void
    ) {
        guard role == .host, let store, !userID.isEmpty, !pendingUserIDs.contains(userID) else { return }
        pendingUserIDs.insert(userID)
        notifyApplicants()
        let liveID = self.liveID
        action(store) { [weak self] result in
            Task { @MainActor in
                guard let self, self.liveID == liveID else { return }
                self.pendingUserIDs.remove(userID)
                switch result {
                case .success: if let successMessage { self.onToast?(successMessage) }
                case .failure(let error): self.onToast?(VoiceLoungeErrorText.coGuest(error))
                }
                self.notifyApplicants()
            }
        }
    }

    // MARK: - State / Events

    private func apply(_ state: CoGuestState) {
        let selfID = selfUserID
        switch role {
        case .host:
            var seen = Set<String>()
            applicants = state.applicants.filter {
                !$0.userID.isEmpty && $0.userID != selfID && seen.insert($0.userID).inserted
            }
            inviteeIDs = Set(state.invitees.map(\.userID).filter { !$0.isEmpty })
            pendingUserIDs.formIntersection(Set(applicants.map(\.userID)).union(inviteeIDs))
            connectedUsers = state.connected.filter { !$0.userID.isEmpty && $0.userID != selfID }
            let connectedIDs = Set(connectedUsers.map(\.userID))
            seatingHoldUntil = seatingHoldUntil.filter { !connectedIDs.contains($0.key) }
            notifyApplicants()
        case .audience:
            guard !selfID.isEmpty else { return }
            let onSeat = state.connected.contains { $0.userID == selfID }
            if onSeat { guestStatus = .onSeat } else if guestStatus == .onSeat { guestStatus = .idle }
        }
    }

    private func notifyApplicants() { changeSubject.send() }

    private func handleGuestEvent(_ event: GuestEvent) {
        switch event {
        case .onGuestApplicationResponded(let isAccept, _):
            if isAccept {
                guestStatus = .onSeat
                onToast?(.accepted)
                Self.openMicrophone()
            } else {
                guestStatus = .idle
                onToast?(.rejected)
            }
        case .onGuestApplicationNoResponse(let reason):
            onToast?(reason == .alreadySeated ? .alreadySeated : .applyTimeout)
            if guestStatus == .applying { guestStatus = .idle }
        case .onKickedOffSeat:
            DeviceStore.shared.closeLocalMicrophone()
            guestStatus = .idle
            onToast?(.kickedOff)
        case .onHostInvitationReceived(let hostUser):
            guard guestStatus != .onSeat else { return }
            pendingInviterID = hostUser.userID
            invitationSubject.send(.received(hostUser))
        case .onHostInvitationCancelled:
            pendingInviterID = nil
            invitationSubject.send(.cancelled)
        @unknown default: break
        }
    }

    private func handleHostEvent(_ event: HostEvent) {
        switch event {
        case .onGuestApplicationReceived(let user):
            if let cancelledAt = recentlyCancelled[user.userID], ProcessInfo.processInfo.systemUptime - cancelledAt < 5
            {
                recentlyCancelled[user.userID] = nil
                return
            }
            onToast?(.newApplicant(Self.displayName(user)))
        case .onGuestApplicationCancelled(let user):
            recentlyCancelled[user.userID] = ProcessInfo.processInfo.systemUptime
        case .onHostInvitationResponded(let isAccept, let user):
            if isAccept { holdSeating(for: user.userID) }
            let name = Self.displayName(user)
            onToast?(isAccept ? .inviteAccepted(name) : .inviteRejected(name))
        case .onHostInvitationNoResponse(let user, _): onToast?(.inviteTimeout(Self.displayName(user)))
        default: break
        }
    }

    func requestOpenMicrophone(userID: String) {
        guard role == .host, !userID.isEmpty else { return }
        barrageStore?.sendCustomMessage(
            businessID: Self.micOpenBusinessID, data: "{\"user\":\"\(userID)\"}", completion: nil)
    }

    func broadcastPause(_ paused: Bool) {
        guard role == .host else { return }
        barrageStore?.sendCustomMessage(
            businessID: Self.pauseBusinessID, data: "{\"paused\":\(paused)}", completion: nil)
    }

    private func handleCustomMessage(_ event: CustomMessageEvent) {
        guard case .customMessageReceived(let barrage) = event else { return }
        switch (role, barrage.businessID) {
        case (.host, Self.seatIntentBusinessID): handleSeatIntent(barrage)
        case (.audience, Self.micOpenBusinessID): handleMicOpenRequest(barrage)
        case (.audience, Self.pauseBusinessID): handlePauseSignal(barrage)
        default: break
        }
    }

    private func handlePauseSignal(_ barrage: Barrage) {
        guard let data = barrage.data.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let paused = json["paused"] as? Bool
        else { return }
        onHostPauseChanged?(paused)
    }

    private func handleMicOpenRequest(_ barrage: Barrage) {
        guard guestStatus == .onSeat, let data = barrage.data.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            (json["user"] as? String) == selfUserID
        else { return }
        onMicOpenRequested?()
    }

    private func handleSeatIntent(_ barrage: Barrage) {
        let userID = barrage.sender.userID
        guard !userID.isEmpty, let data = barrage.data.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let seat = json["seat"] as? Int
        else { return }
        if seat >= 0 { applicantSeatIndex[userID] = seat } else { applicantSeatIndex[userID] = nil }
        notifyApplicants()
    }

    private static func displayName(_ user: LiveUserInfo) -> String {
        user.userName.isEmpty ? user.userID : user.userName
    }

    private static func openMicrophone() {
        let open = { DeviceStore.shared.openLocalMicrophone(completion: nil) }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: open()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else { return }
                Task { @MainActor in open() }
            }
        default: break
        }
    }
}

private extension String {
    static var alreadySeated: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.error.already_seated")
    }
    static var applyTimeout: String { LiveKitResources.localizedString("tuilivekit.player.coguest.error.timeout") }
    static func inviteAccepted(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.invite_accepted", args)
    }
    static func inviteRejected(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.invite_rejected", args)
    }
    static var accepted: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.accepted") }
    static var applied: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.applied") }
    static func inviteTimeout(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.invite_timeout", args)
    }
    static var invited: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.invited") }
    static var joinedByInvite: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.comic.joined_by_invite")
    }
    static var kickedOff: String { LiveKitResources.localizedString("tuilivekit.player.coguest.error.kicked_off") }
    static var left: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.left") }
    static func newApplicant(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.new_applicant", args)
    }
    static var rejected: String { LiveKitResources.localizedString("tuilivekit.player.coguest.error.rejected") }
    static var retracted: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.retracted") }
}

enum VoiceLoungeErrorText {
    static func coGuest(_ error: ErrorInfo) -> String {
        LiveKitResources.localizedString(keys[error.code] ?? "tuilivekit.player.coguest.error.operation_failed")
    }

    static func coGuestApply(_ error: ErrorInfo) -> String {
        LiveKitResources.localizedString(keys[error.code] ?? "tuilivekit.player.coguest.error.apply_failed")
    }

    private static let keys: [Int: String] = [
        100_004: "tuilivekit.player.coguest.error.room_not_exist",
        100_005: "tuilivekit.player.coguest.error.not_room_member",
        100_200: "tuilivekit.player.coguest.error.seat_locked",
        100_202: "tuilivekit.player.coguest.error.already_requesting",
        100_203: "tuilivekit.player.coguest.error.already_on_seat",
        100_205: "tuilivekit.player.coguest.error.seat_full", 100_210: "tuilivekit.player.coguest.error.seat_occupied",
        100_211: "tuilivekit.player.coguest.error.not_supported",
    ]
}
