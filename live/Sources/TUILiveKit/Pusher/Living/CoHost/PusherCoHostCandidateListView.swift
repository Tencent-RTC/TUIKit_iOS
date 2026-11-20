import UIKit
import SnapKit
import Kingfisher

final class PusherCoHostCandidateListView: BottomSheetView, UITableViewDataSource, UITableViewDelegate {
    var onInvite: ((String) -> Void)?
    var onCancel: ((String) -> Void)?
    var onRefresh: (() -> Void)?
    var onLoadMore: (() -> Void)?
    var onBack: (() -> Void)?
    var onDidDismiss: (() -> Void)?

    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .custom)
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let randomConnectionView = PusherCoHostRandomConnectionView()
    private let randomHeaderView = UIView(
        frame: CGRect(x: 0, y: 0, width: 0, height: CoHostCandidateStyle.randomHeaderHeight))
    private let emptyHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
    private let refreshControl = UIRefreshControl()
    private let footerView = UIView()
    private let footerButton = UIButton(type: .system)
    private let emptyLabel = UILabel()
    private var hostAvatarURL = ""
    private var state = PusherCoHostStore.State()
    private var groups: [[PusherCoHostStore.User]] = [[], []]
    private var isAdding = false

    override var sheetHeight: CGFloat { min(550 + safeAreaInsets.bottom, max(0, bounds.height - 80)) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    deinit {
        MainActor.assumeIsolated {
            tableView.delegate = nil
            tableView.dataSource = nil
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The table is inside contentView; its bounds must be resolved before sizing its header.
        contentView.layoutIfNeeded()
        updateTableHeaderSize()
        updateTableFooterSize()
        updateRandomPresentation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateRandomPresentation()
    }

    func bindHostAvatar(_ avatarURL: String) {
        guard hostAvatarURL != avatarURL else { return }
        hostAvatarURL = avatarURL
        randomConnectionView.bind(hostAvatarURL: avatarURL, candidates: state.candidates)
    }

    func show(isAdding: Bool) {
        self.isAdding = isAdding
        backButton.isHidden = !isAdding
        titleLabel.text = LiveKitResources.localizedString(
            isAdding ? "tuilivekit.pusher.cohost.invite_title" : "tuilivekit.pusher.cohost.interaction_title")
        titleLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(isAdding ? 52 : 18)
            make.trailing.equalToSuperview().inset(18)
            make.top.equalToSuperview().offset(isAdding ? 46 : 30)
            make.height.equalTo(34)
        }
        tableView.snp.updateConstraints { $0.top.equalToSuperview().offset(isAdding ? 98 : 78) }
        contentView.layoutIfNeeded()
        updateTableHeaderSize()
        tableView.tableHeaderView = isAdding ? emptyHeaderView : randomHeaderView
        reloadRows()
        tableView.reloadData()
        tableView.setContentOffset(.zero, animated: false)
        present()
        updateRandomPresentation(restart: true)
    }

    func bind(_ state: PusherCoHostStore.State) {
        guard self.state != state else { return }
        self.state = state
        randomConnectionView.bind(hostAvatarURL: hostAvatarURL, candidates: state.candidates)
        if !state.isLoading { refreshControl.endRefreshing() }
        reloadRows()
    }

    override func sheetDidDismiss() { onDidDismiss?() }

    override func sheetWillDismiss() {
        refreshControl.endRefreshing()
        randomConnectionView.setPresentationEnabled(false)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSheetHeight(animated: false)
    }

    private func configureUI() {
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(18)
            make.top.equalToSuperview().offset(30)
            make.height.equalTo(34)
        }
        backButton.setImage(LiveKitResources.image(named: "livekit_cohost_back"), for: .normal)
        backButton.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.common.back")
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        contentView.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(40)
            make.size.equalTo(44)
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        // Grouped headers scroll with the candidates. Suppress UIKit's extra table-top spacing.
        tableView.tableHeaderView = emptyHeaderView
        randomHeaderView.addSubview(randomConnectionView)
        randomConnectionView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.trailing.equalToSuperview().inset(2)
            make.height.equalTo(CoHostCandidateStyle.randomCardHeight)
            make.bottom.equalToSuperview().inset(CoHostCandidateStyle.randomCardBottomSpacing)
        }
        tableView.rowHeight = CoHostCandidateStyle.rowHeight
        tableView.sectionHeaderHeight = 31
        tableView.sectionFooterHeight = 14
        if #available(iOS 15, *) { tableView.sectionHeaderTopPadding = 0 }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CoHostCandidateCell.self, forCellReuseIdentifier: CoHostCandidateCell.reuseID)
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        contentView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(78)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        footerButton.titleLabel?.font = .systemFont(ofSize: 13)
        footerButton.setTitleColor(.white.withAlphaComponent(0.78), for: .normal)
        footerButton.addTarget(self, action: #selector(loadMore), for: .touchUpInside)
        footerView.addSubview(footerButton)
        tableView.tableFooterView = footerView

        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .white.withAlphaComponent(0.48)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        footerView.addSubview(emptyLabel)
    }

    private func reloadRows() {
        var nextGroups: [[PusherCoHostStore.User]] = [[], []]
        for user in state.candidates {
            let belongsToFollowGroup = isAdding ? user.isMutual : user.isFollowing
            nextGroups[belongsToFollowGroup ? 0 : 1].append(user)
        }
        if groups != nextGroups {
            groups = nextGroups
            tableView.reloadData()
        } else {
            for indexPath in tableView.indexPathsForVisibleRows ?? [] {
                let cell = tableView.cellForRow(at: indexPath) as? CoHostCandidateCell
                cell?.bind(groups[indexPath.section][indexPath.row], state: state)
            }
        }
        emptyLabel.isHidden = !state.candidates.isEmpty || state.isLoading || state.loadError != nil
        emptyLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.cohost.empty")
        let footerKey: String
        if state.isLoading {
            footerKey = "tuilivekit.common.processing"
        } else if state.loadError != nil {
            footerKey = "tuilivekit.pusher.cohost.retry"
        } else {
            footerKey = "tuilivekit.pusher.cohost.load_more"
        }
        footerButton.setTitle(LiveKitResources.localizedString(footerKey), for: .normal)
        footerButton.isEnabled = !state.isLoading
        footerButton.isHidden = !state.isLoading && !state.hasMore && state.loadError == nil
        updateTableFooterSize()
    }

    private func updateTableHeaderSize() {
        guard !isAdding else { return }
        // UITableView reserves the header's explicit frame height even before its first width is available.
        let size = CGSize(width: tableView.bounds.width, height: CoHostCandidateStyle.randomHeaderHeight)
        guard randomHeaderView.frame.size != size else { return }
        randomHeaderView.frame.size = size
        tableView.tableHeaderView = randomHeaderView
    }

    private func updateTableFooterSize() {
        let width = tableView.bounds.width
        let emptyHeight: CGFloat = emptyLabel.isHidden ? 0 : 60
        let buttonHeight: CGFloat = footerButton.isHidden ? 0 : 44
        emptyLabel.frame = CGRect(x: 2, y: 0, width: max(0, width - 4), height: emptyHeight)
        footerButton.frame = CGRect(x: 0, y: emptyHeight, width: width, height: buttonHeight)
        let size = CGSize(width: width, height: max(CGFloat.leastNormalMagnitude, emptyHeight + buttonHeight))
        guard footerView.frame.size != size else { return }
        footerView.frame.size = size
        tableView.tableFooterView = footerView
    }

    private func updateRandomPresentation(restart: Bool = false) {
        let visible =
            isPresented && !isAdding && !isHidden && window != nil
            && randomHeaderView.frame.intersects(tableView.bounds)
        randomConnectionView.setPresentationEnabled(visible, restart: restart)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { updateRandomPresentation() }

    func numberOfSections(in tableView: UITableView) -> Int { groups.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { groups[section].count }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !groups[section].isEmpty else { return nil }
        let header = UIView()
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white.withAlphaComponent(0.78)
        let key =
            section == 1
            ? "tuilivekit.pusher.cohost.recommended"
            : (isAdding ? "tuilivekit.pusher.cohost.mutual" : "tuilivekit.pusher.cohost.following")
        label.text = LiveKitResources.localizedString(key)
        header.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.top.equalToSuperview().offset(4)
            make.height.equalTo(!isAdding && section == 0 ? 21 : 20)
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard !groups[section].isEmpty else { return .leastNormalMagnitude }
        return !isAdding && section == 0 ? 32 : 31
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Preserve the drawer background through each section's spacing.
        let spacer = UIView()
        spacer.backgroundColor = .clear
        return spacer
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard !groups[section].isEmpty else { return .leastNormalMagnitude }
        return !isAdding && section == 0 ? 26 : 14
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: CoHostCandidateCell.reuseID, for: indexPath)
                as? CoHostCandidateCell
        else { return UITableViewCell() }
        let user = groups[indexPath.section][indexPath.row]
        cell.bind(user, state: state)
        cell.onAction = { [weak self] in
            guard let self else { return }
            if self.state.isInvited(liveID: user.liveID) {
                self.onCancel?(user.liveID)
            } else {
                self.onInvite?(user.liveID)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? CoHostCandidateCell)?.cancelImageRequest()
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? CoHostCandidateCell)?.bind(groups[indexPath.section][indexPath.row], state: state)
        let lastSection = groups[1].isEmpty ? 0 : 1
        guard !isHidden, indexPath.section == lastSection, indexPath.row >= groups[lastSection].count - 2,
            state.hasMore, !state.isLoading, state.loadError == nil
        else { return }
        // Defer SDK callbacks until UIKit finishes applying the current data source.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isHidden, self.state.hasMore, !self.state.isLoading, self.state.loadError == nil
            else { return }
            self.onLoadMore?()
        }
    }

    @objc private func refresh() { onRefresh?() }
    @objc private func handleBack() { onBack?() }
    @objc private func loadMore() {
        guard !state.isLoading else { return }
        if state.candidates.isEmpty || state.loadError != nil { onRefresh?() } else { onLoadMore?() }
    }
}

private final class CoHostCandidateCell: UITableViewCell {
    static let reuseID = "CoHostCandidateCell"
    var onAction: (() -> Void)?

    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let actionButton = UIButton(type: .custom)
    private let separator = UIView()
    private var avatarURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        avatar.contentMode = .scaleAspectFill
        avatar.layer.cornerRadius = 22
        avatar.clipsToBounds = true
        contentView.addSubview(avatar)
        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(nameLabel)
        actionButton.titleLabel?.font = .systemFont(ofSize: 12)
        actionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        actionButton.titleLabel?.minimumScaleFactor = 0.75
        actionButton.layer.cornerRadius = 10
        actionButton.layer.borderWidth = 1
        actionButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
        contentView.addSubview(actionButton)
        separator.backgroundColor = .white.withAlphaComponent(0.07)
        contentView.addSubview(separator)
        avatar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
            make.size.equalTo(44)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(59)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(4)
            make.centerY.equalToSuperview()
            make.width.equalTo(94)
            make.height.equalTo(34)
        }
        separator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { Task { @MainActor [avatar] in avatar.kf.cancelDownloadTask() } }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelImageRequest()
        avatar.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        nameLabel.text = nil
        onAction = nil
    }

    func bind(_ user: PusherCoHostStore.User, state: PusherCoHostStore.State) {
        nameLabel.text = user.userName
        if avatarURL != user.avatarURL {
            cancelImageRequest()
            avatarURL = user.avatarURL
            let placeholder = LiveKitResources.image(named: "livekit_livelist_default_avatar")
            avatar.kf.setImage(with: URL(string: user.avatarURL), placeholder: placeholder)
        }
        let connected = state.connected.contains { $0.liveID == user.liveID }
        let key: String
        if connected {
            key = "tuilivekit.pusher.cohost.connected"
        } else if state.isBusy(liveID: user.liveID) {
            key = "tuilivekit.common.processing"
        } else if state.isInvited(liveID: user.liveID) {
            key = "tuilivekit.pusher.cohost.cancel_invitation"
        } else {
            key = "tuilivekit.pusher.cohost.invite"
        }
        actionButton.setTitle(LiveKitResources.localizedString(key), for: .normal)
        actionButton.isEnabled = !connected && !state.isBusy(liveID: user.liveID) && !state.isExiting
        actionButton.setTitleColor(.white.withAlphaComponent(connected ? 0.28 : 1), for: .normal)
        actionButton.backgroundColor =
            connected ? .white.withAlphaComponent(0.04) : CoHostCandidateStyle.actionBackground
        actionButton.layer.borderColor =
            (connected ? UIColor.white.withAlphaComponent(0.05) : CoHostCandidateStyle.actionBorder).cgColor
    }

    func cancelImageRequest() {
        avatar.kf.cancelDownloadTask()
        avatarURL = nil
    }
    @objc private func handleAction() { onAction?() }
}

// Ardot 5074:292 / 5074:304 / 5074:1659.
private enum CoHostCandidateStyle {
    static let rowHeight: CGFloat = 66
    static let randomCardHeight: CGFloat = 142
    static let randomCardBottomSpacing: CGFloat = 12
    static let randomHeaderHeight = randomCardHeight + randomCardBottomSpacing
    static let actionBackground = UIColor(red: 0.098, green: 0.388, blue: 0.867, alpha: 0.467)
    static let actionBorder = UIColor(red: 0.384, green: 0.671, blue: 1, alpha: 0.392)
}
