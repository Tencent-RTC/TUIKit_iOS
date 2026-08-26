import Foundation
import AtomicXCore

enum CallProtocolType {
    case unknown
    case send
    case accept
    case reject
    case cancel
    case hangup
    case timeout
    case lineBusy
    case switchToAudio
    case switchToAudioConfirm
}

enum CallStreamMediaType {
    case unknown
    case voice
    case video
}

enum CallParticipantType {
    case unknown
    case c2c
    case group
}

enum CallParticipantRole {
    case unknown
    case caller
    case callee
}

struct CallMessageModel {
    let protocolType: CallProtocolType
    let streamMediaType: CallStreamMediaType
    let participantType: CallParticipantType
    let participantRole: CallParticipantRole
    let caller: String
    let inviteeList: [String]
    let duration: Int
    let isExcludeFromHistory: Bool

    var isCaller: Bool { participantRole == .caller }
    var isGroup: Bool { participantType == .group }
}

enum CallMessageParser {

    private static let businessIDKey = "businessID"
    private static let businessIDAVCall = "av_call"
    private static let businessIDRTCCall = "rtc_call"
    private static let businessIDTimeout = 1.0

    private static let actionInvite = 1
    private static let actionCancelInvite = 2
    private static let actionAcceptInvite = 3
    private static let actionRejectInvite = 4
    private static let actionInviteTimeout = 5

    private static let floatComparisonEpsilon = 0.000001

    static func parse(_ message: MessageInfo) -> CallMessageModel? {
        guard message.messageType == .custom,
              case .custom(let payload) = message.messagePayload,
              let customDataMap = parseJsonMap(payload.customData),
              let signalDataMap = parseSignalDataMap(customDataMap) else {
            return nil
        }

        guard isKnownBusinessID(signalDataMap[businessIDKey]) else {
            return nil
        }

        guard let actionType = anyToInt(customDataMap["actionType"]) else {
            return nil
        }
        let protocolType = parseProtocolType(actionType, signalDataMap)
        guard protocolType != .unknown else {
            return nil
        }

        let caller = parseCaller(signalDataMap)
        let excludeFromHistory = anyToBool(customDataMap["isExcludedFromLastMessage"])
            && anyToBool(customDataMap["isExcludedFromUnreadCount"])

        return CallMessageModel(
            protocolType: protocolType,
            streamMediaType: parseStreamMediaType(protocolType, signalDataMap),
            participantType: parseParticipantType(customDataMap),
            participantRole: parseParticipantRole(caller),
            caller: caller,
            inviteeList: parseInviteeList(customDataMap),
            duration: parseDuration(protocolType, signalDataMap),
            isExcludeFromHistory: excludeFromHistory
        )
    }


    // MARK: - Parse Helpers

    private static func parseJsonMap(_ json: String?) -> [String: Any]? {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return map
    }

    private static func parseSignalDataMap(_ customDataMap: [String: Any]) -> [String: Any]? {
        if let dataString = customDataMap["data"] as? String {
            return parseJsonMap(dataString)
        }
        return customDataMap["data"] as? [String: Any]
    }

    private static func isKnownBusinessID(_ value: Any?) -> Bool {
        if let string = value as? String {
            return string == businessIDAVCall || string == businessIDRTCCall
        }
        if let number = value as? NSNumber {
            return abs(number.doubleValue - businessIDTimeout) < floatComparisonEpsilon
        }
        return false
    }

    private static func parseProtocolType(_ actionType: Int, _ signalDataMap: [String: Any]) -> CallProtocolType {
        switch actionType {
        case actionInvite:
            if let data = signalDataMap["data"] as? [String: Any] {
                switch data["cmd"] as? String {
                case "switchToAudio": return .switchToAudio
                case "hangup": return .hangup
                case "videoCall", "audioCall": return .send
                default: return .unknown
                }
            }
            return signalDataMap["call_end"] != nil ? .hangup : .send
        case actionCancelInvite:
            return .cancel
        case actionAcceptInvite:
            let data = signalDataMap["data"] as? [String: Any]
            return data?["cmd"] as? String == "switchToAudio" ? .switchToAudioConfirm : .accept
        case actionRejectInvite:
            return signalDataMap["line_busy"] != nil ? .lineBusy : .reject
        case actionInviteTimeout:
            return .timeout
        default:
            return .unknown
        }
    }

    private static func parseStreamMediaType(_ protocolType: CallProtocolType, _ signalDataMap: [String: Any]) -> CallStreamMediaType {
        var type = CallStreamMediaType.unknown
        if let callType = anyToInt(signalDataMap["call_type"]) {
            switch callType {
            case 1: type = .voice
            case 2: type = .video
            default: break
            }
        }
        if protocolType == .send {
            let data = signalDataMap["data"] as? [String: Any]
            switch data?["cmd"] as? String {
            case "audioCall": type = .voice
            case "videoCall": type = .video
            default: break
            }
        } else if protocolType == .switchToAudio || protocolType == .switchToAudioConfirm {
            type = .video
        }
        return type
    }

    private static func parseParticipantType(_ customDataMap: [String: Any]) -> CallParticipantType {
        let groupID = customDataMap["groupID"] as? String ?? ""
        return groupID.isEmpty ? .c2c : .group
    }

    private static func parseCaller(_ signalDataMap: [String: Any]) -> String {
        let data = signalDataMap["data"] as? [String: Any]
        if let inviter = data?["inviter"] as? String, !inviter.isEmpty {
            return inviter
        }
        return LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }

    private static func parseParticipantRole(_ caller: String) -> CallParticipantRole {
        guard let loginUser = LoginStore.shared.state.value.loginUserInfo?.userID,
              !loginUser.isEmpty else {
            return .callee
        }
        return caller == loginUser ? .caller : .callee
    }

    private static func parseInviteeList(_ customDataMap: [String: Any]) -> [String] {
        guard let list = customDataMap["inviteeList"] as? [Any] else { return [] }
        return list.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func parseDuration(_ protocolType: CallProtocolType, _ signalDataMap: [String: Any]) -> Int {
        guard protocolType == .hangup else { return 0 }
        return anyToInt(signalDataMap["call_end"]) ?? 0
    }

    private static func anyToInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func anyToBool(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let string = value as? String { return string.lowercased() == "true" }
        if let number = value as? NSNumber { return number.intValue != 0 }
        return false
    }
}

// MARK: - Display String（对齐 Android getCallMessageDisplayString）

extension CallMessageModel {
    func displayString(senderShowName: String) -> String {
        if isGroup {
            return groupDisplayString(senderShowName: senderShowName)
        }
        return c2cDisplayString()
    }

    private func c2cDisplayString() -> String {
        switch protocolType {
        case .reject:
            return LocalizedChatString(isCaller ? "CallRejectCaller" : "CallRejectCallee")
        case .cancel:
            return LocalizedChatString(isCaller ? "CallCancelCaller" : "CallCancelCallee")
        case .hangup:
            return String(format: LocalizedChatString("CallDurationFormat"), Self.formatDuration(duration))
        case .timeout:
            return LocalizedChatString(isCaller ? "CallTimeoutCaller" : "CallTimeoutCallee")
        case .lineBusy:
            return LocalizedChatString(isCaller ? "CallLineBusyCaller" : "CallLineBusyCallee")
        case .send:
            return LocalizedChatString("CallStart")
        case .accept:
            return LocalizedChatString("CallAccept")
        case .switchToAudio:
            return LocalizedChatString("CallSwitchToAudio")
        case .switchToAudioConfirm:
            return LocalizedChatString("CallSwitchToAudioAccept")
        default:
            return LocalizedChatString("CallInvalidCommand")
        }
    }

    private func groupDisplayString(senderShowName: String) -> String {
        switch protocolType {
        case .send:
            return String(format: LocalizedChatString("CallGroupSendFormat"), senderShowName)
        case .cancel, .hangup:
            return LocalizedChatString("CallGroupEnd")
        case .timeout, .lineBusy:
            let names = inviteeList.joined(separator: "、")
            let suffix = protocolType == .lineBusy
                ? LocalizedChatString("CallLineBusyCallee")
                : LocalizedChatString("CallGroupNoAnswer")
            return names.isEmpty ? suffix : "\(names) \(suffix)"
        case .reject:
            return String(format: LocalizedChatString("CallGroupRejectFormat"), senderShowName)
        case .accept:
            return String(format: LocalizedChatString("CallGroupAcceptFormat"), senderShowName)
        case .switchToAudio:
            return String(format: LocalizedChatString("CallGroupSwitchToAudioFormat"), senderShowName)
        case .switchToAudioConfirm:
            return String(format: LocalizedChatString("CallGroupConfirmSwitchToAudioFormat"), senderShowName)
        default:
            return LocalizedChatString("CallInvalidCommand")
        }
    }

    private static func formatDuration(_ seconds: Int) -> String {
        return DateHelper.formatCallDuration(seconds)
    }
}
