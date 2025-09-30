import AtomicX
import AtomicXCore
import SwiftUI

public struct NavigationInfo {
    public let conversation: ConversationInfo
    public let locateMessage: MessageInfo?

    public init(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        self.conversation = conversation
        self.locateMessage = locateMessage
    }
}

class SelectedUsersContainer: ObservableObject {
    @Published var users: [UserPickerItem] = []
}

public struct ConversationsPage: View {
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var selectedUsersContainer = SelectedUsersContainer()
    @State private var showUserPicker = false
    @State private var showConfigSheet = false
    @State private var showStartConversation = false
    @State private var showCreateGroup = false
    @State private var showChatsMenu = false
    @State var friendList: [ContactInfo] = []

    var onShowMessage: ((NavigationInfo) -> Void)?
    private var contactListStore: ContactListStore

    public init(onShowMessage: ((NavigationInfo) -> Void)? = nil) {
        self.contactListStore = ContactListStore.create()
        self.onShowMessage = onShowMessage
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            ConversationList(
                onConversationClick: { conversation in
                    onShowMessage?(NavigationInfo(conversation: conversation))
                }
            )
            .environmentObject(themeState)
        }
        .onReceive(contactListStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendList))) { friendList in
            if self.friendList != friendList {
                self.friendList = friendList
            }
        }
        .onAppear {
            contactListStore.fetchFriendList(completion: { _ in })
        }
        .overlay(
            ChatsMenuOverlay(
                showChatsMenu: $showChatsMenu,
                showStartConversation: $showStartConversation,
                showUserPicker: $showUserPicker
            )
        )
        .sheet(isPresented: $showStartConversation) {
            StartConversationSheet(
                contactListStore: contactListStore,
                onUserSelected: { user in
                    showStartConversation = false
                    let conversation = createConversationFromUser(user)
                    onShowMessage?(NavigationInfo(conversation: conversation))
                }
            )
        }
        .sheet(isPresented: $showUserPicker, onDismiss: {
            if selectedUsersContainer.users.isEmpty {}
        }) {
            UserPickerSheet(
                contactListStore: contactListStore,
                selectedUsersContainer: selectedUsersContainer,
                showUserPicker: $showUserPicker,
                showConfigSheet: $showConfigSheet
            )
        }
        .sheet(isPresented: $showConfigSheet, onDismiss: {
            selectedUsersContainer.users = []
        }) {
            ConfigGroupInfoView(
                members: selectedUsersContainer.users,
                contactListStore: contactListStore,
                onComplete: { createdGroupID, groupName, conversationId in
                    showConfigSheet = false
                    if let groupID = createdGroupID, 
                       let name = groupName,
                       let convId = conversationId {
                        let conversation = createConversationFromGroupInfo(
                            groupID: groupID,
                            groupName: name,
                            conversationId: convId
                        )
                        onShowMessage?(NavigationInfo(conversation: conversation))
                    }
                },
                onBack: {
                    showConfigSheet = false
                }
            )
        }
    }

    private var headerView: some View {
        HStack {
            Text(LocalizedChatString("TabChats"))
                .font(.system(size: 34, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(themeState.colors.textColorPrimary)
                .background(themeState.colors.listColorDefault)
                .padding(.leading, 16)
            Spacer()
            if AppBuilderConfig.shared.enableCreateConversation {
                Button(action: {
                    showChatsMenu.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                        .frame(width: 28, height: 28)
                        .cornerRadius(14)
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Helper Methods

    private func createConversationFromUser(_ user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.id))
        conversation.avatarURL = user.avatarURL
        conversation.type = .c2c
        conversation.title = user.title ?? user.id
        return conversation
    }

    private func createConversationFromGroup(_ groupInfo: Any) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(UUID().uuidString))
        conversation.type = .group
        conversation.title = "New Group"
        return conversation
    }

    private func createConversationFromGroupMembers(members: [UserPickerItem], groupName: String) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(UUID().uuidString))
        conversation.type = .group
        conversation.title = groupName
        conversation.avatarURL = nil
        return conversation
    }
    private func createConversationFromGroupInfo(groupID: String, groupName: String, conversationId: String) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: conversationId)
        conversation.type = .group
        conversation.title = groupName
        conversation.avatarURL = nil
        return conversation
    }
}

struct ChatsMenuOverlay: View {
    @Binding var showChatsMenu: Bool
    @Binding var showStartConversation: Bool
    @Binding var showUserPicker: Bool

    var body: some View {
        Group {
            if showChatsMenu {
                VStack {
                    HStack {
                        Spacer()
                        PopMenu(menuItems: [
                            PopMenuInfo(
                                icon: "message",
                                title: LocalizedChatString("ChatsNewChatText"),
                                onClick: {
                                    showChatsMenu = false
                                    showStartConversation = true
                                }
                            ),
                            PopMenuInfo(
                                icon: "person.3.fill",
                                title: LocalizedChatString("ChatsNewGroupText"),
                                onClick: {
                                    showChatsMenu = false
                                    showUserPicker = true
                                }
                            )
                        ])
                        .padding(.trailing, 16)
                        .padding(.top, 50)
                    }
                    Spacer()
                }
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showChatsMenu = false
                        }
                )
                .animation(.easeInOut(duration: 0.2), value: showChatsMenu)
            }
        }
    }
}

struct StartConversationSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var friendList: [ContactInfo] = []
    @State private var isLoading = true
    let contactListStore: ContactListStore
    var onUserSelected: (AZOrderedListItem) -> Void

    var body: some View {
        NavigationView {
            VStack {
                if isLoading && friendList.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    AZOrderedList(
                        userList: orderedListItems,
                        onItemClick: { user in
                            presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onUserSelected(user)
                            }
                        }
                    )
                }
            }
            .navigationBarTitle(LocalizedChatString("ChatsNewChatText"), displayMode: .inline)
            .navigationBarItems(leading: Button(LocalizedChatString("Cancel")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            loadFriendList()
        }
        .onReceive(contactListStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendList))) { newFriendList in
            DispatchQueue.main.async {
                self.friendList = newFriendList
            }
        }
    }
    
    private func loadFriendList() {
        isLoading = true
        
        let currentFriendList = contactListStore.state.value.friendList
        if !currentFriendList.isEmpty {
            DispatchQueue.main.async {
                self.friendList = currentFriendList
                self.isLoading = false
            }
        }
        
        contactListStore.fetchFriendList(completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("StartConversationSheet: Successfully fetched friend list")
                case .failure(let error):
                    print("StartConversationSheet: Failed to fetch friend list: \(error)")
                    self.isLoading = false
                }
            }
        })
    }
    
    private var orderedListItems: [AZOrderedListItem] {
        return friendList.map { contact in
            AZOrderedListItem(
                userID: contact.contactID,
                avatarURL: contact.avatarURL,
                title: contact.title
            )
        }
    }
    
}

// MARK: - UserPickerSheet
struct UserPickerSheet: View {
    let contactListStore: ContactListStore
    @ObservedObject var selectedUsersContainer: SelectedUsersContainer
    @Binding var showUserPicker: Bool
    @Binding var showConfigSheet: Bool
    @State private var friendList: [ContactInfo] = []
    
    var body: some View {
        NavigationView {
            UserPicker(
                userList: userPickerItems,
                maxCount: 0,
                onSelectedChanged: { users in
                    selectedUsersContainer.users = users
                    showUserPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showConfigSheet = true
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            contactListStore.fetchFriendList(completion: { result in
            })
        }
        .onReceive(contactListStore.state.subscribe(StatePublisherSelector(keyPath: \ContactListState.friendList))) { newFriendList in
            self.friendList = newFriendList
        }
    }
    
    // Computed property that always reflects current friendList state
    private var userPickerItems: [UserPickerItem] {
        let items = friendList.map { contact in
            UserPickerItem(
                userID: contact.contactID,
                avatarURL: contact.avatarURL,
                title: contact.title ?? contact.contactID
            )
        }
        return items
    }
}

