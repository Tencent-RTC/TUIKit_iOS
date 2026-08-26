import AtomicXCore
import Combine
import SnapKit
import UIKit

enum ConversationActionIDs {
    static let delete = "conversation.delete"
    static let mute = "conversation.mute"
    static let pin = "conversation.pin"
    static let markUnread = "conversation.markUnread"
    static let clearHistory = "conversation.clearHistory"
}

final class ConversationListViewImpl: RTCBaseView {
    private static let rowHeight: CGFloat = 72

    private let onConversationClick: (ConversationInfo) -> Void

    private let config: ConversationActionConfigProtocol

    private let viewModel: ConversationListViewModel

    private var conversations: [ConversationInfo] = []

    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = Self.rowHeight
        table.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.reuseIdentifier)
        return table
    }()

    private static let emptyIllustrationWidth: CGFloat = 88

    private static let emptyIllustrationAspectRatio: CGFloat = 300.0 / 338.0

    private static let emptyTextTopSpacing: CGFloat = 14

    private lazy var emptyView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private lazy var emptyIllustrationView: UIImageView = {
        let imageView = UIImageView(image: AtomicXChatResources.image(named: "uikit_empty_illustration"))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizedChatString("EmptyContent")
        label.font = FontScheme.caption2Regular
        label.textColor = ChatUIKitTheme.colors.textColorTertiary
        label.textAlignment = .center
        return label
    }()

    init(onConversationClick: @escaping (ConversationInfo) -> Void,
         config: ConversationActionConfigProtocol = ChatConversationActionConfig()) {
        self.onConversationClick = onConversationClick
        self.config = config
        self.viewModel = ConversationListViewModel()
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func constructViewHierarchy() {
        addSubview(tableView)
        addSubview(emptyView)
        emptyView.addSubview(emptyIllustrationView)
        emptyView.addSubview(emptyLabel)
    }

    public override func activateConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        emptyIllustrationView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.equalTo(Self.emptyIllustrationWidth)
            make.height.equalTo(Self.emptyIllustrationWidth).multipliedBy(Self.emptyIllustrationAspectRatio)
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyIllustrationView.snp.bottom).offset(Self.emptyTextTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    public override func bindInteraction() {
        tableView.dataSource = self
        tableView.delegate = self

        viewModel.$conversationList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.conversations = list
                self?.tableView.reloadData()
                self?.refreshEmptyViewVisibility()
            }
            .store(in: &cancellables)

        viewModel.$initialLoadFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEmptyViewVisibility()
            }
            .store(in: &cancellables)

        viewModel.loadConversations()
    }

    private func refreshEmptyViewVisibility() {
        emptyView.isHidden = !(viewModel.initialLoadFinished && conversations.isEmpty)
    }

    public override func setupViewStyle() {
        let listColor = ChatUIKitTheme.colors.bgColorTopBar
        backgroundColor = listColor
        tableView.backgroundColor = listColor
    }

    private func buildActions(for conversation: ConversationInfo) -> [ConversationCustomAction] {
        var defaultActions: [ConversationCustomAction] = []
        if config.isSupportMarkUnread {
            let isUnread = viewModel.isUnread(conversation)
            let title = isUnread ? LocalizedChatString("MarkAsRead") : LocalizedChatString("MarkAsUnRead")
            defaultActions.append(ConversationCustomAction(ID: ConversationActionIDs.markUnread, title: title) { [weak self] _ in
                if isUnread {
                    self?.viewModel.markAsRead(conversation)
                } else {
                    self?.viewModel.markAsUnread(conversation)
                }
            })
        }
        if config.isSupportMute {
            let willMute = conversation.receiveOption == .receive
            let title = willMute ? LocalizedChatString("ConversationMute") : LocalizedChatString("ConversationUnmute")
            defaultActions.append(ConversationCustomAction(ID: ConversationActionIDs.mute, title: title) { [weak self] _ in
                self?.viewModel.muteConversation(conversation, mute: willMute)
            })
        }
        if config.isSupportPin {
            let pinned = conversation.isPinned
            let title = pinned ? LocalizedChatString("UnPin") : LocalizedChatString("Pin")
            defaultActions.append(ConversationCustomAction(ID: ConversationActionIDs.pin, title: title) { [weak self] _ in
                self?.viewModel.pinConversation(conversation, pin: !pinned)
            })
        }
        if config.isSupportClearHistory {
            defaultActions.append(ConversationCustomAction(ID: ConversationActionIDs.clearHistory, title: LocalizedChatString("ConversationClearChatHistory")) { [weak self] _ in
                self?.viewModel.clearHistory(conversation)
            })
        }
        if config.isSupportDelete {
            defaultActions.append(ConversationCustomAction(ID: ConversationActionIDs.delete, title: LocalizedChatString("Delete"), dangerous: true) { [weak self] _ in
                self?.viewModel.deleteConversation(conversation)
            })
        }
        if let customizer = config.actionCustomizer {
            let editor = CustomEditor(items: defaultActions)
            customizer(editor)
            return editor.build()
        }
        return defaultActions
    }

    private func confirmDeleteConversation(_ conversation: ConversationInfo, action: ConversationCustomAction) {
        let alert = UIAlertController(
            title: LocalizedChatString("ConversationDeleteChatConfirmTitle"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedChatString("Delete"), style: .destructive) { _ in
            action.action(conversation)
        })
        findViewController()?.present(alert, animated: true)
    }

    private func showMoreActionSheet(actions: [ConversationCustomAction], conversation: ConversationInfo) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for action in actions {
            let style: UIAlertAction.Style = action.dangerous ? .destructive : .default
            alert.addAction(UIAlertAction(title: action.title, style: style) { _ in
                action.action(conversation)
            })
        }
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = bounds
        }
        findViewController()?.present(alert, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            responder = next
        }
        return nil
    }
}

extension ConversationListViewImpl: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ConversationCell.reuseIdentifier,
            for: indexPath
        ) as? ConversationCell else {
            return UITableViewCell()
        }
        let conversation = conversations[indexPath.row]
        cell.configure(with: conversation)
        let colors = ChatUIKitTheme.colors
        cell.backgroundColor = conversation.isPinned ? colors.bgColorInput : colors.bgColorOperate
        cell.setSeparatorHidden(indexPath.row == conversations.count - 1)
        return cell
    }
}

extension ConversationListViewImpl: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        onConversationClick(conversation)
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let conversation = conversations[indexPath.row]
        let actions = buildActions(for: conversation)

        var swipeActions: [UIContextualAction] = []
        var sheetActions: [ConversationCustomAction] = []

        var deleteContextualAction: UIContextualAction?
        var markContextualAction: UIContextualAction?

        for action in actions {
            switch action.ID {
            case ConversationActionIDs.delete:
                deleteContextualAction = UIContextualAction(style: .destructive, title: action.title) { [weak self] _, _, completion in
                    self?.confirmDeleteConversation(conversation, action: action)
                    completion(true)
                }
            case ConversationActionIDs.markUnread:
                let markAction = UIContextualAction(style: .normal, title: action.title) { _, _, completion in
                    action.action(conversation)
                    completion(true)
                }
                markAction.backgroundColor = ChatUIKitTheme.colors.buttonColorPrimaryDefault
                markContextualAction = markAction
            default:
                sheetActions.append(action)
            }
        }

        if let deleteContextualAction = deleteContextualAction {
            swipeActions.append(deleteContextualAction)
        }
        if let markContextualAction = markContextualAction {
            swipeActions.append(markContextualAction)
        }
        if !sheetActions.isEmpty {
            let moreAction = UIContextualAction(style: .normal, title: LocalizedChatString("More")) { [weak self] _, _, completion in
                self?.showMoreActionSheet(actions: sheetActions, conversation: conversation)
                completion(true)
            }
            moreAction.backgroundColor = .systemOrange
            swipeActions.append(moreAction)
        }

        guard !swipeActions.isEmpty else { return nil }
        let configuration = UISwipeActionsConfiguration(actions: swipeActions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
