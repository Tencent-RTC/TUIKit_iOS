import TUIChatKit
import AtomicXCore
import UIKit

internal final class ChatFlowCoordinator {
    internal weak var navigationController: UINavigationController?

    internal init() {}

    internal func pushChat(_ conversation: ConversationInfo, locateMessage: MessageInfo? = nil, animated: Bool = true) {
        guard conversation.type == .c2c else {
            showChat(conversation, locateMessage: locateMessage, animated: animated)
            return
        }
        guard let userID = c2cUserID(conversation.conversationID) else { return }
        if canChatWithoutFriendship(userID) {
            showChat(conversation, locateMessage: locateMessage, animated: animated)
            return
        }
        guard let source = navigationController?.topViewController else { return }
        UserProfileRouter.openChat(userID: userID, from: source, animated: animated) { [weak self] contact in
            guard ChatUtil.getC2CConversationID(contact.userID) == conversation.conversationID else { return }
            self?.showChat(conversation, locateMessage: locateMessage, animated: animated)
        }
    }

    private func canChatWithoutFriendship(_ userID: String) -> Bool {
        return userID.hasPrefix("@RBT") || userID == "administrator"
    }

    private func c2cUserID(_ conversationID: String) -> String? {
        let prefix = "c2c_"
        guard conversationID.hasPrefix(prefix) else { return nil }
        let userID = String(conversationID.dropFirst(prefix.count))
        return userID.isEmpty ? nil : userID
    }

    private func showChat(_ conversation: ConversationInfo, locateMessage: MessageInfo? = nil, animated: Bool = true) {
        let page = makeChatPage(conversation: conversation, locateMessage: locateMessage)
        pushPage(page, animated: animated)
    }

    private func makeChatPage(conversation: ConversationInfo, locateMessage: MessageInfo?) -> ChatPage {
        let page = ChatPage(
            conversation: conversation,
            locateMessage: locateMessage,
            messageListConfig: DemoPageConfigs.makeMessageListConfig(),
            messageInputConfig: DemoPageConfigs.makeMessageInputConfig(conversationID: conversation.conversationID),
            isShowMoreButton: true,
            onBack: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            onUserClick: { [weak self] userID in
                self?.openUserProfile(userID: userID, parentConversationID: conversation.conversationID)
            },
            onMoreClick: { [weak self] in
                self?.openConversationSettings(for: conversation)
            }
        )
        attachSecurityWarning(to: page)
        return page
    }

    private func attachSecurityWarning(to page: ChatPage) {
        let warningView = ChatSecurityWarningView()
        warningView.onClose = { [weak page] in
            page?.topBannerView = nil
        }
        page.topBannerView = warningView
    }

    private func openConversationSettings(for conversation: ConversationInfo) {
        if conversation.type == .c2c, let userID = c2cUserID(conversation.conversationID) {
            openUserProfile(userID: userID, parentConversationID: conversation.conversationID)
        } else if conversation.type == .group, let groupID = ChatUtil.getGroupID(conversation.conversationID) {
            pushGroupSettings(groupID: groupID, parentConversationID: conversation.conversationID)
        }
    }

    private func pushGroupSettings(groupID: String, parentConversationID: String?) {
        let page = GroupChatSettingViewController(
            groupID: groupID,
            config: DemoPageConfigs.makeGroupSettingsConfig(),
            onSendMessageClick: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            onGroupDelete: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            },
            onGroupMemberClick: { [weak self] userID in
                self?.openUserProfile(userID: userID, parentConversationID: parentConversationID)
            }
        )
        pushPage(page)
    }

    private func openContactChat(userID: String, parentConversationID: String?) {
        if canChatWithoutFriendship(userID) {
            showContactChat(userID: userID, contact: nil, parentConversationID: parentConversationID)
            return
        }
        guard let source = navigationController?.topViewController else { return }
        UserProfileRouter.openChat(userID: userID, from: source) { [weak self] contact in
            self?.showContactChat(userID: userID, contact: contact, parentConversationID: parentConversationID)
        }
    }

    private func showContactChat(userID: String, contact: ContactInfo?, parentConversationID: String?) {
        let conversationID = ChatUtil.getC2CConversationID(userID)
        if parentConversationID == conversationID {
            navigationController?.popViewController(animated: true)
            return
        }
        var conversation = ConversationInfo(conversationID: conversationID)
        conversation.type = .c2c
        conversation.title = contactDisplayName(contact) ?? userID
        conversation.avatarURL = contact?.avatarURL
        showChat(conversation)
    }

    private func contactDisplayName(_ contact: ContactInfo?) -> String? {
        guard let contact else { return nil }
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return nil
    }

    private func openUserProfile(userID: String, parentConversationID: String?) {
        guard let source = navigationController?.topViewController else { return }
        UserProfileRouter.open(
            userID: userID,
            from: source,
            onSendMessageClick: { [weak self] in
                self?.openContactChat(userID: userID, parentConversationID: parentConversationID)
            },
            onContactDelete: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            }
        )
    }

    private func pushPage(_ page: UIViewController, animated: Bool = true) {
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: animated)
    }
}
