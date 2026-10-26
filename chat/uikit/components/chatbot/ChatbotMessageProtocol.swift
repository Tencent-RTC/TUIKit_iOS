import Foundation
import AtomicXCore

/// 机器人回复来源，对齐 Android ChatbotMessageSource。
enum ChatbotMessageSource {
    case flow
    case interrupt
    case error
    case unknown
}

struct ChatbotMessageData {
    let source: ChatbotMessageSource
    let chunks: [String]
    let isFinished: Bool
    let msgKey: String
    let errorInfo: String
    let isPlaceholder: Bool

    var displayText: String {
        switch source {
        case .flow:
            return chunks.joined()
        case .error:
            return errorInfo
        case .interrupt, .unknown:
            return ""
        }
    }
}

/// chatbotPlugin 自定义消息协议解析，对齐 Android ChatbotMessageProtocol。
enum ChatbotMessageProtocol {
    static let pluginValue = 2
    static let sourceFlow = 2
    static let sourceInterrupt = 22
    static let sourceError = 23
    static let finished = 1

    static func parse(_ message: MessageInfo) -> ChatbotMessageData? {
        guard message.messageType == .custom,
              case .custom(let payload) = message.messagePayload else {
            return nil
        }
        return parse(payload.customData)
    }

    static func createInterruptPayload(msgKey: String) -> String {
        return jsonString([
            "chatbotPlugin": pluginValue,
            "src": sourceInterrupt,
            "msgKey": msgKey
        ])
    }

    static func parse(_ customData: String?) -> ChatbotMessageData? {
        guard let customData = customData, !customData.isEmpty,
              let data = customData.data(using: .utf8),
              let json = ChatUtil.jsonData2Dictionary(jsonData: data) else {
            return nil
        }
        guard intValue(json, "chatbotPlugin") == pluginValue else {
            return nil
        }

        let source: ChatbotMessageSource
        switch intValue(json, "src") {
        case sourceFlow: source = .flow
        case sourceInterrupt: source = .interrupt
        case sourceError: source = .error
        default: source = .unknown
        }

        let chunks = (json["chunks"] as? [Any])?.compactMap { $0 as? String } ?? []
        let isFinished = intValue(json, "isFinished").map { $0 == finished } ?? true

        return ChatbotMessageData(
            source: source,
            chunks: chunks,
            isFinished: isFinished,
            msgKey: stringValue(json, "msgKey"),
            errorInfo: stringValue(json, "errorInfo"),
            isPlaceholder: boolValue(json, "localPlaceholder") ?? false
        )
    }

    static func makePlaceholderCustomData() -> String {
        return jsonString([
            "chatbotPlugin": pluginValue,
            "src": sourceFlow,
            "chunks": [String](),
            "isFinished": 0,
            "localPlaceholder": true
        ])
    }

    // MARK: - Private

    private static func jsonString(_ dictionary: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func intValue(_ json: [String: Any], _ key: String) -> Int? {
        if let value = json[key] as? Int { return value }
        if let value = json[key] as? NSNumber { return value.intValue }
        return nil
    }

    private static func stringValue(_ json: [String: Any], _ key: String) -> String {
        return json[key] as? String ?? ""
    }

    private static func boolValue(_ json: [String: Any], _ key: String) -> Bool? {
        if let value = json[key] as? Bool { return value }
        if let value = json[key] as? NSNumber { return value.boolValue }
        return nil
    }
}
