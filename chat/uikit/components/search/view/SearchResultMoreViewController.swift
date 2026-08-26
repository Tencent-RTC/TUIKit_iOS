import UIKit
import Combine
import SnapKit
import AtomicXCore

final class SearchResultMoreViewController: UIViewController {
    private let searchType: SearchType

    private let initialKeyword: String

    private let onTapItem: SearchResultHandler

    private let viewModel: SearchViewModel

    private var cancellables = Set<AnyCancellable>()

    private var currentKeyword: String

    private var friendSnapshot: [FriendSearchInfo] = []

    private var groupSnapshot: [GroupSearchInfo] = []

    private var messageSnapshot: [MessageSearchResultItem] = []

    private let searchBar = SearchFieldBar()

    private let statusView = SearchStatusView()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 64
        table.keyboardDismissMode = .onDrag
        table.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseIdentifier)
        return table
    }()

    private var currentResultCount: Int {
        if searchType == .friend {
            return friendSnapshot.count
        } else if searchType == .group {
            return groupSnapshot.count
        } else {
            return messageSnapshot.count
        }
    }

    init(searchType: SearchType,
         keyword: String,
         onTapItem: @escaping SearchResultHandler) {
        self.searchType = searchType
        self.initialKeyword = keyword
        self.currentKeyword = keyword
        self.onTapItem = onTapItem
        self.viewModel = SearchViewModel(scene: .singleType(searchType))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHierarchy()
        setupStyle()
        bindViewModel()
        searchBar.setText(initialKeyword)
        if !initialKeyword.isEmpty {
            viewModel.searchImmediately(initialKeyword)
        }
    }

    // MARK: - Navigation

    private func setupHierarchy() {
        searchBar.onTextChanged = { [weak self] text in
            self?.currentKeyword = text
            self?.viewModel.updateKeyword(text)
            self?.updateStatus()
        }
        searchBar.onCancel = { [weak self] in
            self?.searchBar.setText("")
            self?.viewModel.searchImmediately("")
            self?.dismissOrPop()
        }

        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(statusView)

        searchBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        statusView.snp.makeConstraints { make in
            make.edges.equalTo(tableView)
        }
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        tableView.backgroundColor = colors.bgColorOperate
    }

    private func bindViewModel() {
        Publishers.CombineLatest3(
            viewModel.$friendList,
            viewModel.$groupList,
            viewModel.$messageResults
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.reloadResults()
        }
        .store(in: &cancellables)

        viewModel.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatus() }
            .store(in: &cancellables)
    }

    private func reloadResults() {
        friendSnapshot = viewModel.friendList
        groupSnapshot = viewModel.groupList
        messageSnapshot = viewModel.messageResults
        tableView.reloadData()
        updateStatus()
    }

    private func updateStatus() {
        if viewModel.isSearching && currentResultCount == 0 {
            statusView.setStatus(.loading)
        } else {
            statusView.setStatus(.hidden)
        }
    }

    private func dismissOrPop() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func pushMessageDetail(_ item: MessageSearchResultItem) {
        let controller = SearchMessageDetailViewController(
            conversationID: item.conversationID,
            conversationName: item.conversationShowName,
            conversationAvatar: item.conversationAvatarURL,
            keyword: currentKeyword,
            onTapItem: onTapItem
        )
        navigationController?.pushViewController(controller, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SearchResultMoreViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentResultCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SearchResultCell.reuseIdentifier, for: indexPath
        ) as? SearchResultCell else {
            return UITableViewCell()
        }
        if searchType == .friend {
            guard indexPath.row < friendSnapshot.count else { return cell }
            SearchResultCellConfigurator.configureFriend(
                cell, friend: friendSnapshot[indexPath.row],
                keyword: currentKeyword, showDivider: true
            )
        } else if searchType == .group {
            guard indexPath.row < groupSnapshot.count else { return cell }
            SearchResultCellConfigurator.configureGroup(
                cell, group: groupSnapshot[indexPath.row],
                keyword: currentKeyword, showDivider: true
            )
        } else {
            guard indexPath.row < messageSnapshot.count else { return cell }
            SearchResultCellConfigurator.configureMessage(
                cell, item: messageSnapshot[indexPath.row],
                keyword: currentKeyword, showDivider: true
            )
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SearchResultMoreViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if searchType == .friend {
            guard indexPath.row < friendSnapshot.count else { return }
            onTapItem(friendSnapshot[indexPath.row])
        } else if searchType == .group {
            guard indexPath.row < groupSnapshot.count else { return }
            onTapItem(groupSnapshot[indexPath.row])
        } else {
            guard indexPath.row < messageSnapshot.count else { return }
            pushMessageDetail(messageSnapshot[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard searchType == .message else { return }
        if indexPath.row == messageSnapshot.count - 3 {
            viewModel.loadMoreMessages()
        }
    }
}
