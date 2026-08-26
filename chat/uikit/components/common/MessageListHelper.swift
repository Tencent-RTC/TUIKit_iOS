import AtomicXCore
import Foundation

class MessageListHelper {
    private static let mergedTitleMaxSenderCount = 2

    private static let mergedAbstractMaxCount = 4

    static func getGroupTipsDisplayString(_ groupTips: [GroupTipsInfo]?) -> String {
        guard let groupTips = groupTips, !groupTips.isEmpty else {
            return ""
        }

        let parts = groupTips.compactMap { info -> String? in
            let result = getGroupTipDisplayString(info)
            return result.isEmpty ? nil : result
        }

        return parts.isEmpty ? LocalizedChatString("unknown") : parts.joined(separator: LocalizedChatString("MessageTipsSeparator"))
    }

    static func getGroupTipDisplayString(_ groupTip: GroupTipsInfo) -> String {
        switch groupTip {
        case .unknown:
            return ""

        case .joinGroup(let joinMember):
            return String(format: LocalizedChatString("MessageTipsJoinGroupFormat"), displayName(joinMember))

        case .inviteToGroup(let inviter, let invitees):
            let inviteesShowName = invitees.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsInviteJoinGroupFormat"), displayName(inviter), inviteesShowName)

        case .quitGroup(let quitMember):
            return String(format: LocalizedChatString("MessageTipsLeaveGroupFormat"), displayName(quitMember))

        case .kickedFromGroup(let opUser, let kickedMembers):
            let kickedMembersShowName = kickedMembers.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsKickoffGroupFormat"), displayName(opUser), kickedMembersShowName)

        case .setGroupAdmin(_, let setAdminMembers):
            let setAdminMembersShowName = setAdminMembers.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsSettAdminFormat"), setAdminMembersShowName)

        case .cancelGroupAdmin(_, let cancelAdminMembers):
            let cancelAdminMembersShowName = cancelAdminMembers.map { displayName($0) }.joined(separator: ", ")
            return String(format: LocalizedChatString("MessageTipsCancelAdminFormat"), cancelAdminMembersShowName)

        case .muteGroupMember(_, let isSelfMuted, let mutedGroupMembers, let muteTime):
            let mutedGroupMembersShowName = mutedGroupMembers.map { displayName($0) }.joined(separator: ", ")
            let actualShowName = isSelfMuted ? LocalizedChatString("You") : mutedGroupMembersShowName
            return "\(actualShowName) \(muteTime == 0 ? LocalizedChatString("MessageTipsUnmute") : LocalizedChatString("MessageTipsMute"))"

        case .pinGroupMessage(let opUser):
            return String(format: LocalizedChatString("MessageTipsGroupPinMessage"), displayName(opUser))

        case .unpinGroupMessage(let opUser):
            return String(format: LocalizedChatString("MessageTipsGroupUnPinMessage"), displayName(opUser))

        case .changeGroupName(let opUser, let groupName):
            return String(format: LocalizedChatString("MessageTipsEditGroupNameFormat"), displayName(opUser), groupName)

        case .changeGroupIntroduction(let opUser, let groupIntroduction):
            return String(format: LocalizedChatString("MessageTipsEditGroupIntroFormat"), displayName(opUser), groupIntroduction)

        case .changeGroupNotification(let opUser, let groupNotification):
            let format = groupNotification.isEmpty ? LocalizedChatString("MessageTipsDeleteGroupAnnounceFormat") : LocalizedChatString("MessageTipsEditGroupAnnounceFormat")
            return String(format: format, displayName(opUser), groupNotification)

        case .changeGroupAvatar(let opUser, _):
            return String(format: LocalizedChatString("MessageTipsEditGroupAvatarFormat"), displayName(opUser))

        case .changeGroupOwner(let opUser, let groupOwner):
            return String(format: LocalizedChatString("MessageTipsEditGroupOwnerFormat"), displayName(opUser), groupOwner)

        case .changeGroupMuteAll(let opUser, let isMuteAll):
            let format = isMuteAll ? LocalizedChatString("SetShutupAllFormatString") : LocalizedChatString("CancelShutupAllFormatString")
            return String(format: format, displayName(opUser))

        case .changeJoinGroupApproval(let opUser, let groupJoinOption):
            var desc = ""
            switch groupJoinOption {
            case .forbid:
                desc = LocalizedChatString("GroupProfileJoinDisable")
            case .auth:
                desc = LocalizedChatString("GroupProfileAdminApprove")
            case .any:
                desc = LocalizedChatString("GroupProfileAutoApproval")
            }
            return String(format: LocalizedChatString("MessageTipsEditGroupAddOptFormat"), displayName(opUser), desc)

        case .changeInviteToGroupApproval(let opUser, let groupInviteOption):
            var desc = ""
            switch groupInviteOption {
            case .forbid:
                desc = LocalizedChatString("GroupProfileInviteDisable")
            case .auth:
                desc = LocalizedChatString("GroupProfileAdminApprove")
            case .any:
                desc = LocalizedChatString("GroupProfileAutoApproval")
            }
            return String(format: LocalizedChatString("MessageTipsEditGroupInviteOptFormat"), displayName(opUser), desc)
        }
    }

    static func getMessageAbstract(_ messageInfo: MessageInfo?, showMergedTitle: Bool = false) -> String {
        guard let messageInfo = messageInfo else { return "" }

        if messageInfo.status == .revoked {
            if messageInfo.isSentBySelf {
                return LocalizedChatString("MessageTipsYouRecallMessage")
            } else if messageInfo.conversationType == .c2c {
                return LocalizedChatString("MessageTipsOthersRecallMessage")
            } else {
                return String(format: LocalizedChatString("MessageTipsRecallMessageFormat"), messageInfo.from.userID)
            }
        }

        switch messageInfo.messageType {
        case .text:
            if case .text(let payload) = messageInfo.messagePayload {
                return payload.text
            }
            return ""

        case .image:
            return LocalizedChatString("MessageTypeImage")

        case .audio:
            if case .audio(let payload) = messageInfo.messagePayload {
                let voiceLabel = LocalizedChatString("MessageTypeVoice")
                let duration = payload.audioDuration
                if duration > 0 {
                    return "\(voiceLabel) \(duration)\""
                }
                return voiceLabel
            }
            return LocalizedChatString("MessageTypeVoice")

        case .file:
            return LocalizedChatString("MessageTypeFile")

        case .video:
            return LocalizedChatString("MessageTypeVideo")

        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")

        case .custom:

            if let callModel = CallMessageParser.parse(messageInfo) {
                return callModel.displayString(senderShowName: Self.senderShowName(of: messageInfo))
            }
            if case .custom(let payload) = messageInfo.messagePayload,
               let data = payload.customData.data(using: .utf8),
               let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
               let businessID = customInfo["businessID"] as? String,
               businessID == "group_create"
            {
                let sender = customInfo["opUser"] as? String ?? ""
                let cmd = customInfo["cmd"] as? Int ?? 0

                return String(format: cmd == 1 ? LocalizedChatString("TUICommunityCreateTipsMessage") : LocalizedChatString("TUIGroupCreateTipsMessage"), sender)
            }
            if case .custom(let payload) = messageInfo.messagePayload,
               let summary = CustomMessageSummaryRegistry.shared.summary(for: payload),
               !summary.isEmpty
            {
                return summary
            }
            return LocalizedChatString("MessageUnsupportedType")

        case .tips:
            if case .tips(let payload) = messageInfo.messagePayload {
                return getGroupTipsDisplayString(payload.groupTips)
            }
            return ""

        case .merged:
            if showMergedTitle, case .merged(let payload) = messageInfo.messagePayload, !payload.title.isEmpty {
                let title = payload.title
                return title
            }
            return LocalizedChatString("MessageTypeMergedHistory")

        default:
            return ""
        }
    }

    static func shouldShowReadReceipt(message: MessageInfo, isInMergedDetailView: Bool = false) -> Bool {
        return !isInMergedDetailView &&
            AppBuilderConfig.shared.enableReadReceipt &&
            message.isSentBySelf &&
            message.needReadReceipt &&
            message.status == .sendSuccess &&
            message.messageType != .tips
    }


    // MARK: - Message Forwarding

    static func getMessageAbstractForForward(_ message: MessageInfo) -> String {
        let senderName: String
        if let nickname = message.from.nickname, !nickname.isEmpty {
            senderName = nickname
        } else {
            senderName = message.from.userID
        }
        let content = getMessageAbstract(message)
        return alignEmojiString(userName: senderName, text: content)
    }

    static func generateMergedTitle(messages: [MessageInfo], conversationID: String) -> String {

        let isGroupChat = conversationID.hasPrefix("group_")

        if isGroupChat {

            return LocalizedChatString("RelayGroupChatHistory")
        } else {

            var senderNames: [String] = []
            var seenSenders: Set<String> = []

            for message in messages {
            let sender = message.from.userID
                if !seenSenders.contains(sender) {
                    seenSenders.insert(sender)

                    let name = message.from.nickname ?? sender
                    senderNames.append(name)
                }

                if senderNames.count >= mergedTitleMaxSenderCount {
                    break
                }
            }

            if senderNames.count == mergedTitleMaxSenderCount {

                return String(format: LocalizedChatString("RelayChatHistoryForSomebodyFormat"), senderNames[0], senderNames[1])
            } else if senderNames.count == 1 {

                return String(format: LocalizedChatString("RelayC2CChatHistoryFormat"), senderNames[0])
            } else {

                return LocalizedChatString("RelayChatHistory")
            }
        }
    }

    static func generateAbstractList(messages: [MessageInfo]) -> [String] {
        return messages.prefix(mergedAbstractMaxCount).map { message in
            getMessageAbstractForForward(message)
        }
    }

    private static func alignEmojiString(userName: String, text: String) -> String {
        return "\(userName): \(text)"
    }

    private static func displayName(_ member: GroupMember) -> String {
        if let nameCard = member.nameCard, !nameCard.isEmpty {
            return nameCard
        }
        if let remark = member.friendRemark, !remark.isEmpty {
            return remark
        }
        if let nickname = member.nickname, !nickname.isEmpty {
            return nickname
        }
        return member.userID
    }

    static func senderShowName(of message: MessageInfo) -> String {
        let sender = message.from
        if let nameCard = sender.nameCard, !nameCard.isEmpty { return nameCard }
        if let remark = sender.friendRemark, !remark.isEmpty { return remark }
        if let nickname = sender.nickname, !nickname.isEmpty { return nickname }
        return sender.userID
    }
}
