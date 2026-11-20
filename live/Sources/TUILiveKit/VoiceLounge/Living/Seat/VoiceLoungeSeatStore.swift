import AtomicXCore
import Combine
import Foundation
import UIKit

@MainActor final class VoiceLoungeSeatStore {
    let liveID: String
    let role: VoiceLoungeRole
    let coGuest: VoiceLoungeCoGuestStore
    let muteCache: VoiceLoungeMuteCache
    let settings: VoiceLoungeSettings

    var layout: VoiceLoungeSeatLayout { settings.seatLayout }
    var skin: VoiceLoungeSkin { settings.skin }
    private(set) var seats: [VoiceLoungeSeat] = VoiceLoungeSeatTemplate.seats(
        for: .oneV8, hostName: "", hostAvatarURL: "")
    private(set) var seatList: [SeatInfo] = []
    private(set) var audienceFadedSeatIndex: Int?
    var isHostMicOff = false { didSet { if oldValue != isHostMicOff { refresh() } } }

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }
    var cancelApplicationPrompts: AnyPublisher<Void, Never> { cancelApplicationSubject.eraseToAnyPublisher() }
    var leavePrompts: AnyPublisher<Void, Never> { leaveSubject.eraseToAnyPublisher() }

    private let changeSubject = PassthroughSubject<Void, Never>()
    private let cancelApplicationSubject = PassthroughSubject<Void, Never>()
    private let leaveSubject = PassthroughSubject<Void, Never>()

    private var speakingUsers: [String: Int] = [:]
    private var localMicVolume = 0
    private var adminUserIDs: Set<String> = []
    private var showsAudienceFadedSeat = true
    private var isStaleCleanupEnabled = false
    private var hasCleanedStaleSeats = false
    private var hasCleanedStaleAdmins = false

    private var seatStore: LiveSeatStore?
    private var audienceStore: LiveAudienceStore?
    private var sessionCancellables = Set<AnyCancellable>()
    private var audienceCancellables = Set<AnyCancellable>()
    private var bindingCancellables = Set<AnyCancellable>()
    private var audienceVolumeToken: SubscriptionToken?

    init(
        liveID: String, role: VoiceLoungeRole, coGuest: VoiceLoungeCoGuestStore, muteCache: VoiceLoungeMuteCache,
        settings: VoiceLoungeSettings
    ) {
        self.liveID = liveID
        self.role = role
        self.coGuest = coGuest
        self.muteCache = muteCache
        self.settings = settings
        settings.changes.sink { [weak self] in self?.refresh(force: true) }.store(in: &bindingCancellables)
        coGuest.changes.sink { [weak self] in self?.handleCoGuestChange() }.store(in: &bindingCancellables)
        coGuest.fadedSeatReleases.sink { [weak self] in self?.hideAudienceFadedSeat() }.store(in: &bindingCancellables)
        muteCache.changes.sink { [weak self] in self?.refresh() }.store(in: &bindingCancellables)
    }

}

extension VoiceLoungeSeatStore {
    func activate() {
        guard seatStore == nil else { return }
        let store = LiveSeatStore.create(liveID: liveID)
        seatStore = store
        store.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            self?.applySeatState(seatList: state.seatList, speakingUsers: state.speakingUsers)
        }.store(in: &sessionCancellables)
        DeviceStore.shared.state.subscribe().map { $0.microphoneStatus == .on ? $0.currentMicVolume : 0 }
            .removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] volume in
                self?.localMicVolume = volume
                self?.refresh()
            }.store(in: &sessionCancellables)
        subscribeAudienceVolume()
    }

    private func subscribeAudienceVolume() {
        guard role == .audience, audienceVolumeToken == nil else { return }
        let liveID = self.liveID
        audienceVolumeToken = EngineBridge.subscribe(event: "CoreViewModule.stateChanged") { [weak self] id, json in
            guard id == liveID, let data = json.data(using: .utf8),
                let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                dict["property"] as? String == "speaking_users", let raw = dict["speaking_users"] as? [String: Any]
            else { return }
            var map: [String: Int] = [:]
            for (userID, value) in raw { if let intValue = (value as? NSNumber)?.intValue { map[userID] = intValue } }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.speakingUsers = map
                self.refresh()
            }
        }
    }

    private func unsubscribeAudienceVolume() {
        if let token = audienceVolumeToken { EngineBridge.unsubscribe(token) }
        audienceVolumeToken = nil
    }

    func activateAudienceList() {
        guard audienceStore == nil else { return }
        let store = LiveAudienceStore.create(liveID: liveID)
        audienceStore = store
        store.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            guard let self else { return }
            self.adminUserIDs = Set(state.adminList.map(\.userID).filter { !$0.isEmpty })
            self.cleanStaleAdminsIfNeeded()
            self.refresh()
        }.store(in: &audienceCancellables)
        if role == .host {
            store.liveAudienceEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
                guard case .onAudienceLeft(let user) = event else { return }
                self?.coGuest.forgetUser(userID: user.userID)
            }.store(in: &audienceCancellables)
        }
        store.fetchAudienceList(completion: nil)
    }

    func enableStaleCleanup() {
        guard role == .host else { return }
        isStaleCleanupEnabled = true
        cleanStaleSeatsIfNeeded()
        cleanStaleAdminsIfNeeded()
    }

    func deactivate() {
        sessionCancellables.removeAll()
        audienceCancellables.removeAll()
        unsubscribeAudienceVolume()
        seatStore = nil
        audienceStore = nil
        seatList = []
        speakingUsers = [:]
        localMicVolume = 0
        adminUserIDs = []
        showsAudienceFadedSeat = true
        audienceFadedSeatIndex = nil
        isStaleCleanupEnabled = false
        hasCleanedStaleSeats = false
        hasCleanedStaleAdmins = false
        muteCache.reset()
        isHostMicOff = false
        refresh()
    }

    func moveAudienceFadedSeat(to index: Int) {
        audienceFadedSeatIndex = index
        refresh()
    }

    func promptCancelApplication() { cancelApplicationSubject.send() }

    func promptLeave() { leaveSubject.send() }

    var hasNoFreeGuestSeat: Bool { !seats.contains { $0.role != .host && ($0.state == .empty || $0.state == .faded) } }

    var isSelfMicOff: Bool { selfSeatUser.map { muteCache.isMicOff($0) } ?? true }

    @discardableResult func toggleSelfMicrophone() -> Bool {
        guard let user = selfSeatUser else { return true }
        if user.microphoneStatus == .on {
            seatStore?.muteMicrophone()
            return true
        }
        guard user.allowOpenMicrophone else { return false }
        seatStore?.unmuteMicrophone { result in
            guard case .failure(let error) = result else { return }
            LiveKitLog.error("[VoiceLounge] unmute self failed: code=\(error.code), message=\(error.message)")
        }
        return true
    }
}

private extension VoiceLoungeSeatStore {
    static let speakingVolumeThreshold = 5

    var selfUserID: String { LoginStore.shared.state.value.loginUserInfo?.userID ?? "" }

    var selfSeatUser: SeatUserInfo? {
        let selfID = selfUserID
        guard !selfID.isEmpty else { return nil }
        return seatList.first { $0.userInfo.userID == selfID }?.userInfo
    }

    func applySeatState(seatList: [SeatInfo], speakingUsers: [String: Int]) {
        self.seatList = seatList
        self.speakingUsers = speakingUsers
        if role == .host {
            muteCache.reconcile(with: seatList)
            cleanStaleSeatsIfNeeded()
        }
        refresh()
    }

    func handleCoGuestChange() {
        if role == .audience, coGuest.guestStatus == .onSeat {
            showsAudienceFadedSeat = false
            audienceFadedSeatIndex = nil
        }
        refresh()
    }

    func hideAudienceFadedSeat() {
        guard role == .audience, coGuest.guestStatus == .idle else { return }
        showsAudienceFadedSeat = false
        audienceFadedSeatIndex = nil
        refresh()
    }

    func cleanStaleSeatsIfNeeded() {
        guard role == .host, isStaleCleanupEnabled, !hasCleanedStaleSeats, let seatStore else { return }
        hasCleanedStaleSeats = true
        let selfID = selfUserID
        let stale = seatList.map(\.userInfo.userID).filter { !$0.isEmpty && $0 != selfID }
        guard !stale.isEmpty else { return }
        LiveKitLog.info("[VoiceLounge] clean stale seats on start: \(stale)")
        stale.forEach { seatStore.kickUserOutOfSeat(userID: $0, completion: nil) }
    }

    func cleanStaleAdminsIfNeeded() {
        guard role == .host, isStaleCleanupEnabled, !hasCleanedStaleAdmins, let audienceStore else { return }
        hasCleanedStaleAdmins = true
        let selfID = selfUserID
        let stale = adminUserIDs.filter { $0 != selfID }
        guard !stale.isEmpty else { return }
        LiveKitLog.info("[VoiceLounge] clean stale admins on start: \(stale)")
        stale.forEach { audienceStore.revokeAdministrator(userID: $0, completion: nil) }
    }

    func refresh(force: Bool = false) {
        var next = projectFadedSeats(
            overlaySeats(
                VoiceLoungeSeatTemplate.seats(
                    for: layout, hostName: settings.hostName, hostAvatarURL: settings.hostAvatarURL), with: seatList))
        if role == .host, let index = next.firstIndex(where: { $0.role == .host }) {
            next[index].isMuted = isHostMicOff
        }
        for index in next.indices { next[index].accentColor = skin.mid }
        guard force || next != seats else { return }
        seats = next
        changeSubject.send()
    }

    func overlaySeats(_ base: [VoiceLoungeSeat], with seatList: [SeatInfo]) -> [VoiceLoungeSeat] {
        base.map { seat in
            var result = seat
            if let sdk = seatList.first(where: { $0.index == seat.index }) {
                if !sdk.userInfo.userID.isEmpty {
                    result.state = .occupied
                    result.userID = sdk.userInfo.userID
                    result.name = sdk.userInfo.userName.isEmpty ? sdk.userInfo.userID : sdk.userInfo.userName
                    result.avatarURL = sdk.userInfo.avatarURL
                    result.isMuted = muteCache.isMicOff(sdk.userInfo)
                    result.isAdmin = isAdministrator(sdk.userInfo)
                } else if sdk.isLocked {
                    result.state = .locked
                }
            }
            if result.role == .host, result.userID.isEmpty { result.userID = settings.hostUserID }
            result.isSpeaking = result.state == .occupied && isSpeaking(result.userID)
            return result
        }
    }

    func isAdministrator(_ info: SeatUserInfo) -> Bool { adminUserIDs.contains(info.userID) || info.role == .admin }

    func isSpeaking(_ userID: String) -> Bool {
        guard !userID.isEmpty else { return false }
        let volume = userID == selfUserID ? localMicVolume : (speakingUsers[userID] ?? 0)
        return volume > Self.speakingVolumeThreshold
    }

    func projectFadedSeats(_ seats: [VoiceLoungeSeat]) -> [VoiceLoungeSeat] {
        var result = seats
        let selfID = selfUserID
        let onSeatIDs = Set(seats.filter { $0.state == .occupied }.map(\.userID))

        switch role {
        case .audience:
            guard !selfID.isEmpty, coGuest.guestStatus != .onSeat, !onSeatIDs.contains(selfID),
                showsAudienceFadedSeat || coGuest.guestStatus == .applying
            else {
                if let index = audienceFadedSeatIndex,
                    !result.contains(where: { $0.index == index && $0.state == .empty && $0.role != .host })
                {
                    audienceFadedSeatIndex = nil
                }
                return result
            }
            let preferred = audienceFadedSeatIndex.flatMap { index in
                result.firstIndex { $0.index == index && $0.state == .empty && $0.role != .host }
            }
            guard let slot = preferred ?? result.firstIndex(where: { $0.state == .empty && $0.role != .host }) else {
                return result
            }
            audienceFadedSeatIndex = result[slot].index
            let profile = LoginStore.shared.state.value.loginUserInfo
            let applying = coGuest.guestStatus == .applying
            result[slot].state = .faded
            result[slot].userID = selfID
            result[slot].name = profile?.nickname ?? selfID
            result[slot].avatarURL = profile?.avatarURL ?? ""
            result[slot].pillText = applying ? .pillPending : .pillApply
            result[slot].isPillHighlighted = false
        case .host:
            let applicants = coGuest.applicants.filter { !onSeatIDs.contains($0.userID) && $0.userID != selfID }
            let applicantIDs = Set(applicants.map(\.userID))
            let invitees = coGuest.invitees.filter {
                !onSeatIDs.contains($0.userID) && $0.userID != selfID && !applicantIDs.contains($0.userID)
            }
            var slots = result.indices.filter { result[$0].state == .empty && result[$0].role != .host }
            func place(_ user: LiveUserInfo, at slot: Int, isApplicant: Bool) {
                result[slot].state = .faded
                result[slot].userID = user.userID
                result[slot].name = user.userName.isEmpty ? user.userID : user.userName
                result[slot].avatarURL = user.avatarURL
                result[slot].pillText = isApplicant ? .pillStart : .pillInvitePending
                result[slot].isPillHighlighted = isApplicant
            }
            let requests =
                applicants.map { ($0, true, coGuest.applicantSeatIndex[$0.userID]) }
                + invitees.map { ($0, false, coGuest.inviteeSeatIndex[$0.userID]) }
            var unplaced: [(LiveUserInfo, Bool)] = []
            for (user, isApplicant, seatIndex) in requests {
                if let seatIndex, let position = slots.firstIndex(where: { result[$0].index == seatIndex }) {
                    place(user, at: slots.remove(at: position), isApplicant: isApplicant)
                } else {
                    unplaced.append((user, isApplicant))
                }
            }
            var iterator = slots.makeIterator()
            for (user, isApplicant) in unplaced {
                guard let slot = iterator.next() else { break }
                place(user, at: slot, isApplicant: isApplicant)
            }
        }
        return result
    }
}

private extension String {
    static var pillPending: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.pill_pending") }
    static var pillInvitePending: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.seat.pill_invite_pending")
    }
    static var pillApply: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.pill_apply") }
    static var pillStart: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.pill_start") }
}

struct VoiceLoungeSeat: Equatable {
    enum Role: Equatable {
        case host
        case cohost
        case guest
    }

    enum State: Equatable {
        case empty
        case occupied
        case locked
        case faded
    }

    let index: Int
    var role: Role
    var state: State
    var name: String
    var avatarURL: String
    var userID: String = ""
    var isSpeaking: Bool
    var isMuted: Bool
    var pillText: String = ""
    var isPillHighlighted: Bool = false
    var isAdmin: Bool = false
    var accentColor: UIColor?

    init(
        index: Int, role: Role = .guest, state: State = .empty, name: String = "", avatarURL: String = "",
        isSpeaking: Bool = false, isMuted: Bool = false
    ) {
        self.index = index
        self.role = role
        self.state = state
        self.name = name
        self.avatarURL = avatarURL
        self.isSpeaking = isSpeaking
        self.isMuted = isMuted
    }
}

enum VoiceLoungeSeatTemplate {
    static func seats(for layout: VoiceLoungeSeatLayout, hostName: String, hostAvatarURL: String) -> [VoiceLoungeSeat] {
        let hostState: VoiceLoungeSeat.State = hostName.isEmpty ? .empty : .occupied
        switch layout {
        case .oneV8, .oneV8x:
            var seats: [VoiceLoungeSeat] = [
                VoiceLoungeSeat(index: 0, role: .host, state: hostState, name: hostName, avatarURL: hostAvatarURL)
            ]
            for i in 1...8 { seats.append(VoiceLoungeSeat(index: i, role: .guest, state: .empty)) }
            return seats
        case .twoV8:
            var seats: [VoiceLoungeSeat] = [
                VoiceLoungeSeat(index: 0, role: .host, state: hostState, name: hostName, avatarURL: hostAvatarURL),
                VoiceLoungeSeat(index: 1, role: .cohost, state: .empty),
            ]
            for i in 2...9 { seats.append(VoiceLoungeSeat(index: i, role: .guest, state: .empty)) }
            return seats
        case .duo:
            return [
                VoiceLoungeSeat(index: 0, role: .host, state: hostState, name: hostName, avatarURL: hostAvatarURL),
                VoiceLoungeSeat(index: 1, role: .guest, state: .empty),
            ]
        }
    }

    static func oneV8(hostName: String, hostAvatarURL: String) -> [VoiceLoungeSeat] {
        seats(for: .oneV8, hostName: hostName, hostAvatarURL: hostAvatarURL)
    }
}

@MainActor final class VoiceLoungeMuteCache {
    private(set) var values: [String: Bool] = [:]

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }
    private let changeSubject = PassthroughSubject<Void, Never>()

    func isMicOff(_ info: SeatUserInfo) -> Bool { values[info.userID] ?? info.isMicOff }

    func set(_ disabled: Bool, for userID: String) {
        values[userID] = disabled
        changeSubject.send()
    }

    func reconcile(with seatList: [SeatInfo]) {
        guard !values.isEmpty else { return }
        let seatUsers = Dictionary(
            seatList.filter { !$0.userInfo.userID.isEmpty }.map { ($0.userInfo.userID, $0.userInfo) },
            uniquingKeysWith: { first, _ in first })
        values = values.filter { userID, disabled in
            guard let info = seatUsers[userID] else { return false }
            return info.isMicOff != disabled
        }
    }

    func reset() { values = [:] }
}

extension SeatUserInfo { var isMicOff: Bool { microphoneStatus != .on || !allowOpenMicrophone } }
