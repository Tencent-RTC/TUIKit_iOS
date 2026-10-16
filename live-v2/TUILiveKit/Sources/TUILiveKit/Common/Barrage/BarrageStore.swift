import AtomicXCore
import Combine
import Foundation

@MainActor
final class BarrageUIStore {
    struct Comment: Equatable {
        let id: String
        let senderName: String
        let text: String
        let level: Int
        let isHost: Bool
        let gift: LiveGiftComment?
        let timestamp: TimeInterval
    }

    struct State: Equatable {
        var liveID = ""
        var comments: [Comment] = []
    }

    var onStateChanged: ((State) -> Void)? {
        didSet { onStateChanged?(state) }
    }

    var onSendError: ((String) -> Void)?

    private var sessionID = UUID()
    private var pendingSends = Set<UUID>()
    private(set) var state = State()
    private var barrageStore: BarrageStore?
    private var cancellables = Set<AnyCancellable>()
    private var hostUserID = ""
    private var textComments: [Comment] = []
    private var giftComments: [Comment] = []

    func activate(liveID: String, hostUserID: String) {
        guard !liveID.isEmpty else {
            deactivate()
            return
        }
        if state.liveID == liveID,
           self.hostUserID == hostUserID,
           barrageStore != nil {
            return
        }

        deactivate()
        state.liveID = liveID
        self.hostUserID = hostUserID

        let sessionID = self.sessionID
        let barrageStore = BarrageStore.create(liveID: liveID)
        self.barrageStore = barrageStore
        barrageStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] barrageState in
                guard let self, self.sessionID == sessionID, self.state.liveID == liveID else { return }
                self.apply(barrageState)
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        sessionID = UUID()
        pendingSends.removeAll()
        cancellables.removeAll()
        barrageStore = nil
        hostUserID = ""
        textComments.removeAll()
        giftComments.removeAll()
        state = State()
        notify()
    }

    func sendComment(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard let barrageStore else { return }
        if isSelfMessageBanned() {
            onSendError?(Self.sendErrorMessage(code: 10017))
            return
        }
        let sessionID = self.sessionID
        let requestID = UUID()
        let liveID = state.liveID
        pendingSends.insert(requestID)
        barrageStore.sendTextMessage(text: value, extensionInfo: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.sessionID == sessionID,
                      self.pendingSends.remove(requestID) != nil else { return }
                if case .failure(let error) = result {
                    LiveKitLog.error("[BarrageUIStore] send comment failed liveID=\(liveID) code=\(error.code) message=\(error.message)")
                    self.onSendError?(Self.sendErrorMessage(code: error.code))
                }
            }
        }
    }

    func isSelfMessageBanned() -> Bool {
        guard !state.liveID.isEmpty,
              let userID = LoginStore.shared.state.value.loginUserInfo?.userID,
              !userID.isEmpty else { return false }
        return LiveAudienceStore.create(liveID: state.liveID).state.value
            .messageBannedUserList.contains { $0.userID == userID }
    }

    static func sendErrorMessage(code: Int) -> String {
        let key: String
        switch code {
        case 10017, -2381: key = "muted"
        case -2380: key = "all_muted"
        case 10023, 10006, 7008, 9506, -2: key = "too_frequent"
        case 7015, 80001: key = "content_rejected"
        case 8001, 80002: key = "too_long"
        case 6014, 6206, -1002: key = "login_expired"
        case 6208: key = "login_elsewhere"
        case -2101: key = "not_joined"
        case 10010: key = "room_unavailable"
        case 10007: key = "no_permission"
        case 9508, 9512: key = "network_error"
        case 9510, 9518...9521, 9523...9525: key = "timeout"
        case 10016: key = "send_rejected"
        default: key = "send_failed"
        }
        return LiveKitResources.localizedString("tuilivekit.comment.\(key)")
    }

    func appendGiftComment(_ gift: LiveGiftComment) {
        guard !state.liveID.isEmpty,
              !giftComments.contains(where: { $0.id == "gift-\(gift.id)" })
        else { return }

        let senderName = gift.senderName.isEmpty ? gift.senderID : gift.senderName
        giftComments.append(Comment(
            id: "gift-\(gift.id)",
            senderName: senderName.isEmpty
                ? LiveKitResources.localizedString("tuilivekit.common.viewer")
                : senderName,
            text: "",
            level: gift.senderLevel,
            isHost: false,
            gift: gift,
            timestamp: Date().timeIntervalSince1970
        ))
        giftComments = Array(giftComments.suffix(100))
        rebuildComments()
    }

    private func apply(_ barrageState: BarrageState) {
        textComments = barrageState.messageList.suffix(100).map { barrage in
            let senderName = barrage.sender.userName.isEmpty
                ? barrage.sender.userID
                : barrage.sender.userName
            return Comment(
                id: "\(barrage.sequence)-\(barrage.timestampInSecond)",
                senderName: senderName.isEmpty
                    ? LiveKitResources.localizedString("tuilivekit.common.viewer")
                    : senderName,
                text: barrage.textContent,
                level: barrage.sender.level,
                isHost: !hostUserID.isEmpty && barrage.sender.userID == hostUserID,
                gift: nil,
                timestamp: barrage.timestampInSecond
            )
        }
        rebuildComments()
    }

    private func rebuildComments() {
        state.comments = Array((textComments + giftComments)
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp { return lhs.id < rhs.id }
                return lhs.timestamp < rhs.timestamp
            }
            .suffix(100))
        notify()
    }

    private func notify() {
        onStateChanged?(state)
    }
}
