import UIKit
import Combine
import SnapKit
import AtomicXCore

final class GroupListViewController: UIViewController {
    private static let navigationBarHeight: CGFloat = 44

    private let onGroupClick: (AZOrderedListItem) -> Void

    private let viewModel = GroupListViewModel()

    private var groups: [GroupInfo] = []

    private var searchQuery = ""

    private var cancellables = Set<AnyCancellable>()

    private lazy var navigationBar = SubPageNavigationBar(title: LocalizedChatString("ContactsGroupChats"))

    private let searchBar = ContactSearchBarView()

    private lazy var listView: AZOrderedListView = {
        let view = AZOrderedListView(showIndexBar: true) { [weak self] item in
            self?.onGroupClick(item)
        }
        view.emptyText = LocalizedChatString("ContactNoGroupChats")
        return view
    }()

    init(onGroupClick: @escaping (AZOrderedListItem) -> Void) {
        self.onGroupClick = onGroupClick
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
        viewModel.$groups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.groups = list
                self?.renderList()
            }
            .store(in: &cancellables)
    }

    private func renderList() {
        let isSearching = !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        listView.emptyText = isSearching
            ? LocalizedChatString("SearchGroupNotFound")
            : LocalizedChatString("ContactNoGroupChats")
        let filtered = groups.filter { matchesSearchQuery($0, query: searchQuery) }
        listView.setItems(filtered.map { item(for: $0) })
    }

    private func matchesSearchQuery(_ group: GroupInfo, query: String) -> Bool {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty {
            return true
        }
        let candidates = [ContactDisplayNameFormatter.name(for: group), group.groupID]
        return candidates.filter { !$0.isEmpty }.contains {
            $0.range(of: keyword, options: .caseInsensitive) != nil
        }
    }

    private func item(for group: GroupInfo) -> AZOrderedListItem {
        AZOrderedListItem(
            userID: group.groupID,
            avatarURL: group.avatarURL,
            title: ContactDisplayNameFormatter.name(for: group)
        )
    }
}
