import UIKit
import Combine
import SnapKit
import AtomicXCore

final class SearchMessageDetailViewController: UIViewController {
    private static let estimatedRowHeight: CGFloat = 64

    private static let dividerHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let dividerHeight: CGFloat = 0.5

    private static let loadMorePrefetchThreshold = 3

    private let conversationID: String

    private let conversationName: String

    private let conversationAvatar: String?

    private let initialKeyword: String

    private let onTapItem: SearchResultHandler

    private let viewModel: SearchViewModel

    private var cancellables = Set<AnyCancellable>()

    private var messages: [MessageInfo] = []

    private var currentKeyword: String

    private let searchBar = SearchFieldBar()

    private let headerView = SearchConversationHeaderView()

    private let dividerView = UIView()

    private let statusView = SearchStatusView()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = Self.estimatedRowHeight
        table.keyboardDismissMode = .onDrag
        table.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseIdentifier)
        return table
    }()

    init(conversationID: String,
         conversationName: String,
         conversationAvatar: String?,
         keyword: String,
         onTapItem: @escaping SearchResultHandler) {
        self.conversationID = conversationID
        self.conversationName = conversationName
        self.conversationAvatar = conversationAvatar
        self.initialKeyword = keyword
        self.currentKeyword = keyword
        self.onTapItem = onTapItem
        self.viewModel = SearchViewModel(scene: .conversation(conversationID))
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

    private func setupHierarchy() {
        searchBar.onTextChanged = { [weak self] text in
            self?.currentKeyword = text
            self?.viewModel.updateKeyword(text)
        }
        searchBar.onCancel = { [weak self] in
            self?.searchBar.setText("")
            self?.viewModel.searchImmediately("")
            self?.dismissOrPop()
        }
        headerView.onTap = { [weak self] in self?.handleHeaderTap() }

        view.addSubview(searchBar)
        view.addSubview(headerView)
        view.addSubview(dividerView)
        view.addSubview(tableView)
        view.addSubview(statusView)

        searchBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        headerView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        dividerView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.equalToSuperview().offset(Self.dividerHorizontalInset)
            make.trailing.equalToSuperview().offset(-Self.dividerHorizontalInset)
            make.height.equalTo(Self.dividerHeight)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom)
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
        view.backgroundColor = colors.bgColorOperate
        tableView.backgroundColor = colors.bgColorOperate
        dividerView.backgroundColor = colors.strokeColorPrimary
        headerView.configure(name: conversationName, avatarURL: conversationAvatar)
    }

    private func bindViewModel() {
        viewModel.$messageResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.messages = results.flatMap { $0.messageList }
                self?.tableView.reloadData()
                self?.updateStatus()
            }
            .store(in: &cancellables)

        viewModel.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatus() }
            .store(in: &cancellables)
    }

    private func updateStatus() {
        if viewModel.isSearching && messages.isEmpty {
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

    private func handleHeaderTap() {
        let info: [String: Any] = [
            "conversationID": conversationID,
            "conversationName": conversationName,
            "conversationAvatar": conversationAvatar as Any
        ]
        onTapItem(info)
    }

    private func handleMessageTap(_ message: MessageInfo) {
        let result: [String: Any] = [
            "message": message,
            "conversationID": conversationID,
            "conversationName": conversationName,
            "conversationAvatar": conversationAvatar as Any
        ]
        onTapItem(result)
    }
}

// MARK: - UITableViewDataSource

extension SearchMessageDetailViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SearchResultCell.reuseIdentifier, for: indexPath
        ) as? SearchResultCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        let colors = TUIChatKitTheme.colors
        let senderName = ChatUtil.getMessageSenderName(message)
        let abstract = MessageListHelper.getMessageAbstract(message, showMergedTitle: true)
        let title = SearchHighlightBuilder.attributedText(
            text: senderName,
            keyword: "",
            font: FontScheme.caption2Bold,
            normalColor: colors.textColorPrimary,
            highlightColor: colors.textColorLink
        )
        let subtitle: NSAttributedString
        if abstract.contains("[TUIEmoji_") {
            subtitle = SearchHighlightBuilder.attributedTextWithEmoji(
                text: abstract,
                keyword: currentKeyword,
                font: FontScheme.caption3Regular,
                normalColor: colors.textColorSecondary,
                highlightColor: colors.textColorLink
            )
        } else {
            subtitle = SearchHighlightBuilder.attributedText(
                text: abstract,
                keyword: currentKeyword,
                font: FontScheme.caption3Regular,
                normalColor: colors.textColorSecondary,
                highlightColor: colors.textColorLink
            )
        }
        cell.configure(
            avatarURL: message.from.avatarURL,
            avatarName: senderName,
            title: title,
            subtitle: subtitle,
            showDivider: true
        )
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SearchMessageDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleMessageTap(messages[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == messages.count - Self.loadMorePrefetchThreshold {
            viewModel.loadMoreMessages()
        }
    }
}

final class SearchConversationHeaderView: UIView {
    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let verticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let avatarNameSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let nameChevronSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let chevronWidth: CGFloat = 8

    private static let chevronHeight: CGFloat = 13

    var onTap: (() -> Void)?

    private let avatarView = ChatAvatarView(size: .m, isRound: true)

    private let nameLabel = UILabel()

    private let chevronView = UIImageView()

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, avatarURL: String?) {
        nameLabel.text = name
        avatarView.configure(avatarURL: avatarURL, fallbackName: name)
    }

    private func constructViewHierarchy() {
        addSubview(avatarView)
        addSubview(nameLabel)
        addSubview(chevronView)
    }

    private func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.width.height.equalTo(ChatAvatarSize.m.size)
        }
        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.equalTo(Self.chevronWidth)
            make.height.equalTo(Self.chevronHeight)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarNameSpacing)
            make.trailing.lessThanOrEqualTo(chevronView.snp.leading).offset(-Self.nameChevronSpacing)
            make.centerY.equalToSuperview()
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorTopBar
        nameLabel.font = FontScheme.caption1Bold
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        chevronView.image = UIImage(systemName: "chevron.right")
        chevronView.tintColor = colors.textColorSecondary
        chevronView.contentMode = .scaleAspectFit
    }

    @objc private func handleTap() {
        onTap?()
    }
}
