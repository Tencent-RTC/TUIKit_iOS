import UIKit
import Combine
import AtomicXCore

final class TypingIndicatorController {
    private static let typingSendInterval: TimeInterval = 4

    private static let peerActiveWindow: TimeInterval = 30

    private static let displayTimeout: TimeInterval = 5

    private static let recentMessageScanCount = 20

    private static let businessID = MessageInputView.typingMessageBusinessID

    private static let actionParamTyping = "EIMAMSG_InputStatus_Ing"

    private static let actionParamEnd = "EIMAMSG_InputStatus_End"

    private static let typingUserActionCode = 14

    private let conversationID: String

    private let peerUserID: String?

    private let currentUserID: String?

    private let messageListStore: MessageListStore

    private let messageInputStore: MessageInputStore

    private var cancellables = Set<AnyCancellable>()

    private var lastPeerMessageAt: TimeInterval?

    private var lastTypingStartSentAt: TimeInterval = 0

    private var hasSentTypingStart = false

    private var displayTimeoutWorkItem: DispatchWorkItem?

    private let typingSubject = CurrentValueSubject<Bool, Never>(false)

    var typingPublisher: AnyPublisher<Bool, Never> {
        return typingSubject.eraseToAnyPublisher()
    }

    init(conversationID: String, currentUserID: String?) {
        self.conversationID = conversationID
        self.currentUserID = currentUserID
        self.peerUserID = ChatUtil.getUserID(conversationID)
        self.messageListStore = MessageListStore.create(conversationID: conversationID)
        self.messageInputStore = MessageInputStore.create(conversationID: conversationID)
        bindIncomingMessages()
        initializePeerActivity()
    }

    func sendTypingStatus(hasContent: Bool) {
        guard peerUserID != nil else { return }
        guard isPeerActive() else { return }
        let now = Date().timeIntervalSince1970
        if hasContent {
            guard now - lastTypingStartSentAt >= Self.typingSendInterval else { return }
            lastTypingStartSentAt = now
            hasSentTypingStart = true
            sendTypingMessage(isTyping: true)
        } else {
            guard hasSentTypingStart else { return }
            hasSentTypingStart = false
            sendTypingMessage(isTyping: false)
        }
    }

    func invalidate() {
        displayTimeoutWorkItem?.cancel()
        cancellables.removeAll()
        if hasSentTypingStart {
            hasSentTypingStart = false
            sendTypingMessage(isTyping: false)
        }
        typingSubject.send(false)
    }

    private func bindIncomingMessages() {
        messageListStore.messageEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                guard case .onReceiveNewMessage(let message) = event,
                      message.from.userID == self.peerUserID
                else { return }
                if let isTyping = self.typingStatus(from: message) {
                    self.handlePeerTypingStatus(isTyping)
                    return
                }
                self.lastPeerMessageAt = Date().timeIntervalSince1970
            }
            .store(in: &cancellables)
    }

    private func typingStatus(from message: MessageInfo) -> Bool? {
        guard case .custom(let payload) = message.messagePayload,
              let data = payload.customData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let businessID = json["businessID"] as? String,
              businessID == Self.businessID
        else { return nil }
        if let typingStatus = json["typingStatus"] as? Int {
            return typingStatus == 1
        }
        if let actionParam = json["actionParam"] as? String {
            if actionParam == Self.actionParamTyping { return true }
            if actionParam == Self.actionParamEnd { return false }
        }
        return nil
    }

    private func initializePeerActivity() {
        let messages = messageListStore.state.value.messageList
        for message in messages.suffix(Self.recentMessageScanCount).reversed() {
            guard let peerUserID = peerUserID, message.from.userID == peerUserID else { continue }
            if let timestamp = message.timestamp, timestamp > 0 {
                lastPeerMessageAt = TimeInterval(timestamp)
            }
            break
        }
    }

    private func isPeerActive() -> Bool {
        guard let lastPeerMessageAt = lastPeerMessageAt else { return false }
        return Date().timeIntervalSince1970 - lastPeerMessageAt <= Self.peerActiveWindow
    }

    private func handlePeerTypingStatus(_ isTyping: Bool) {
        displayTimeoutWorkItem?.cancel()
        displayTimeoutWorkItem = nil
        if isTyping {
            typingSubject.send(true)
            let workItem = DispatchWorkItem { [weak self] in
                self?.typingSubject.send(false)
            }
            displayTimeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.displayTimeout, execute: workItem)
        } else {
            typingSubject.send(false)
        }
    }

    private func sendTypingMessage(isTyping: Bool) {
        let json: [String: Any] = [
            "businessID": Self.businessID,
            "typingStatus": isTyping ? 1 : 0,
            "version": 0,
            "userAction": isTyping ? Self.typingUserActionCode : 0,
            "actionParam": isTyping ? Self.actionParamTyping : Self.actionParamEnd
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        let payload = CustomSendMessagePayload(customData: jsonString)
        var option = SendMessageOption()
        option.onlineUserOnly = true
        messageInputStore.sendMessage(payload: .custom(payload), option: option, completion: nil)
    }
}
