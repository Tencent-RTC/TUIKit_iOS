import AtomicX
import AtomicXCore
import ChatUIKit
import SwiftUI

public struct HomePage: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var appStyleSettings: AppStyleSettings
    @EnvironmentObject var languageState: LanguageState
    @StateObject private var homeToast = Toast()
    @State private var selectedTab: Tab = .chats
    private var conversationListStore: ConversationListStore
    private var contactListStore: ContactListStore
    @State private var totalUnreadCount: UInt = 0

    @State private var showChatPage: Bool = false
    @State private var showC2CChatSetting: Bool = false

    @State private var currentConversation: ConversationInfo? = nil
    @State private var currentLocateMessage: MessageInfo? = nil
    @State private var currentContactUser: AZOrderedListItem? = nil

    public init() {
        self.conversationListStore = ConversationListStore.create()
        self.contactListStore = ContactListStore.create()
    }

    public var body: some View {
        ZStack {
            TabView(selection: self.$selectedTab) {
                ConversationsPage(
                    onConversationClick: { navigationInfo in
                        showChatPage(conversation: navigationInfo.conversation, locateMessage: navigationInfo.locateMessage)
                    }
                )
                .navigationTitle("")
                .navigationBarHidden(true)
                .tabItem {
                    Label(LocalizedChatString("TabChats"), image: "tab_chat")
                }
                .tag(Tab.chats)
                .modifier(TabBadgeModifier(count: totalUnreadCount))

                ContactsPage(
                    onContactClick: { user in
                        showC2CChatSetting(user)
                    },
                    onGroupClick: { group in
                        let conversation = createConversationFromGroup(group)
                        showChatPage(conversation: conversation)
                    }
                )
                .tabItem {
                    Label(LocalizedChatString("TabContacts"), image: "tab_contact")
                }
                .tag(Tab.contacts)
                .navigationTitle("")
                .navigationBarHidden(true)

                SettingsPage()
                    .tabItem {
                        Label(LocalizedChatString("TabSettings"), image: "tab_setting")
                    }
                    .tag(Tab.settings)
                    .navigationTitle("")
                    .navigationBarHidden(true)
            }
            .id("TabView-\(themeState.currentTheme.mode)")
            .background(themeState.colors.bgColorOperate)
            .onAppear {
                updateTabBarAppearance()
            }
            .onChange(of: themeState.currentTheme.mode) { _ in
                updateTabBarAppearance()
            }
            .navigationBarHidden(true)
            .navigationTitle("")

            ZStack {
                if let conversation = currentConversation {
                    NavigationLink(
                        destination: ChatNavPage(
                            conversation: conversation,
                            locateMessage: currentLocateMessage,
                            onBack: {
                                dismissChatPage()
                            },
                            onContactDelete: {
                                dismissChatPage()
                            },
                            onGroupDelete: {
                                dismissChatPage()
                            },
                            onNavigateToChat: { newConversation in
                                // First dismiss current chat page, then navigate to the new chat
                                dismissChatPage()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showChatPage(conversation: newConversation)
                                }
                            }
                        )
                        .navigationBarHidden(true),
                        isActive: $showChatPage
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                if let contactUser = currentContactUser {
                    NavigationLink(
                        destination: C2CChatSetting(
                            userID: contactUser.userID,
                            onSendMessageClick: {
                                let newConversation = createConversationFromUser(contactUser)
                                dismissContactDetail()
                                showChatPage(conversation: newConversation)
                            }
                        )
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline),
                        isActive: $showC2CChatSetting
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accentColor(themeState.colors.buttonColorPrimaryDefault)
        .toast(homeToast)
        .id("HomePage-\(languageState.currentLanguage)")
        .onReceive(conversationListStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))) { unreadCount in
            self.totalUnreadCount = UInt(unreadCount)
        }
        .onAppear {
            // Initialize with current value
            conversationListStore.getConversationTotalUnreadCount(completion: nil)
        }
    }

    private func showChatPage(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        currentConversation = conversation
        currentLocateMessage = locateMessage
        showChatPage = true
    }

    private func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(themeState.colors.bgColorOperate)
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func showC2CChatSetting(_ user: AZOrderedListItem) {
        currentContactUser = user
        showC2CChatSetting = true
    }

    private func dismissChatPage() {
        showChatPage = false
    }

    private func dismissContactDetail() {
        showC2CChatSetting = false
    }

    private func createConversationFromUser(_ user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.id))
        conversation.avatarURL = user.avatarURL
        conversation.type = .c2c
        conversation.title = user.title ?? user.id
        return conversation
    }

    private func createConversationFromGroup(_ group: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.id))
        conversation.avatarURL = group.avatarURL
        conversation.type = .group
        conversation.title = group.title ?? group.id
        return conversation
    }
}

enum Tab {
    case chats, contacts, settings
}

struct TabBadgeModifier: ViewModifier {
    let count: UInt
    func body(content: Content) -> some View {
        let badgeValue = count > 0 ? (count > 99 ? "99+" : "\(count)") : nil
        return content.badge(badgeValue)
    }
}

// MARK: - FriendshipHelper

extension HomePage {
    static func checkIsFriend(userID: String, completion: @escaping (Bool) -> Void) {
        let contactStore = ContactListStore.create()

        contactStore.fetchUserInfo(userID: userID, completion: { result in
            switch result {
            case .success:
                // Check the result in the store's state
                let contactInfo = contactStore.state.value.addFriendInfo
                let isFriend = contactInfo?.isContact ?? false
                completion(isFriend)
            case .failure:
                // If failed to get user info, assume not a friend
                completion(false)
            }
        })
    }
}
