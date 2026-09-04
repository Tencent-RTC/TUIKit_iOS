import UIKit
import Combine
import SnapKit
import AtomicXCore

final class ReactionDetailViewController: UIViewController {
    private static let tabSpacing = CGFloat(SpacingScheme.smallSpacing)

    private static let tabBarTopInset: CGFloat = 26

    private static let tabBarHeight: CGFloat = 32

    private static let contentHorizontalMargin = CGFloat(SpacingScheme.bubbleSpacing)

    private static let tableTopSpacing = CGFloat(SpacingScheme.bubbleSpacing)

    private static let userRowHeight: CGFloat = 52

    private static let reactionUserPageCount = 20

    private let message: MessageInfo

    private let currentUserID: String?

    private let actionStore: MessageActionStore

    private var reactionList: [MessageReaction]

    private var selectedReactionID: String = ""

    private var users: [UserProfile] = []

    private var cancellables = Set<AnyCancellable>()

    private let tabScrollView = UIScrollView()

    private let tabStack = UIStackView()

    private let tableView = UITableView(frame: .zero, style: .plain)

    private var selectedReaction: MessageReaction? {
        return reactionList.first { $0.reactionID == selectedReactionID }
    }

    private var orderedUsers: [UserProfile] {
        var list = users
        guard let reaction = selectedReaction, reaction.reactedByMyself,
              let currentUserID = currentUserID,
              let selfIndex = list.firstIndex(where: { $0.userID == currentUserID }), selfIndex > 0 else {
            return list
        }
        let selfUser = list.remove(at: selfIndex)
        list.insert(selfUser, at: 0)
        return list
    }

    // MARK: - Init

    init(message: MessageInfo, currentUserID: String?) {
        self.message = message
        self.currentUserID = currentUserID
        self.reactionList = message.reactionList
        self.actionStore = MessageActionStore.create(message: message)
        super.init(nibName: nil, bundle: nil)
        if #available(iOS 16.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribeState()
        if let first = reactionList.first {
            selectTab(reactionID: first.reactionID)
        }
    }

    // MARK: - User Ordering (自己置顶)

    private func setupUI() {
        view.backgroundColor = TUIChatKitTheme.colors.bgColorOperate

        tabScrollView.showsHorizontalScrollIndicator = false
        tabStack.axis = .horizontal
        tabStack.spacing = Self.tabSpacing
        tabStack.alignment = .center

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = Self.userRowHeight
        tableView.register(ReactionUserCell.self, forCellReuseIdentifier: ReactionUserCell.reuseID)

        view.addSubview(tabScrollView)
        tabScrollView.addSubview(tabStack)
        view.addSubview(tableView)

        tabScrollView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.tabBarTopInset)
            make.leading.trailing.equalToSuperview().inset(Self.contentHorizontalMargin)
            make.height.equalTo(Self.tabBarHeight)
        }
        tabStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(tabScrollView.snp.bottom).offset(Self.tableTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Self.contentHorizontalMargin)
            make.bottom.equalToSuperview()
        }
        rebuildTabs()
    }

    private func subscribeState() {
        actionStore.state
            .subscribe(StatePublisherSelector(keyPath: \MessageActionState.reactionUserList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.users = list
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for reaction in reactionList {
            let tab = ReactionTabButton(
                reaction: reaction,
                isSelected: reaction.reactionID == selectedReactionID
            ) { [weak self] in
                self?.selectTab(reactionID: reaction.reactionID)
            }
            tabStack.addArrangedSubview(tab)
        }
    }

    private func selectTab(reactionID: String) {
        selectedReactionID = reactionID
        rebuildTabs()
        users = []
        tableView.reloadData()
        actionStore.loadReactionUsers(reactionID: reactionID, count: Self.reactionUserPageCount) { _ in }
    }

    private func isSelf(_ user: UserProfile) -> Bool {
        return user.userID == currentUserID && (selectedReaction?.reactedByMyself ?? false)
    }

    private func removeSelfReaction() {
        guard !selectedReactionID.isEmpty else { return }
        actionStore.removeReaction(reactionID: selectedReactionID) { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss(animated: true) }
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ReactionDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return orderedUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ReactionUserCell.reuseID, for: indexPath) as? ReactionUserCell else {
            return UITableViewCell()
        }
        let user = orderedUsers[indexPath.row]
        cell.configure(user: user, isSelf: isSelf(user))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let user = orderedUsers[indexPath.row]
        if isSelf(user) {
            removeSelfReaction()
        }
    }
}

// MARK: - Tab Button

private final class ReactionTabButton: UIControl {
    private static let cornerRadius = CGFloat(RadiusScheme.largeRadius)

    private static let selectedBorderWidth: CGFloat = 1

    private static let selectedBackgroundAlpha: CGFloat = 0.1

    private static let contentSpacing = CGFloat(SpacingScheme.iconTextSpacing)

    private static let emojiSize: CGFloat = 18

    private static let contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

    private let handler: () -> Void

    init(reaction: MessageReaction, isSelected: Bool, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        buildUI(reaction: reaction, isSelected: isSelected)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI(reaction: MessageReaction, isSelected: Bool) {
        let colors = TUIChatKitTheme.colors
        layer.cornerRadius = Self.cornerRadius
        layer.borderWidth = isSelected ? Self.selectedBorderWidth : 0
        layer.borderColor = isSelected ? colors.buttonColorPrimaryDefault.cgColor : UIColor.clear.cgColor
        backgroundColor = isSelected
            ? colors.buttonColorPrimaryDefault.withAlphaComponent(Self.selectedBackgroundAlpha)
            : colors.bgColorInput

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = ReactionEmojiRenderer.image(for: reaction.reactionID) ?? UIImage(systemName: "face.smiling")

        let countLabel = UILabel()
        countLabel.font = FontScheme.caption2Regular
        countLabel.textColor = isSelected ? colors.buttonColorPrimaryDefault : colors.textColorSecondary
        countLabel.text = "\(reaction.totalUserCount)"

        let stack = UIStackView(arrangedSubviews: [imageView, countLabel])
        stack.axis = .horizontal
        stack.spacing = Self.contentSpacing
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        imageView.snp.makeConstraints { make in make.width.height.equalTo(Self.emojiSize) }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.contentInsets)
        }
    }

    @objc private func handleTap() { handler() }
}

// MARK: - User Cell

private final class ReactionUserCell: UITableViewCell {
    static let reuseID = "ReactionUserCell"

    private static let avatarSize: CGFloat = 36

    private static let avatarNameSpacing = CGFloat(SpacingScheme.iconIconSpacing)

    private static let nameTopOffset: CGFloat = 2

    private static let hintTopSpacing: CGFloat = 2

    private let avatarView = ChatAvatarView(size: .m, isRound: true)

    private let nameLabel = UILabel()

    private let hintLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        let colors = TUIChatKitTheme.colors
        nameLabel.font = FontScheme.caption2Medium
        nameLabel.textColor = colors.textColorPrimary
        hintLabel.font = FontScheme.caption3Regular
        hintLabel.textColor = colors.textColorTertiary
        hintLabel.text = LocalizedChatString("ChatTap2Remove")

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(hintLabel)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.avatarSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarNameSpacing)
            make.top.equalTo(avatarView).offset(Self.nameTopOffset)
            make.trailing.lessThanOrEqualToSuperview()
        }
        hintLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(Self.hintTopSpacing)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(user: UserProfile, isSelf: Bool) {
        let name = user.nickname ?? user.userID
        nameLabel.text = name
        hintLabel.isHidden = !isSelf
        avatarView.configure(avatarURL: user.avatarURL, fallbackName: name)
    }
}
