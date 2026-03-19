import AtomicX
import AtomicXCore
import SwiftUI

public struct ContactsPage: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var showAddContactMenu = false
    @State private var showAddFriend = false
    @State private var showJoinGroup = false
    private let contactStore: ContactListStore
    let onContactClick: ((AZOrderedListItem) -> Void)?
    let onGroupClick: ((AZOrderedListItem) -> Void)?

    public init(
        contactStore: ContactListStore = ContactListStore.create(),
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil
    ) {
        self.contactStore = contactStore
        self.onContactClick = onContactClick
        self.onGroupClick = onGroupClick
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            ContactList(
                contactStore: contactStore,
                onContactClick: onContactClick,
                onGroupClick: onGroupClick
            )
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea(edges: .top))
        .overlay(
            Group {
                if showAddContactMenu {
                    VStack {
                        HStack {
                            Spacer()
                            AddContactPopView(
                                onDismiss: {
                                    showAddContactMenu = false
                                },
                                onShowAddFriend: {
                                    showAddFriend = true
                                },
                                onShowJoinGroup: {
                                    showJoinGroup = true
                                }
                            )
                            .padding(.trailing, 16)
                            .padding(.top, 50)
                        }
                        Spacer()
                    }
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showAddContactMenu = false
                            }
                    )
                    .animation(.easeInOut(duration: 0.2), value: showAddContactMenu)
                }
            }
        )
        .sheet(isPresented: $showAddFriend) {
            AddFriendView(contactStore: contactStore)
        }
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupView(contactStore: contactStore)
        }
    }

    private var headerView: some View {
        HStack {
            Text(LocalizedChatString("TabContacts"))
                .font(.system(size: 34, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(themeState.colors.textColorPrimary)
                .padding(.leading, 16)
            Spacer()
            Button(action: {
                showAddContactMenu = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                    .frame(width: 28, height: 28)
                    .cornerRadius(14)
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}
