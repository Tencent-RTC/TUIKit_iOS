import UIKit
import Combine
import SnapKit
import AtomicXCore

final class BlackListViewController: UIViewController {
    private static let navigationBarHeight: CGFloat = 44

    private let onContactClick: (AZOrderedListItem) -> Void

    private let viewModel = BlackListViewModel()

    private var blackList: [ContactInfo] = []

    private var searchQuery = ""

    private var cancellables = Set<AnyCancellable>()

    private lazy var navigationBar = SubPageNavigationBar(title: LocalizedChatString("ContactsBlackList"))

    private let searchBar = ContactSearchBarView()

    private lazy var listView: AZOrderedListView = {
        let view = AZOrderedListView(showIndexBar: true) { [weak self] item in
            self?.onContactClick(item)
        }
        view.emptyText = LocalizedChatString("ContactNoBlacklistUsers")
        return view
    }()

    init(onContactClick: @escaping (AZOrderedListItem) -> Void) {
        self.onContactClick = onContactClick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHierarchy()
        setupStyle()
        bindInteraction()
        bindViewModel()
        viewModel.loadData()
    }

    private func setupHierarchy() {
        navigationBar.onClose = { [weak self] in
            if let navigationController = self?.navigationController {
                navigationController.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        }
        view.addSubview(navigationBar)
        view.addSubview(searchBar)
        view.addSubview(listView)
        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.navigationBarHeight)
        }
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        listView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupStyle() {
        view.backgroundColor = ChatUIKitTheme.colors.bgColorOperate
    }

    private func bindInteraction() {
        searchBar.onQueryChange = { [weak self] query in
            self?.searchQuery = query
            self?.renderList()
        }
        listView.onUserInteraction = { [weak self] in
            self?.searchBar.hideKeyboard()
        }
    }

    private func bindViewModel() {
        viewModel.$blackList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.blackList = list
                self?.renderList()
            }
            .store(in: &cancellables)
    }

    private func renderList() {
        let isSearching = !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        listView.emptyText = isSearching
            ? LocalizedChatString("SearchBlacklistUserNotFound")
            : LocalizedChatString("ContactNoBlacklistUsers")
        let filtered = blackList.filter { matchesSearchQuery($0, query: searchQuery) }
        listView.setItems(filtered.map { item(for: $0) })
    }

    private func matchesSearchQuery(_ contact: ContactInfo, query: String) -> Bool {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            return true
        }
        let candidates = [
            ContactDisplayNameFormatter.name(for: contact),
            contact.userID,
            contact.nickname,
            contact.friendRemark,
        ]
        var seen = Set<String>()
        return candidates.compactMap { $0 }.filter { !$0.isEmpty }.contains { value in
            if !seen.insert(value).inserted {
                return false
            }
            return value.range(of: keyword, options: .caseInsensitive) != nil
        }
    }

    private func item(for contact: ContactInfo) -> AZOrderedListItem {
        AZOrderedListItem(
            userID: contact.userID,
            avatarURL: contact.avatarURL,
            title: ContactDisplayNameFormatter.name(for: contact)
        )
    }
}
