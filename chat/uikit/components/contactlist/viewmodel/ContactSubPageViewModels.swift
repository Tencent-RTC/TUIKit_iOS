import Foundation
import Combine
import AtomicXCore

final class FriendApplicationListViewModel {
    @Published private(set) var applications: [FriendApplicationInfo] = []

    private let contactStore: ContactStore

    private var cancellables = Set<AnyCancellable>()

    init(contactStore: ContactStore = ContactStore.shared) {
        self.contactStore = contactStore
        applications = contactStore.state.value.friendApplicationList
        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendApplicationList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.applications = list
            }
            .store(in: &cancellables)
    }

    func loadData() {
        contactStore.loadFriendApplications(completion: nil)
        contactStore.clearFriendApplicationUnreadCount(completion: nil)
    }

    func accept(_ application: FriendApplicationInfo, completion: @escaping CompletionClosure) {
        contactStore.acceptFriendApplication(info: application, completion: completion)
    }

    func refuse(_ application: FriendApplicationInfo, completion: @escaping CompletionClosure) {
        contactStore.refuseFriendApplication(info: application, completion: completion)
    }
}

final class GroupApplicationListViewModel {
    @Published private(set) var applications: [GroupApplicationInfo] = []

    private let groupStore: GroupStore

    private var cancellables = Set<AnyCancellable>()

    init(groupStore: GroupStore = GroupStore.shared) {
        self.groupStore = groupStore
        applications = groupStore.state.value.applicationList
        groupStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.applicationList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.applications = list
            }
            .store(in: &cancellables)
    }

    func loadData() {
        groupStore.loadApplications(completion: nil)
        groupStore.clearApplicationUnreadCount(completion: nil)
    }

    func accept(_ application: GroupApplicationInfo, completion: @escaping CompletionClosure) {
        groupStore.acceptApplication(info: application, completion: completion)
    }

    func refuse(_ application: GroupApplicationInfo, completion: @escaping CompletionClosure) {
        groupStore.refuseApplication(info: application, completion: completion)
    }
}

final class GroupListViewModel {
    @Published private(set) var groups: [GroupInfo] = []

    private let groupStore: GroupStore

    private var cancellables = Set<AnyCancellable>()

    init(groupStore: GroupStore = GroupStore.shared) {
        self.groupStore = groupStore
        groups = groupStore.state.value.joinedGroupList
        groupStore.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.joinedGroupList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.groups = list
            }
            .store(in: &cancellables)
    }

    func loadData() {
        groupStore.loadJoinedGroups(completion: nil)
    }
}

final class BlackListViewModel {
    @Published private(set) var blackList: [ContactInfo] = []

    private let contactStore: ContactStore

    private var cancellables = Set<AnyCancellable>()

    init(contactStore: ContactStore = ContactStore.shared) {
        self.contactStore = contactStore
        blackList = contactStore.state.value.blackList
        contactStore.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.blackList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.blackList = list
            }
            .store(in: &cancellables)
    }

    func loadData() {
        contactStore.loadBlackList(completion: nil)
    }
}
