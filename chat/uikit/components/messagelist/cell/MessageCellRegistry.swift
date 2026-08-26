import Foundation
import AtomicXCore

enum MessageRenderKind: Equatable {

    case systemTip

    case revoked

    case bubble(MessageContentKind)

    case custom(businessID: String)
}

enum MessageContentKind: Equatable {
    case text
    case image
    case video
    case audio
    case file
    case face
    case merged

    case call

    case custom(String)

    case unsupported

    var reuseIdentifier: String {
        switch self {
        case .text: return "MessageCell.text"
        case .image: return "MessageCell.image"
        case .video: return "MessageCell.video"
        case .audio: return "MessageCell.audio"
        case .file: return "MessageCell.file"
        case .face: return "MessageCell.face"
        case .merged: return "MessageCell.merged"
        case .call: return "MessageCell.call"
        case .custom(let businessID): return "MessageCell.custom.\(businessID)"
        case .unsupported: return "MessageCell.unsupported"
        }
    }

    static var allReuseIdentifiers: [String] {
        let kinds: [MessageContentKind] = [.text, .image, .video, .audio, .file, .face, .merged, .call, .unsupported]
        return kinds.map { $0.reuseIdentifier }
    }
}

final class MessageCellRegistry {
    static let shared = MessageCellRegistry()

    var builtInReuseIdentifiers: [String] {
        let contentKinds: [MessageContentKind] = [.text, .image, .video, .audio, .file, .face, .merged, .call, .unsupported]
        return contentKinds.map { $0.reuseIdentifier } + [Self.systemTipReuseIdentifier, Self.revokedReuseIdentifier]
    }

    static let systemTipReuseIdentifier = "MessageCell.systemTip"

    static let revokedReuseIdentifier = "MessageCell.revoked"

    private var customSystemBusinessIDs: Set<String> = ["group_create"]

    private var customContentViewFactories: [String: () -> MessageContentView] = [:]

    var customReuseIdentifiers: [String] {
        return customContentViewFactories.keys.map { MessageContentKind.custom($0).reuseIdentifier }
    }

    // MARK: - Resolution

    func renderKind(for message: MessageInfo) -> MessageRenderKind {
        if message.status == .revoked {
            return .revoked
        }
        switch message.messagePayload {
        case .tips:
            return .systemTip
        case .custom(let payload):
            return resolveCustomKind(payload, message: message)
        case .text:
            return .bubble(.text)
        case .image:
            return .bubble(.image)
        case .video:
            return .bubble(.video)
        case .audio:
            return .bubble(.audio)
        case .file:
            return .bubble(.file)
        case .face:
            return .bubble(.face)
        case .merged:
            return .bubble(.merged)
        case .stream, .none:
            return .bubble(.unsupported)
        }
    }

    func reuseIdentifier(for kind: MessageRenderKind) -> String {
        switch kind {
        case .systemTip: return Self.systemTipReuseIdentifier
        case .revoked: return Self.revokedReuseIdentifier
        case .bubble(let contentKind): return contentKind.reuseIdentifier
        case .custom(let businessID): return MessageContentKind.custom(businessID).reuseIdentifier
        }
    }

    // MARK: - Custom Message Registration

    func registerCustomMessageCell(businessID: String,
                                   summaryProvider: @escaping (CustomMessagePayload) -> String?,
                                   makeContentView: @escaping () -> MessageContentView) {
        CustomMessageSummaryRegistry.shared.register(businessID: businessID, summaryProvider: summaryProvider)
        customContentViewFactories[businessID] = makeContentView
    }

    func makeCustomContentView(for businessID: String) -> MessageContentView? {
        return customContentViewFactories[businessID]?()
    }

    // MARK: - Centered Text (系统提示 / 撤回 居中灰字文案)

    func centeredText(for message: MessageInfo, kind: MessageRenderKind, config: MessageListConfigProtocol) -> String {
        switch kind {
        case .revoked:
            return MessageListHelper.getMessageAbstract(message)
        case .systemTip:
            guard config.isShowSystemMessage else { return "" }
            return systemTipText(for: message)
        default:
            return ""
        }
    }

    // MARK: - Private

    private init() {}

    private func systemTipText(for message: MessageInfo) -> String {
        switch message.messagePayload {
        case .tips(let payload):
            return MessageListHelper.getGroupTipsDisplayString(payload.groupTips)
        case .custom(let payload):
            if let callModel = CallMessageParser.parse(message) {
                return callModel.displayString(senderShowName: MessageListHelper.senderShowName(of: message))
            }
            return customSystemText(from: payload)
        default:
            return ""
        }
    }

    private func customSystemText(from payload: CustomMessagePayload) -> String {
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data) else {
            return ""
        }
        let opUser = customInfo["opUser"] as? String ?? ""
        let content = customInfo["content"] as? String ?? ""
        if !opUser.isEmpty, !content.isEmpty {
            return "\(opUser) \(content)"
        }
        return opUser.isEmpty ? content : opUser
    }

    private func resolveCustomKind(_ payload: CustomMessagePayload, message: MessageInfo) -> MessageRenderKind {

        if let callModel = CallMessageParser.parse(message) {
            return callModel.isGroup ? .systemTip : .bubble(.call)
        }
        guard let businessID = businessID(from: payload) else {
            return .bubble(.unsupported)
        }
        if customSystemBusinessIDs.contains(businessID) {
            return .systemTip
        }
        if customContentViewFactories[businessID] != nil {
            return .custom(businessID: businessID)
        }
        return .bubble(.unsupported)
    }

    private func businessID(from payload: CustomMessagePayload) -> String? {
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String else {
            return nil
        }
        return businessID
    }
}
