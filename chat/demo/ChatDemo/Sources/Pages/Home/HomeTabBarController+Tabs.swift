import AtomicXCore
import TUIChatKit
import TUICallKit_Swift
import UIKit

extension HomeTabBarController {
    internal static var tabIconBaseNames: [String] {
        var names: [String] = []
        if isAITabVisible {
            names.append("tab_ai")
        }
        names.append("tab_chat")
        if isCallsTabVisible {
            names.append("tab_calls")
        }
        names.append(contentsOf: ["tab_contact", "tab_setting"])
        return names
    }

    internal func rebuildTabs() {
        var tabs: [UIViewController] = []
        if Self.isAITabVisible {
            tabs.append(makeAssistantTab())
        }
        tabs.append(makeConversationsTab())
        if Self.isCallsTabVisible {
            tabs.append(makeCallsTab())
        }
        tabs.append(contentsOf: [makeContactsTab(), makeSettingsTab()])
        viewControllers = tabs
    }

    private func makeAssistantTab() -> UIViewController {
        let page = AIAssistantPageViewController(config: DemoPageConfigs.makeAssistantConfig())
        page.setup(agentLoader: DemoAIAssistantAgentLoader.shared)
        page.tabBarItem = UITabBarItem(
            title: LocalizedChatString("DemoTabAI"),
            image: nil,
            tag: 0
        )
        return page
    }

    private func makeCallsTab() -> UIViewController {
        let page = RecentCallsViewController(recordCallsUIStyle: .minimalist)
        page.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabCalls"),
            image: UIImage(named: "tab_calls"),
            tag: 1
        )
        return page
    }

    private func makeConversationsTab() -> UIViewController {
        let coordinator = ChatFlowCoordinator()
        weak var chatNavigationController: HiddenBarNavigationController?
        let page = ConversationsPage(
            config: DemoPageConfigs.makeConversationsConfig(),
            onConversationClick: { [weak coordinator] info in
                if info.conversation.conversationID == CustomerServiceManager.customerServiceConversationID,
                   let source = chatNavigationController?.topViewController {
                    CustomerServiceManager.openCustomerServiceChat(from: source)
                    return
                }
                coordinator?.pushChat(info.conversation, locateMessage: info.locateMessage)
            }
        )
        let navigationController = HiddenBarNavigationController(rootViewController: page)
        chatNavigationController = navigationController
        coordinator.navigationController = navigationController
        navigationController.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabChats"),
            image: UIImage(named: "tab_chat"),
            tag: 0
        )
        chatsCoordinator = coordinator
        chatsNavigationController = navigationController
        return navigationController
    }

    private func makeContactsTab() -> UIViewController {
        let coordinator = ChatFlowCoordinator()
        let page = ContactsPage(
            config: DemoPageConfigs.makeContactsConfig(),
            onContactClick: { [weak coordinator] contact in
                coordinator?.pushChat(Self.makeContactConversation(from: contact))
            },
            onGroupClick: { [weak coordinator] group in
                coordinator?.pushChat(Self.makeGroupConversation(from: group))
            }
        )
        let navigationController = HiddenBarNavigationController(rootViewController: page)
        coordinator.navigationController = navigationController
        navigationController.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabContacts"),
            image: UIImage(named: "tab_contact"),
            tag: 1
        )
        contactsCoordinator = coordinator
        contactsNavigationController = navigationController
        return navigationController
    }

    private func makeSettingsTab() -> UIViewController {
        let page = SettingsViewController()
        let navigationController = HiddenBarNavigationController(rootViewController: page)
        navigationController.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabSettings"),
            image: UIImage(named: "tab_setting"),
            tag: 2
        )
        return navigationController
    }

    private static func makeGroupConversation(from group: GroupInfo) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.groupID))
        conversation.type = .group
        conversation.title = group.groupName ?? group.groupID
        conversation.avatarURL = group.avatarURL
        return conversation
    }

    private static func makeContactConversation(from contact: ContactInfo) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(contact.userID))
        conversation.type = .c2c
        conversation.title = contact.friendRemark ?? contact.nickname ?? contact.userID
        conversation.avatarURL = contact.avatarURL
        return conversation
    }
}
