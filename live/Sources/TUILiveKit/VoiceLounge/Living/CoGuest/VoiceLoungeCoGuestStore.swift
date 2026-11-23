import AVFoundation
import AtomicXCore
import Combine
import Foundation
import UIKit

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

    var fadedSeatReleases: AnyPublisher<Void, Never> { fadedSeatReleaseSubject.eraseToAnyPublisher() }
    private let fadedSeatReleaseSubject = PassthroughSubject<Void, Never>()

    private(set) var guestStatus: GuestStatus = .idle {
        didSet {
            guard guestStatus != oldValue else { return }
            changeSubject.send()
        }
    }
    private(set) var applicants: [LiveUserInfo] = []
    private(set) var pendingUserIDs: Set<String> = []
    private(set) var invitees: [LiveUserInfo] = []
    private(set) var inviteeIDs: Set<String> = []
    private(set) var applicantSeatIndex: [String: Int] = [:]
    private(set) var inviteeSeatIndex: [String: Int] = [:]
    private(set) var connectedUsers: [SeatUserInfo] = []

    private var store: CoGuestStore?
    private var barrageStore: BarrageStore?
    static let seatIntentBusinessID = "vl_seat_apply"
    static let micOpenBusinessID = "vl_mic_open"
    static let pauseBusinessID = "vl_pause"

    var onMicOpenRequested: (() -> Void)?
    var onHostPauseChanged: ((Bool) -> Void)?
    var onMicrophoneDenied: (() -> Void)?
    private var liveID = ""
    private var role: VoiceLoungeRole = .audience
    private var cancellables = Set<AnyCancellable>()
    private let applyTimeout: TimeInterval = 60
    private let inviteTimeout: TimeInterval = 30
    private var pendingInviterID: String?
    private var pendingInviter: LiveUserInfo?

    private var selfUserID: String { LoginStore.shared.state.value.loginUserInfo?.userID ?? "" }

    private var pendingInviteDeadline: TimeInterval = 0

    var hasPendingInvitation: Bool {
        role == .audience && guestStatus != .onSeat && pendingInviterID != nil
            && ProcessInfo.processInfo.systemUptime < pendingInviteDeadline
    }

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
        invitees = []
        inviteeIDs = []
        applicantSeatIndex = [:]
        inviteeSeatIndex = [:]
        connectedUsers = []
        pendingInviterID = nil
        pendingInviter = nil
        guestStatus = .idle
        changeSubject.send()
    }

    @discardableResult func promptPendingInvitation() -> Bool {
        guard hasPendingInvitation, let pendingInviter else { return false }
        invitationSubject.send(.received(pendingInviter))
        return true
    }

    func apply(seatIndex: Int) {
        guard role == .audience, guestStatus == .idle, let store else { return }
        if promptPendingInvitation() { return }
        guestStatus = .applying
        store.applyForSeat(seatIndex: seatIndex, timeout: applyTimeout, extraInfo: "{\"mediaType\":\"audio\"}") {
            [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success: self.announceSeatIntent(seatIndex)
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
                self.apply(seatIndex: seatIndex)
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
        fadedSeatReleaseSubject.send()
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
    }

    func acceptInvitation() {
        guard role == .audience, let store, let inviterID = pendingInviterID else { return }
        clearPendingInvitation()
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
                    self.openMicrophone()
                case .failure(let error): self.onToast?(VoiceLoungeErrorText.coGuest(error))
                }
            }
        }
    }

    func rejectInvitation() {
        guard role == .audience, let store, let inviterID = pendingInviterID else { return }
        clearPendingInvitation()
        store.rejectInvitation(inviterID: inviterID, completion: nil)
        if guestStatus == .idle { fadedSeatReleaseSubject.send() }
    }

    private func clearPendingInvitation() {
        pendingInviterID = nil
        pendingInviter = nil
    }

    func invite(userID: String, seatIndex: Int) {
        guard role == .host, !userID.isEmpty, !pendingUserIDs.contains(userID) else { return }
        if seatIndex >= 0 { inviteeSeatIndex[userID] = seatIndex } else { inviteeSeatIndex[userID] = nil }
        perform(userID: userID) { [inviteTimeout] store, completion in
            store.inviteToSeat(
                userID: userID, seatIndex: seatIndex, timeout: inviteTimeout, extraInfo: nil, completion: completion)
        }
    }

    func cancelInvitation(userID: String) {
        perform(userID: userID) { store, completion in store.cancelInvitation(inviteeID: userID, completion: completion)
        }
    }

    func accept(userID: String) {
        perform(userID: userID) { store, completion in store.acceptApplication(userID: userID, completion: completion) }
    }

    func reject(userID: String) {
        perform(userID: userID) { store, completion in store.rejectApplication(userID: userID, completion: completion) }
    }

    func forgetUser(userID: String) {
        guard role == .host, !userID.isEmpty else { return }
        applicantSeatIndex[userID] = nil
        inviteeSeatIndex[userID] = nil
    }

    private func perform(userID: String, action: (CoGuestStore, @escaping CompletionClosure) -> Void) {
        guard role == .host, let store, !userID.isEmpty, !pendingUserIDs.contains(userID) else { return }
        pendingUserIDs.insert(userID)
        notifyApplicants()
        let liveID = self.liveID
        action(store) { [weak self] result in
            Task { @MainActor in
                guard let self, self.liveID == liveID else { return }
                self.pendingUserIDs.remove(userID)
                if case .failure(let error) = result { self.onToast?(VoiceLoungeErrorText.coGuest(error)) }
                self.notifyApplicants()
            }
        }
    }

    private func apply(_ state: CoGuestState) {
        let selfID = selfUserID
        switch role {
        case .host:
            var seen = Set<String>()
            applicants = state.applicants.filter {
                !$0.userID.isEmpty && $0.userID != selfID && seen.insert($0.userID).inserted
            }
            var inviteeSeen = Set<String>()
            invitees = state.invitees.filter {
                !$0.userID.isEmpty && $0.userID != selfID && inviteeSeen.insert($0.userID).inserted
            }
            inviteeIDs = Set(invitees.map(\.userID))
            inviteeSeatIndex = inviteeSeatIndex.filter { inviteeIDs.contains($0.key) }
            pendingUserIDs.formIntersection(Set(applicants.map(\.userID)).union(inviteeIDs))
            connectedUsers = state.connected.filter { !$0.userID.isEmpty && $0.userID != selfID }
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
                openMicrophone()
            } else {
                guestStatus = .idle
                onToast?(.rejected)
                fadedSeatReleaseSubject.send()
            }
        case .onGuestApplicationNoResponse(let reason):
            onToast?(reason == .alreadySeated ? .alreadySeated : .applyTimeout)
            if guestStatus == .applying { guestStatus = .idle }
        case .onKickedOffSeat:
            DeviceStore.shared.closeLocalMicrophone()
            guestStatus = .idle
        case .onHostInvitationReceived(let hostUser):
            guard guestStatus != .onSeat else { return }
            pendingInviterID = hostUser.userID
            pendingInviter = hostUser
            pendingInviteDeadline = ProcessInfo.processInfo.systemUptime + inviteTimeout
            invitationSubject.send(.received(hostUser))
        case .onHostInvitationCancelled:
            clearPendingInvitation()
            invitationSubject.send(.cancelled)
        @unknown default: break
        }
    }

    private func handleHostEvent(_ event: HostEvent) {
        switch event {
        case .onHostInvitationResponded(let isAccept, let user):
            if !isAccept { onToast?(.inviteRejected(Self.displayName(user))) }
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

    private func openMicrophone() {
        VoiceLoungeMicrophonePermission.request(
            onGranted: { DeviceStore.shared.openLocalMicrophone(completion: nil) },
            onDenied: { [weak self] in self?.onMicrophoneDenied?() })
    }
}

@MainActor enum VoiceLoungeMicrophonePermission {
    static func request(onGranted: @escaping @MainActor () -> Void, onDenied: @escaping @MainActor () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: onGranted()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in granted ? onGranted() : onDenied() }
            }
        default: onDenied()
        }
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private extension String {
    static var alreadySeated: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.error.already_seated")
    }
    static var applyTimeout: String { LiveKitResources.localizedString("tuilivekit.player.coguest.error.timeout") }
    static func inviteRejected(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.invite_rejected", args)
    }
    static func inviteTimeout(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.invite_timeout", args)
    }
    static var rejected: String { LiveKitResources.localizedString("tuilivekit.player.coguest.error.rejected") }
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
