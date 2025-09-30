import AtomicX
import ChatUIKit
import AtomicXCore
import SwiftUI

struct ChatPageWithNavigation: View {
    let conversation: ConversationInfo
    let locateMessage: MessageInfo?
    let onBack: () -> Void
    let onUserAvatarClick: (String) -> Void
    let onNavigationAvatarClick: () -> Void
    
    let currentC2CUserID: String?
    let currentGroupID: String?
    @Binding var showC2CChatSetting: Bool
    @Binding var showGroupChatSetting: Bool
    let currentC2CNeedNavigateToChat: Bool
    let currentGroupNeedNavigateToChat: Bool
    
    let onC2CChatSettingDismiss: () -> Void
    let onGroupChatSettingDismiss: () -> Void
    let onC2CChatSettingSendMessage: (String) -> Void
    let onGroupChatSettingSendMessage: (String) -> Void
    let onPopToRoot: (() -> Void)?
    
    var body: some View {
        ZStack {
            ChatPage(
                conversation: conversation,
                locateMessage: locateMessage,
                onBack: onBack,
                onUserAvatarClick: onUserAvatarClick,
                onNavigationAvatarClick: onNavigationAvatarClick
            )
            
            if let userID = currentC2CUserID {
                NavigationLink(
                    destination: C2CChatSetting(
                        userID: userID,
                        showsOwnNavigation: false,
                        onSendMessageClick: {
                            onC2CChatSettingSendMessage(userID)
                        }
                    )
                    .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            onC2CChatSettingDismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
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
                    destination: GroupChatSetting(
                        groupID: groupID,
                        showsOwnNavigation: false,
                        onSendMessageClick: {
                            onGroupChatSettingSendMessage(groupID)
                        },
                        onPopToRoot: onPopToRoot
                    )
                    .navigationBarTitle(LocalizedChatString("GroupSettings"), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            onGroupChatSettingDismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
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
}
