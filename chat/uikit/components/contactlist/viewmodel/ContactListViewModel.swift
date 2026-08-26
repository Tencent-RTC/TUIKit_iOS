import Foundation
import Combine
import AtomicXCore

final class ContactListViewModel {
    @Published private(set) var friendList: [ContactInfo] = []

    @Published private(set) var friendApplicationUnreadCount: Int = 0

    @Published private(set) var groupApplicationUnreadCount: Int = 0

    private let contactStore: ContactStore

    private let groupStore: GroupStore

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(contactStore: ContactStore = ContactStore.shared,
         groupStore: GroupStore = GroupStore.shared) {
        self.contactStore = contactStore
        self.groupStore = groupStore
        syncInitialState()
        subscribeState()
    }

    // MARK: - Business Actions (forwarded to core stores)

    func loadData() {
        contactStore.loadFriends(completion: nil)
        contactStore.loadFriendApplications(completion: nil)
        groupStore.loadApplications(completion: nil)
    }

    private func syncInitialState() {
        let contactState = contactStore.state.value
        let groupState = groupStore.state.value
        friendList = contactState.friendList
        friendApplicationUnreadCount = contactState.friendApplicationUnreadCount
        groupApplicationUnreadCount = groupState.unreadApplicationCount
    }

    private func subscribeState() {
        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self else { return }

                if list.isEmpty && !self.friendList.isEmpty {
                    return
                }
                self.friendList = list
            }
            .store(in: &cancellables)

        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendApplicationUnreadCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.friendApplicationUnreadCount = count
            }
            .store(in: &cancellables)

        groupStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.unreadApplicationCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.groupApplicationUnreadCount = count
            }
            .store(in: &cancellables)
    }
}
