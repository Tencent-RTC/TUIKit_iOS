import AtomicXCore
import Combine
import Foundation

@MainActor final class VoiceLoungeNoticeStore {
    private var liveID = ""
    private var role: VoiceLoungeRole = .audience
    private var isActive = false
    private var pendingNotices: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var sequence = 0
    private var openingTopic = ""
    private var isOpeningTopicShown = false

    func activate(liveID: String, role: VoiceLoungeRole, topic: String) {
        deactivate()
        guard !liveID.isEmpty else { return }
        self.liveID = liveID
        self.role = role
        isActive = true
        append(.civilityNotice)
        append(.adNotice)
        openingTopic = topic
        if role == .host { showOpeningTopic() }
        guard !pendingNotices.isEmpty else { return }
        LiveListStore.shared.state.subscribe().map(\.currentLive).filter { [liveID] in
            $0.liveID == liveID && !$0.liveOwner.userID.isEmpty
        }.first().receive(on: DispatchQueue.main).sink { [weak self] _ in self?.flushPending() }.store(
            in: &cancellables)
    }

    func updateTopic(_ topic: String) {
        guard isActive, !isOpeningTopicShown else { return }
        openingTopic = topic
    }

    func showOpeningTopic() {
        guard isActive, !isOpeningTopicShown else { return }
        isOpeningTopicShown = true
        if !openingTopic.isEmpty { append(.topicNotice(openingTopic)) }
    }

    func deactivate() {
        isActive = false
        liveID = ""
        openingTopic = ""
        isOpeningTopicShown = false
        pendingNotices = []
        cancellables.removeAll()
    }

    private func append(_ text: String) {
        guard let host = hostSender() else {
            pendingNotices.append(text)
            return
        }
        appendTip(text, sender: host)
    }

    private func flushPending() {
        guard isActive, let host = hostSender() else { return }
        let notices = pendingNotices
        pendingNotices = []
        notices.forEach { appendTip($0, sender: host) }
    }

    private func appendTip(_ text: String, sender: LiveUserInfo) {
        sequence += 1
        var barrage = Barrage()
        barrage.liveID = liveID
        barrage.sender = sender
        barrage.sequence = -sequence
        barrage.timestampInSecond = Date().timeIntervalSince1970
        barrage.messageType = .text
        barrage.textContent = text
        BarrageStore.create(liveID: liveID).appendLocalTip(message: barrage)
    }

    private func hostSender() -> LiveUserInfo? {
        if role == .host {
            guard let profile = LoginStore.shared.state.value.loginUserInfo, !profile.userID.isEmpty else { return nil }
            var user = LiveUserInfo()
            user.userID = profile.userID
            user.userName = profile.nickname ?? ""
            user.avatarURL = profile.avatarURL ?? ""
            user.level = Int(profile.level ?? 0)
            return user
        }
        let live = LiveListStore.shared.state.value.currentLive
        guard live.liveID == liveID, !live.liveOwner.userID.isEmpty else { return nil }
        return live.liveOwner
    }
}

private extension String {
    static var civilityNotice: String { LiveKitResources.localizedString("tuilivekit.voiceroom.notice.civility") }
    static var adNotice: String { LiveKitResources.localizedString("tuilivekit.voiceroom.notice.no_ads") }
    static func topicNotice(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.notice.topic", args)
    }
}
