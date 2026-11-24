import Foundation
import UIKit
import AtomicXCore

enum MessageActionIDs {
    static let multiSelect = "message.multiSelect"
    static let forward = "message.forward"
    static let quote = "message.quote"
    static let copy = "message.copy"
    static let recall = "message.recall"
    static let delete = "message.delete"
    static let convertToText = "message.convertToText"
    static let translate = "message.translate"
    static let readReceipt = "message.readReceipt"
    static let listenFromHere = "message.listenFromHere"
    static let reaction = "message.reaction"
}

enum MessageActionMenuProvider {

    private static let revokeTimeLimit: TimeInterval = 2 * 60

    static func visibleActions(
        for message: MessageInfo,
        config: ChatMessageListConfig,
        conversationID: String,
        auxiliaryHiddenIDs: Set<String> = [],
        source: AnyObject? = nil
    ) -> [MessageActionMenuAction] {
        var actions: [MessageActionMenuAction] = []

        if config._isSupportCopy, canCopy(message) {
            actions.append(copyAction())
        }
        if config._isSupportForward, canForward(message) {
            actions.append(forwardAction(source: source))
        }
        if canQuote(message, config: config) {
            actions.append(quoteAction(conversationID: conversationID))
        }
        if config._isSupportMultiSelect {
            actions.append(multiSelectAction(source: source))
        }
        if config._isSupportDelete {
            actions.append(deleteAction(source: source))
        }
        if config._isSupportRecall, canRecall(message) {
            actions.append(recallAction())
        }
        if config._isSupportConvertToText, canConvertToText(message, auxiliaryHiddenIDs: auxiliaryHiddenIDs) {
            actions.append(convertToTextAction(source: source))
        }
        if config._isSupportTranslate, canTranslate(message, auxiliaryHiddenIDs: auxiliaryHiddenIDs) {
            actions.append(translateAction(source: source))
        }
        if config._isSupportListenFromHere {
            actions.append(listenFromHereAction(source: source))
        }
        if let customizer = config._actionCustomizer {
            let editor = CustomEditor(items: actions)
            customizer(editor)
            return editor.build()
        }
        return actions
    }

    // MARK: - shouldShow 判定（对齐声明式各 ButtonConfig.shouldShow）

    private static func canCopy(_ message: MessageInfo) -> Bool {
        return message.messageType == .text && message.status != .violation
    }

    private static func canQuote(_ message: MessageInfo,
                                 config: ChatMessageListConfig) -> Bool {

        return config._isSupportQuote && message.status == .sendSuccess
    }

    private static func canForward(_ message: MessageInfo) -> Bool {
        return message.status == .sendSuccess
    }

    private static func canConvertToText(_ message: MessageInfo, auxiliaryHiddenIDs: Set<String>) -> Bool {
        guard message.messageType == .audio, message.status == .sendSuccess else { return false }
        guard case .audio(let payload) = message.messagePayload else { return false }
        let asrText = payload.asrText ?? ""
        return asrText.isEmpty || auxiliaryHiddenIDs.contains(message.msgID)
    }

    private static func canTranslate(_ message: MessageInfo, auxiliaryHiddenIDs: Set<String>) -> Bool {
        guard message.messageType == .text, message.status == .sendSuccess else { return false }
        guard case .text(let payload) = message.messagePayload else { return false }

        if auxiliaryHiddenIDs.contains(message.msgID) {
            return true
        }
        let targetLanguage = AppBuilderConfig.shared.translateTargetLanguage.isEmpty
            ? "en" : AppBuilderConfig.shared.translateTargetLanguage
        let translatedText = payload.translatedText ?? [:]

        let translatedToTarget = payload.translateLanguage == targetLanguage
            || translatedText[targetLanguage] != nil
        if !translatedText.isEmpty, translatedToTarget {
            return false
        }
        return true
    }

    private static func canRecall(_ message: MessageInfo) -> Bool {
        guard message.isSentBySelf, message.status == .sendSuccess else { return false }
        guard let timestamp = message.timestamp else { return false }
        let messageDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Date().timeIntervalSince(messageDate) < revokeTimeLimit
    }

    // MARK: - Action 工厂

    private static func copyAction() -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.copy,
            iconName: "message_copy",
            systemIconFallback: "doc.on.doc",
            label: LocalizedChatString("Copy")
        ) { message, _ in
            if case .text(let payload) = message.messagePayload {
                UIPasteboard.general.string = payload.text
            }
        }
    }

    private static func quoteAction(conversationID: String) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.quote,
            iconName: "message_quote",
            systemIconFallback: "quote.bubble",
            label: LocalizedChatString("Quote")
        ) { message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("quoteMessageNotification"),
                object: nil,
                userInfo: ["message": message, "conversationID": conversationID]
            )
        }
    }

    private static func forwardAction(source: AnyObject?) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.forward,
            iconName: "message_forward",
            systemIconFallback: "arrowshape.turn.up.right",
            label: LocalizedChatString("Forward")
        ) { [weak source] message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("showForwardTargetSelector"),
                object: source,
                userInfo: ["messages": [message]]
            )
        }
    }

    private static func convertToTextAction(source: AnyObject?) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.convertToText,
            iconName: "message_convert",
            systemIconFallback: "text.bubble",
            label: LocalizedChatString("ConvertToText")
        ) { [weak source] message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("convertVoiceToText"),
                object: source,
                userInfo: ["message": message]
            )
        }
    }

    private static func translateAction(source: AnyObject?) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.translate,
            iconName: "message_translate",
            systemIconFallback: "character.bubble",
            label: LocalizedChatString("Translate")
        ) { [weak source] message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("translateTextMessage"),
                object: source,
                userInfo: ["message": message]
            )
        }
    }

    private static func recallAction() -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.recall,
            iconName: "message_recall",
            systemIconFallback: "arrow.uturn.backward",
            label: LocalizedChatString("Revoke")
        ) { _, actionStore in
            actionStore.revoke { _ in }
        }
    }

    private static func multiSelectAction(source: AnyObject?) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.multiSelect,
            iconName: "message_multiselect",
            systemIconFallback: "checkmark.circle",
            label: LocalizedChatString("MultiSelect")
        ) { [weak source] message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("enterMultiSelectMode"),
                object: source,
                userInfo: ["initialMessage": message]
            )
        }
    }

    private static func listenFromHereAction(source: AnyObject?) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.listenFromHere,
            iconName: "message_listen_from_here",
            systemIconFallback: "speaker.wave.2",
            label: LocalizedChatString("VoiceListenFromHere")
        ) { [weak source] message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("listenFromHereNotification"),
                object: source,
                userInfo: ["message": message]
            )
        }
    }

    private static func deleteAction(source: AnyObject?) -> MessageActionMenuAction {
        MessageActionMenuAction(
            ID: MessageActionIDs.delete,
            iconName: "message_delete",
            systemIconFallback: "trash",
            label: LocalizedChatString("Delete"),
            isDangerous: true
        ) { [weak source] message, _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("deleteMessageNotification"),
                object: source,
                userInfo: ["message": message]
            )
        }
    }
}
