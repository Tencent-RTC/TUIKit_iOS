import UIKit
import Combine
import SnapKit
import AtomicXCore

final class SearchResultViewController: UIViewController {
    private enum ResultSection {
        case friend
        case group
        case message
    }

    private static let estimatedRowHeight: CGFloat = 58

    private static let searchBarFocusDelay: TimeInterval = 0.1

    private static let maxPreviewRowCount = 3

    private let onTapItem: SearchResultHandler

    private let viewModel = SearchViewModel(scene: .all)

    private var cancellables = Set<AnyCancellable>()

    private var currentKeyword: String = ""

    private var activeSections: [ResultSection] = []

    private var friendSnapshot: [FriendSearchInfo] = []

    private var groupSnapshot: [GroupSearchInfo] = []

    private var messageSnapshot: [MessageSearchResultItem] = []

    private var hasAutoFocusedSearchBar = false

    private let searchBar = SearchFieldBar()

    private let topBackdropView = UIView()

    private let statusView = SearchStatusView()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = Self.estimatedRowHeight
        table.keyboardDismissMode = .onDrag
        table.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseIdentifier)
        table.register(SearchSectionMoreCell.self, forCellReuseIdentifier: SearchSectionMoreCell.reuseID)
        return table
    }()

    init(onTapItem: @escaping SearchResultHandler) {
        self.onTapItem = onTapItem
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
        updateBodyState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAutoFocusedSearchBar else { return }
        hasAutoFocusedSearchBar = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.searchBarFocusDelay) { [weak self] in
            self?.searchBar.becomeFirstResponder()
        }
    }

    // MARK: - Navigation

    private func setupHierarchy() {
        searchBar.onTextChanged = { [weak self] text in
            self?.currentKeyword = text
            self?.viewModel.updateKeyword(text)
            self?.updateBodyState()
        }
        searchBar.onCancel = { [weak self] in
            self?.searchBar.setText("")
            self?.viewModel.searchImmediately("")
            self?.dismissOrPop()
        }

        view.addSubview(topBackdropView)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(statusView)

        searchBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        topBackdropView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(searchBar.snp.bottom)
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
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorDefault
        topBackdropView.backgroundColor = colors.bgColorOperate
        tableView.backgroundColor = colors.bgColorDefault
    }

    private func bindViewModel() {
        Publishers.CombineLatest4(
            viewModel.$friendList,
            viewModel.$groupList,
            viewModel.$messageResults,
            viewModel.$isSearching
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.reloadSections()
        }
        .store(in: &cancellables)

        viewModel.$hasSearched
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateBodyState() }
            .store(in: &cancellables)
    }

    private func reloadSections() {
        friendSnapshot = viewModel.friendList
        groupSnapshot = viewModel.groupList
        messageSnapshot = viewModel.messageResults
        var sections: [ResultSection] = []
        if !friendSnapshot.isEmpty { sections.append(.friend) }
        if !groupSnapshot.isEmpty { sections.append(.group) }
        if !messageSnapshot.isEmpty { sections.append(.message) }
        activeSections = sections
        tableView.reloadData()
        updateBodyState()
    }

    private func updateBodyState() {
        let hasResults = !viewModel.friendList.isEmpty
            || !viewModel.groupList.isEmpty
            || !viewModel.messageResults.isEmpty
        if currentKeyword.isEmpty {
            tableView.isHidden = true
            statusView.setStatus(.hidden)
        } else if viewModel.isSearching {
            tableView.isHidden = true
            statusView.setStatus(.loading)
        } else if hasResults {
            tableView.isHidden = false
            statusView.setStatus(.hidden)
        } else if viewModel.hasSearched {
            tableView.isHidden = true
            statusView.setStatus(.empty)
        } else {
            tableView.isHidden = true
            statusView.setStatus(.loading)
        }
    }

    private func dismissOrPop() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func deliverResult(_ result: Any) {
        onTapItem(result)
    }

    private func pushMore(_ searchType: SearchType) {
        let controller = SearchResultMoreViewController(
            searchType: searchType,
            keyword: currentKeyword,
            onTapItem: { [weak self] result in self?.deliverResult(result) }
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    private func pushMessageDetail(_ item: MessageSearchResultItem) {
        let controller = SearchMessageDetailViewController(
            conversationID: item.conversationID,
            conversationName: item.conversationShowName,
            conversationAvatar: item.conversationAvatarURL,
            keyword: currentKeyword,
            onTapItem: { [weak self] result in self?.deliverResult(result) }
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    private func rowCount(for section: ResultSection) -> Int {
        switch section {
        case .friend:
            return min(friendSnapshot.count, Self.maxPreviewRowCount)
        case .group:
            return min(groupSnapshot.count, Self.maxPreviewRowCount)
        case .message:
            return min(messageSnapshot.count, Self.maxPreviewRowCount)
        }
    }

    private func totalCount(for section: ResultSection) -> Int {
        switch section {
        case .friend: return friendSnapshot.count
        case .group: return groupSnapshot.count
        case .message: return messageSnapshot.count
        }
    }

    private func hasMoreFooter(for section: ResultSection) -> Bool {
        return totalCount(for: section) > Self.maxPreviewRowCount
    }

    private func isMoreRow(at indexPath: IndexPath) -> Bool {
        let section = activeSections[indexPath.section]
        return hasMoreFooter(for: section) && indexPath.row == rowCount(for: section)
    }

    private func headerTitle(for section: ResultSection) -> String {
        switch section {
        case .friend: return LocalizedChatString("SearchItemHeaderTitleContact")
        case .group: return LocalizedChatString("SearchItemHeaderTitleGroup")
        case .message: return LocalizedChatString("SearchItemHeaderTitleChatHistory")
        }
    }

    private func footerTitle(for section: ResultSection) -> String {
        switch section {
        case .friend: return LocalizedChatString("SearchItemFooterTitleContact")
        case .group: return LocalizedChatString("SearchItemFooterTitleGroup")
        case .message: return LocalizedChatString("SearchItemFooterTitleChatHistory")
        }
    }
}

// MARK: - UITableViewDataSource

extension SearchResultViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return activeSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let resultSection = activeSections[section]
        return rowCount(for: resultSection) + (hasMoreFooter(for: resultSection) ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < activeSections.count else { return UITableViewCell() }
        if isMoreRow(at: indexPath) {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SearchSectionMoreCell.reuseID, for: indexPath
            ) as! SearchSectionMoreCell
            cell.configure(title: footerTitle(for: activeSections[indexPath.section]))
            return cell
        }
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SearchResultCell.reuseIdentifier, for: indexPath
        ) as? SearchResultCell else {
            return UITableViewCell()
        }
        switch activeSections[indexPath.section] {
        case .friend:
            guard indexPath.row < friendSnapshot.count else { return cell }
            SearchResultCellConfigurator.configureFriend(
                cell, friend: friendSnapshot[indexPath.row],
                keyword: currentKeyword, showDivider: true
            )
        case .group:
            guard indexPath.row < groupSnapshot.count else { return cell }
            SearchResultCellConfigurator.configureGroup(
                cell, group: groupSnapshot[indexPath.row],
                keyword: currentKeyword, showDivider: true
            )
        case .message:
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

extension SearchResultViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = SearchSectionHeaderView()
        header.configure(title: headerTitle(for: activeSections[section]))
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return SearchSectionHeaderView.headerHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < activeSections.count else { return }
        if isMoreRow(at: indexPath) {
            switch activeSections[indexPath.section] {
            case .friend: pushMore(.friend)
            case .group: pushMore(.group)
            case .message: pushMore(.message)
            }
            return
        }
        switch activeSections[indexPath.section] {
        case .friend:
            guard indexPath.row < friendSnapshot.count else { return }
            deliverResult(friendSnapshot[indexPath.row])
        case .group:
            guard indexPath.row < groupSnapshot.count else { return }
            deliverResult(groupSnapshot[indexPath.row])
        case .message:
            guard indexPath.row < messageSnapshot.count else { return }
            pushMessageDetail(messageSnapshot[indexPath.row])
        }
    }
}

final class SearchSectionHeaderView: UIView {
    static let headerHeight: CGFloat = 33

    private static let sectionTopGap: CGFloat = 1

    private static let titleLeadingPadding: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let titleTopPadding: CGFloat = 10

    private static let titleBottomPadding: CGFloat = 2

    private let contentBackground = UIView()

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = TUIChatKitTheme.colors.bgColorDefault
        contentBackground.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        addSubview(contentBackground)
        contentBackground.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.sectionTopGap)
            make.leading.trailing.bottom.equalToSuperview()
        }
        titleLabel.font = FontScheme.caption2Regular
        titleLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        contentBackground.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.titleLeadingPadding)
            make.top.equalToSuperview().offset(Self.titleTopPadding)
            make.bottom.equalToSuperview().offset(-Self.titleBottomPadding)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}

final class SearchSectionMoreCell: UITableViewCell {
    static let reuseID = "SearchSectionMoreCell"

    private static let moreLeadingPadding: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let moreVerticalPadding: CGFloat = 10

    private let moreLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        contentView.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        moreLabel.font = FontScheme.caption2Regular
        moreLabel.textColor = TUIChatKitTheme.colors.textColorLink
        contentView.addSubview(moreLabel)
        moreLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.moreLeadingPadding)
            make.top.equalToSuperview().offset(Self.moreVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.moreVerticalPadding)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        moreLabel.text = title
    }
}
