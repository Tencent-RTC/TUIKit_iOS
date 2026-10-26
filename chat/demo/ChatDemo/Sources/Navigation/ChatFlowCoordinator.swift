import TUIChatKit
import AtomicXCore
import UIKit

internal final class ChatFlowCoordinator {
    internal weak var navigationController: UINavigationController?

    internal init() {}

    internal func pushChat(_ conversation: ConversationInfo, locateMessage: MessageInfo? = nil, animated: Bool = true) {
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
                self?.pushContactSettings(userID: userID, parentConversationID: conversation.conversationID)
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
        if conversation.type == .c2c, let userID = ChatUtil.getUserID(conversation.conversationID) {
            pushContactSettings(userID: userID, parentConversationID: conversation.conversationID)
        } else if conversation.type == .group, let groupID = ChatUtil.getGroupID(conversation.conversationID) {
            pushGroupSettings(groupID: groupID, parentConversationID: conversation.conversationID)
        }
    }

    private func pushContactSettings(userID: String, parentConversationID: String?) {
        let page = C2CChatSettingViewController(
            userID: userID,
            config: DemoPageConfigs.makeContactSettingsConfig(),
            onSendMessageClick: { [weak self] in
                self?.openContactChat(userID: userID, parentConversationID: parentConversationID)
            },
            onContactDelete: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            }
        )
        pushPage(page)
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
                self?.openMemberProfile(userID: userID, parentConversationID: parentConversationID)
            }
        )
        pushPage(page)
    }

    private func openContactChat(userID: String, parentConversationID: String?) {
        let conversationID = ChatUtil.getC2CConversationID(userID)
        if parentConversationID == conversationID {
            navigationController?.popViewController(animated: true)
            return
        }
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: ContactChatLookupHandler(
                onSuccess: { [weak self] contacts in
                    DispatchQueue.main.async {
                        self?.pushContactChat(userID: userID, contact: contacts.first)
                    }
                },
                onFailure: { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.pushContactChat(userID: userID, contact: nil)
                    }
                }
            )
        )
    }

    private func pushContactChat(userID: String, contact: ContactInfo?) {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(userID))
        conversation.type = .c2c
        conversation.title = contactDisplayName(contact) ?? userID
        conversation.avatarURL = contact?.avatarURL
        pushChat(conversation)
    }

    private func contactDisplayName(_ contact: ContactInfo?) -> String? {
        guard let contact else { return nil }
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return nil
    }

    private func openMemberProfile(userID: String, parentConversationID: String?) {
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

private final class ContactChatLookupHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        onSuccessBlock = onSuccess
        onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
