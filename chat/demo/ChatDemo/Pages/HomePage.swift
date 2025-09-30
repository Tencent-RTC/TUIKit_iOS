import AtomicX
import ChatUIKit
import AtomicXCore
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
    @State private var showGroupChatSetting: Bool = false
    @State private var showContactDetail: Bool = false
    @State private var showAddFriend: Bool = false
    @State private var showGroupList: Bool = false
    @State private var showBlackList: Bool = false
    @State private var showNewFriends: Bool = false
    @State private var showGroupApplications: Bool = false

    @State private var currentConversation: ConversationInfo? = nil
    @State private var currentLocateMessage: MessageInfo? = nil
    @State private var currentC2CUserID: String? = nil
    @State private var currentC2CNeedNavigateToChat: Bool = false
    @State private var currentGroupID: String? = nil
    @State private var currentGroupNeedNavigateToChat: Bool = false
    @State private var currentContactUser: AZOrderedListItem? = nil

    public init() {
        self.conversationListStore = ConversationListStore.create()
        self.contactListStore = ContactListStore.create()
    }

    public var body: some View {
        if #available(iOS 15.0, *) {
            let _ = Self._printChanges()
        }

        ZStack {
            TabView(selection: self.$selectedTab) {
                ConversationsPage(
                    onShowMessage: { navigationInfo in
                        showChatPage(conversation: navigationInfo.conversation, locateMessage: navigationInfo.locateMessage)
                    }
                )
                .navigationTitle("")
                .navigationBarHidden(true)
                .tabItem {
                    Label(LocalizedChatString("TabChats"), image:"tab_chat")
                }
                .tag(Tab.chats)
                .modifier(TabBadgeModifier(count: totalUnreadCount))
                

                ContactsPage(
                    onShowMessage: { conversation in
                        showChatPage(conversation: conversation)
                    },
                    onContactClick: { user in
                        showContactDetail(user)
                    },
                    onGroupClick: { group in
                        let conversation = createConversationFromGroup(group)
                        showChatPage(conversation: conversation)
                    },
                    onNewFriendsClick: {
                        showNewFriendsPage()
                    },
                    onGroupApplicationsClick: {
                        showGroupApplicationsPage()
                    },
                    onGroupListClick: {
                        showGroupListPage()
                    },
                    onBlackListClick: {
                        showBlackListPage()
                    }
                )
                .tabItem {
                    Label(LocalizedChatString("TabContacts"),  image:"tab_contact")
                }
                .tag(Tab.contacts)
                .navigationTitle("")
                .navigationBarHidden(true)

                SettingsPage()
                    .tabItem {
                        Label(LocalizedChatString("TabSettings"), image:"tab_setting")
                    }
                    .tag(Tab.settings)
                    .navigationTitle("")
                    .navigationBarHidden(true)

            }
            .onAppear() {
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = UIColor.clear
                UITabBar.appearance().isTranslucent = false
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                } else {
                    // Fallback on earlier versions
                }
            }
            .navigationBarHidden(true)
            .navigationTitle("")

            ZStack {
                if let conversation = currentConversation {
                    NavigationLink(
                        destination: ChatPageWithNavigation(
                            conversation: conversation,
                            locateMessage: currentLocateMessage,
                            onBack: {
                                dismissChatPage()
                            },
                            onUserAvatarClick: { userID in
                                showC2CChatSettingPage(userID: userID)
                            },
                            onNavigationAvatarClick: {
                                if conversation.type == .c2c {
                                    if let userID = ChatUtil.getUserID(conversation.conversationID) {
                                        showC2CChatSettingPage(userID: userID, needNavigateToChat: false)
                                    }
                                } else if conversation.type == .group {
                                    if let groupID = ChatUtil.getGroupID(conversation.conversationID) {
                                        showGroupChatSettingPage(groupID: groupID, needNavigateToChat: false)
                                    }
                                }
                            },
                            currentC2CUserID: currentC2CUserID,
                            currentGroupID: currentGroupID,
                            showC2CChatSetting: $showC2CChatSetting,
                            showGroupChatSetting: $showGroupChatSetting,
                            currentC2CNeedNavigateToChat: currentC2CNeedNavigateToChat,
                            currentGroupNeedNavigateToChat: currentGroupNeedNavigateToChat,
                            onC2CChatSettingDismiss: {
                                dismissC2CChatSetting()
                            },
                            onGroupChatSettingDismiss: {
                                dismissGroupChatSetting()
                            },
                            onC2CChatSettingSendMessage: { userID in
                                if currentC2CNeedNavigateToChat {
                                    let newConversation = createConversationFromUserID(userID)
                                    dismissC2CChatSetting()
                                    showChatPage(conversation: newConversation)
                                } else {
                                    dismissC2CChatSetting()
                                }
                            },
                            onGroupChatSettingSendMessage: { groupID in
                                if currentGroupNeedNavigateToChat {
                                    let newConversation = createConversationFromGroupID(groupID)
                                    dismissGroupChatSetting()
                                    showChatPage(conversation: newConversation)
                                } else {
                                    dismissGroupChatSetting()
                                }
                            },
                            onPopToRoot: {
                                dismissAllPages()
                                selectedTab = .chats
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
                            showsOwnNavigation: false,
                            onSendMessageClick: {
                                let newConversation = createConversationFromUser(contactUser)
                                dismissContactDetail()
                                showChatPage(conversation: newConversation)
                            }
                        )
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline),
                        isActive: $showContactDetail
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                if let userID = currentC2CUserID {
                    NavigationLink(
                        destination: AddFriendPage(
                            userID: userID,
                            showsOwnNavigation: false,
                            onSendMessageClick: {
                                if currentC2CNeedNavigateToChat {
                                    let newConversation = createConversationFromUserID(userID)
                                    dismissAddFriend()
                                    showChatPage(conversation: newConversation)
                                } else {
                                    dismissAddFriend()
                                }
                            },
                            onAddFriendSuccess: {
                                dismissAddFriend()
                                // Optionally show success message or refresh friend list
                            }
                        )
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline),
                        isActive: $showAddFriend
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                NavigationLink(
                    destination: GroupListView(
                        contactStore: ContactListStore.create(),
                        onShowMessage: { conversation in
                            dismissGroupList()
                            showChatPage(conversation: conversation)
                        },
                        showsNavigationTitle: true
                    )
                    .navigationBarTitle(LocalizedChatString("TabContacts"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissGroupList()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showGroupList
                ) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(
                    destination: BlackListView(
                        contactStore: ContactListStore.create(),
                        onShowProfile: { userItem in
                            let contact = ContactInfo(
                                identifier: userItem.userID,
                                avatarURL: userItem.avatarURL,
                                title: userItem.title
                            )
                            dismissBlackList()
                            showContactDetail(AZOrderedListItem(
                                userID: userItem.userID,
                                avatarURL: userItem.avatarURL,
                                title: userItem.title
                            ))
                        },
                        showsNavigationTitle: true
                    )
                    .navigationBarTitle(LocalizedChatString("TabContacts"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissBlackList()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showBlackList
                ) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(
                    destination: FriendApplicationListView(
                        contactStore: ContactListStore.create()
                    )
                    .navigationTitle(LocalizedChatString("ContactsNewFriends"))
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissNewFriends()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showNewFriends
                ) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(
                    destination: GroupApplicationListView(
                        contactStore: ContactListStore.create()
                    )
                    .navigationTitle(LocalizedChatString("ContactsGroupApplications"))
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissGroupApplications()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showGroupApplications
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accentColor(themeState.colors.buttonColorPrimaryDefault)
        .toast(homeToast)
        .id("HomePage-\(languageState.currentLanguage)")
        .onReceive(conversationListStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))) { unreadCount in
            self.totalUnreadCount = unreadCount
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

    private func showC2CChatSettingPage(userID: String, needNavigateToChat: Bool = false) {
        currentC2CUserID = userID
        currentC2CNeedNavigateToChat = needNavigateToChat
        
        // Check if user is friend before showing chat setting
        HomePage.checkIsFriend(userID: userID) { isFriend in
            DispatchQueue.main.async {
                if isFriend {
                    self.showC2CChatSetting = true
                } else {
                    self.showAddFriend = true
                }
            }
        }
    }

    private func showGroupChatSettingPage(groupID: String, needNavigateToChat: Bool = false) {
        currentGroupID = groupID
        currentGroupNeedNavigateToChat = needNavigateToChat
        showGroupChatSetting = true
    }

    private func showContactDetail(_ user: AZOrderedListItem) {
        currentContactUser = user
        showContactDetail = true
    }

    private func showGroupListPage() {
        showGroupList = true
    }

    private func showBlackListPage() {
        showBlackList = true
    }

    private func showNewFriendsPage() {
        showNewFriends = true
    }

    private func showGroupApplicationsPage() {
        showGroupApplications = true
    }

    private func dismissChatPage() {
        showChatPage = false
    }

    private func dismissC2CChatSetting() {
        showC2CChatSetting = false
    }

    private func dismissGroupChatSetting() {
        showGroupChatSetting = false
    }

    private func dismissGroupList() {
        showGroupList = false
    }

    private func dismissBlackList() {
        showBlackList = false
    }

    private func dismissNewFriends() {
        showNewFriends = false
    }

    private func dismissGroupApplications() {
        showGroupApplications = false
    }

    private func dismissContactDetail() {
        showContactDetail = false
    }
    
    private func dismissAddFriend() {
        showAddFriend = false
    }
    
    private func dismissAllPages() {
        showChatPage = false
        showC2CChatSetting = false
        showGroupChatSetting = false
        showContactDetail = false
        showAddFriend = false
        showGroupList = false
        showBlackList = false
        showNewFriends = false
        showGroupApplications = false
        
        currentConversation = nil
        currentLocateMessage = nil
        currentC2CUserID = nil
        currentGroupID = nil
        currentContactUser = nil
        currentC2CNeedNavigateToChat = false
        currentGroupNeedNavigateToChat = false
    }

    private func createConversationFromUserID(_ userID: String) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(userID))
        conversation.type = .c2c
        conversation.title = userID
        return conversation
    }

    private func createConversationFromGroupID(_ groupID: String) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(groupID))
        conversation.type = .group
        conversation.title = groupID
        return conversation
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
        if #available(iOS 15.0, *) {
            let badgeValue = count > 0 ? (count > 99 ? "99+" : "\(count)") : nil
            return content.badge(badgeValue)
        } else {
            return content
        }
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
