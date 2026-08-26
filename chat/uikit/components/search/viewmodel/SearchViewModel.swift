import Foundation
import Combine
import AtomicXCore

final class SearchViewModel {
    enum Scene {
        case all
        case singleType(SearchType)
        case conversation(String)
    }

    @Published private(set) var friendList: [FriendSearchInfo] = []

    @Published private(set) var groupList: [GroupSearchInfo] = []

    @Published private(set) var messageResults: [MessageSearchResultItem] = []

    @Published private(set) var hasMoreMessageResults: Bool = true

    @Published private(set) var isSearching: Bool = false

    @Published private(set) var hasSearched: Bool = false

    private let scene: Scene

    private let store: SearchStore

    private var cancellables = Set<AnyCancellable>()

    private var debounceWorkItem: DispatchWorkItem?

    private var isLoadingMore: Bool = false

    private let debounceInterval: TimeInterval = 0.3

    private let pageSize: Int

    // MARK: - Init

    init(scene: Scene, store: SearchStore = SearchStore.create()) {
        self.scene = scene
        self.store = store
        switch scene {
        case .conversation:
            self.pageSize = 10
        case .all, .singleType:
            self.pageSize = 20
        }
        subscribeState()
    }

    // MARK: - Actions

    func updateKeyword(_ text: String) {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSearch(text)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    func searchImmediately(_ text: String) {
        debounceWorkItem?.cancel()
        performSearch(text)
    }

    func loadMoreMessages() {
        guard hasMoreMessageResults, !isLoadingMore else { return }
        isLoadingMore = true
        store.searchMore(searchType: .message) { _ in }
    }

    private func subscribeState() {
        store.state
            .subscribe(StatePublisherSelector(keyPath: \SearchState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in self?.friendList = list }
            .store(in: &cancellables)

        store.state
            .subscribe(StatePublisherSelector(keyPath: \SearchState.groupList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in self?.groupList = list }
            .store(in: &cancellables)

        store.state
            .subscribe(StatePublisherSelector(keyPath: \SearchState.messageResults))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.messageResults = list
                self?.isSearching = false
            }
            .store(in: &cancellables)

        store.state
            .subscribe(StatePublisherSelector(keyPath: \SearchState.hasMoreMessageResults))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasMore in
                self?.hasMoreMessageResults = hasMore
                self?.isLoadingMore = false
            }
            .store(in: &cancellables)
    }

    private func performSearch(_ text: String) {
        if text.isEmpty {
            clearResults()
            return
        }
        isSearching = true
        hasSearched = false
        store.search(keywordList: [text], option: buildOption()) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSearching = false
                self?.hasSearched = true
            }
        }
    }

    private func clearResults() {
        friendList = []
        groupList = []
        messageResults = []
        isSearching = false
        hasSearched = false
    }

    private func buildOption() -> SearchOption {
        var option = SearchOption()
        option.pageSize = pageSize
        switch scene {
        case .all:
            option.searchScope = [.friend, .group, .message]
        case .singleType(let type):
            option.searchScope = [type]
        case .conversation(let conversationID):
            option.searchScope = [.message]
            var messageFilter = MessageSearchFilter()
            messageFilter.conversationID = conversationID
            option.messageFilter = messageFilter
        }
        return option
    }
}
