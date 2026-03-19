import AtomicX
import AtomicXCore
import ChatUIKit
import SwiftUI

struct ChatNavPage: View {
    @EnvironmentObject var themeState: ThemeState
    
    // Essential parameters
    let conversation: ConversationInfo
    let locateMessage: MessageInfo?
    let onBack: () -> Void
    let onContactDelete: () -> Void
    let onGroupDelete: () -> Void
    let onNavigateToChat: ((ConversationInfo) -> Void)?
    
    // Internal navigation state
    @State private var showC2CChatSetting: Bool = false
    @State private var showGroupChatSetting: Bool = false
    @State private var currentC2CUserID: String? = nil
    @State private var currentGroupID: String? = nil
    
    init(
        conversation: ConversationInfo,
        locateMessage: MessageInfo? = nil,
        onBack: @escaping () -> Void,
        onContactDelete: @escaping () -> Void,
        onGroupDelete: @escaping () -> Void,
        onNavigateToChat: ((ConversationInfo) -> Void)? = nil
    ) {
        self.conversation = conversation
        self.locateMessage = locateMessage
        self.onBack = onBack
        self.onContactDelete = onContactDelete
        self.onGroupDelete = onGroupDelete
        self.onNavigateToChat = onNavigateToChat
    }
    
    var body: some View {
        ZStack {
            ChatPage(
                conversation: conversation,
                locateMessage: locateMessage,
                onBack: onBack,
                onUserAvatarClick: { userID in
                    handleUserAvatarClick(userID: userID)
                },
                onNavigationAvatarClick: {
                    handleNavigationAvatarClick()
                }
            )
            
            if let userID = currentC2CUserID {
                NavigationLink(
                    destination: NestedC2CSetting(
                        userID: userID,
                        parentConversationID: conversation.conversationID,
                        onBack: {
                            dismissC2CChatSetting()
                        },
                        onContactDelete: {
                            dismissC2CChatSetting()
                            onContactDelete()
                        }
                    )
                    .id(userID)
                    .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissC2CChatSetting()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(themeState.colors.textColorLink)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showC2CChatSetting
                ) {
                    EmptyView()
                }
                .hidden()
            }
            
            if let groupID = currentGroupID {
                NavigationLink(
                    destination: NestedGroupSetting(
                        groupID: groupID,
                        parentConversationID: conversation.conversationID,
                        onBack: {
                            dismissGroupChatSetting()
                        },
                        onGroupDelete: {
                            dismissGroupChatSetting()
                            onGroupDelete()
                        }
                    )
                    .id(groupID)
                    .navigationBarTitle(LocalizedChatString("GroupSettings"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissGroupChatSetting()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(themeState.colors.textColorLink)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showGroupChatSetting
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleUserAvatarClick(userID: String) {
        currentC2CUserID = userID
        showC2CChatSetting = true
    }
    
    private func handleNavigationAvatarClick() {
        if conversation.type == .c2c {
            if let userID = ChatUtil.getUserID(conversation.conversationID) {
                currentC2CUserID = userID
                showC2CChatSetting = true
            }
        } else if conversation.type == .group {
            if let groupID = ChatUtil.getGroupID(conversation.conversationID) {
                currentGroupID = groupID
                showGroupChatSetting = true
            }
        }
    }
    
    private func dismissC2CChatSetting() {
        showC2CChatSetting = false
        currentC2CUserID = nil
    }
    
    private func dismissGroupChatSetting() {
        showGroupChatSetting = false
        currentGroupID = nil
    }
}

// MARK: - NestedC2CSetting
// A wrapper that handles nested navigation from C2CChatSetting to a new chat page.
// Note: This struct creates its own C2CSettingStore instance, separate from the one inside C2CChatSetting.
// This is intentional because we need to access user info (nickname, remark, avatarURL) for creating
// the nested conversation before navigating. The two store instances will fetch the same data independently.

private struct NestedC2CSetting: View {
    @EnvironmentObject var themeState: ThemeState
    
    let userID: String
    let parentConversationID: String
    let onBack: () -> Void
    let onContactDelete: () -> Void
    
    @State private var showNestedChat: Bool = false
    @State private var nestedConversation: ConversationInfo? = nil
    
    // User info from C2CSettingStore (updated via onReceive)
    @State private var userRemark: String = ""
    @State private var userNickname: String = ""
    @State private var userAvatarURL: String = ""
    @State private var settingStore: C2CSettingStore
    
    init(
        userID: String,
        parentConversationID: String,
        onBack: @escaping () -> Void,
        onContactDelete: @escaping () -> Void
    ) {
        self.userID = userID
        self.parentConversationID = parentConversationID
        self.onBack = onBack
        self.onContactDelete = onContactDelete
        self._settingStore = State(initialValue: C2CSettingStore.create(userID: userID))
    }
    
    private var displayName: String {
        if !userRemark.isEmpty {
            return userRemark
        } else if !userNickname.isEmpty {
            return userNickname
        } else {
            return userID
        }
    }
    
    var body: some View {
        ZStack {
            C2CChatSetting(
                userID: userID,
                onSendMessageClick: {
                    handleSendMessageClick()
                },
                onContactDelete: onContactDelete
            )
            
            if let conversation = nestedConversation {
                NavigationLink(
                    destination: NestedChat(
                        conversation: conversation,
                        userID: userID,
                        onBack: {
                            dismissNestedChat()
                        }
                    )
                    .navigationBarHidden(true),
                    isActive: $showNestedChat
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.remark))) { remark in
            self.userRemark = remark
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.nickname))) { nickname in
            self.userNickname = nickname
        }
        .onReceive(settingStore.state.subscribe(StatePublisherSelector(keyPath: \C2CSettingState.avatarURL))) { avatarURL in
            self.userAvatarURL = avatarURL
        }
        .onAppear {
            // Fetch user info to ensure displayName is available
            settingStore.fetchUserInfo(completion: nil)
        }
    }
    
    private func handleSendMessageClick() {
        let targetConversationID = ChatUtil.getC2CConversationID(userID)
        
        // If already in this user's C2C chat, just go back
        if parentConversationID == targetConversationID {
            onBack()
            return
        }
        
        var conversation = ConversationInfo(conversationID: targetConversationID)
        conversation.type = .c2c
        conversation.title = displayName
        conversation.avatarURL = userAvatarURL
        
        nestedConversation = conversation
        showNestedChat = true
    }
    
    private func dismissNestedChat() {
        showNestedChat = false
    }
}

// MARK: - NestedChat
// A chat page for nested navigation that supports avatar click to C2CChatSetting.
// This is the deepest level of nesting - clicking avatar here opens C2CChatSetting directly
// without further nesting capability to prevent infinite navigation depth.

private struct NestedChat: View {
    @EnvironmentObject var themeState: ThemeState
    
    let conversation: ConversationInfo
    let userID: String
    let onBack: () -> Void
    
    @State private var showC2CChatSetting: Bool = false
    
    var body: some View {
        ZStack {
            ChatPage(
                conversation: conversation,
                locateMessage: nil,
                onBack: onBack,
                onUserAvatarClick: { _ in
                    // In nested C2C chat, clicking avatar opens the same user's setting
                    showC2CChatSetting = true
                },
                onNavigationAvatarClick: {
                    showC2CChatSetting = true
                }
            )
            
            NavigationLink(
                destination: C2CChatSetting(
                    userID: userID,
                    onSendMessageClick: {
                        // Already in this user's chat, just dismiss settings
                        showC2CChatSetting = false
                    },
                    onContactDelete: {
                        showC2CChatSetting = false
                        onBack()
                    }
                )
                .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button(action: {
                        showC2CChatSetting = false
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(themeState.colors.textColorLink)
                    }
                )
                .navigationBarBackButtonHidden(true),
                isActive: $showC2CChatSetting
            ) {
                EmptyView()
            }
            .hidden()
        }
    }
}

// MARK: - NestedGroupSetting
// A wrapper that handles nested navigation from GroupChatSetting to C2CChatSetting and chat pages.
// When a group member is clicked, it navigates to NestedC2CSetting for that member.

private struct NestedGroupSetting: View {
    @EnvironmentObject var themeState: ThemeState
    
    let groupID: String
    let parentConversationID: String
    let onBack: () -> Void
    let onGroupDelete: () -> Void
    
    // Navigation state for member C2CChatSetting
    @State private var showMemberSetting: Bool = false
    @State private var selectedMemberUserID: String? = nil
    
    var body: some View {
        ZStack {
            GroupChatSetting(
                groupID: groupID,
                onSendMessageClick: {
                    // Already in group chat, just go back
                    onBack()
                },
                onGroupDelete: onGroupDelete,
                onGroupMemberClick: { userID in
                    selectedMemberUserID = userID
                    showMemberSetting = true
                }
            )
            
            if let userID = selectedMemberUserID {
                NavigationLink(
                    destination: NestedC2CSetting(
                        userID: userID,
                        parentConversationID: parentConversationID,
                        onBack: {
                            dismissMemberSetting()
                        },
                        onContactDelete: {
                            dismissMemberSetting()
                        }
                    )
                    .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            dismissMemberSetting()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(themeState.colors.textColorLink)
                        }
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showMemberSetting
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }
    
    private func dismissMemberSetting() {
        showMemberSetting = false
        selectedMemberUserID = nil
    }
}
