import UIKit
import SnapKit
import Combine
import Kingfisher
import MJRefresh
import AtomicXCore

/**
 * Co-host user list component (half-screen panel)
 *
 * APIs involved:
 * - LiveListStore.shared.fetchLiveList(cursor:count:completion:) - fetch the live room list
 * - LiveListStore.shared.state - live room list state subscription (LiveListState.liveList)
 *
 * Features:
 * - Display the current list of hosts available for co-hosting
 * - Display the host avatar, nickname, and live room ID
 * - Support pull-to-refresh
 * - Notify the caller via callback after selection
 */
class CoHostUserListView: UIView {

    // MARK: - Properties

    /// whitelist of layout templates that support cross-room co-hosting
    private static func isCoHostSupported(_ template: SeatLayoutTemplate) -> Bool {
        switch template {
        case .videoDynamicGrid9Seats,
             .videoDynamicFloat7Seats,
             .videoFixedGrid9Seats,
             .videoFixedFloat7Seats,
             .videoLandscape4Seats:
            return true
        default:
            return false
        }
    }

    private let currentLiveID: String
    private var cancellables = Set<AnyCancellable>()
    private var liveList: [LiveInfo] = []

    /// item count per page
    private let pageSize = 20

    /// current pagination cursor
    private var cursor: String = ""

    /// callback after selecting a host, passing in the target live room's liveID
    var onSelectHost: ((LiveInfo) -> Void)?

    /// callback when the list is empty
    var onEmptyList: (() -> Void)?

    /// callback when loading fails
    var onLoadError: ((ErrorInfo) -> Void)?

    // MARK: - UI Components

    /// title bar
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "livePK.coHost.selectHost".localized
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    /// closebutton
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.6)
        return button
    }()

    /// separator
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return view
    }()

    /// host list
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.delegate = self
        tv.dataSource = self
        tv.register(CoHostUserCell.self, forCellReuseIdentifier: CoHostUserCell.reuseIdentifier)
        tv.rowHeight = 64
        tv.showsVerticalScrollIndicator = false

        // MJRefresh pull-to-refresh
        tv.mj_header = MJRefreshNormalHeader(refreshingTarget: self, refreshingAction: #selector(refreshList))

        // MJRefresh load more on upward scroll
        tv.mj_footer = MJRefreshAutoNormalFooter(refreshingTarget: self, refreshingAction: #selector(loadMoreList))
        tv.mj_footer?.isHidden = true

        return tv
    }()

    /// empty state label
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "livePK.coHost.emptyList".localized
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    /// loading indicator
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Init

    init(currentLiveID: String) {
        self.currentLiveID = currentLiveID
        super.init(frame: .zero)
        setupUI()
        setupActions()
        loadList()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true

        addSubview(titleLabel)
        addSubview(closeButton)
        addSubview(separatorView)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(loadingIndicator)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.centerX.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(28)
        }

        separatorView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(0.5)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    // MARK: - Data Loading

    /// Load the list of live rooms available for co-hosting (initial load /pull-to-refresh)
    private func loadList() {
        loadingIndicator.startAnimating()
        emptyLabel.isHidden = true
        cursor = ""

        LiveListStore.shared.fetchLiveList(cursor: cursor, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                self.tableView.mj_header?.endRefreshing()

                switch result {
                case .success:
                    let state = LiveListStore.shared.state.value
                    self.cursor = state.liveListCursor
                    self.liveList = state.liveList
                        .filter { $0.liveID != self.currentLiveID }
                        .filter { Self.isCoHostSupported($0.seatTemplate) }

                    self.emptyLabel.isHidden = !self.liveList.isEmpty
                    self.tableView.reloadData()

                    // Check whether there is more data
                    if self.cursor.isEmpty {
                        self.tableView.mj_footer?.endRefreshingWithNoMoreData()
                    } else {
                        self.tableView.mj_footer?.resetNoMoreData()
                    }
                    self.tableView.mj_footer?.isHidden = self.liveList.isEmpty

                    if self.liveList.isEmpty {
                        self.onEmptyList?()
                    }

                case .failure(let error):
                    self.emptyLabel.isHidden = false
                    self.onLoadError?(error)
                }
            }
        }
    }

    /// load more on upward scroll
    private func loadMore() {
        guard !cursor.isEmpty else {
            tableView.mj_footer?.endRefreshingWithNoMoreData()
            return
        }

        LiveListStore.shared.fetchLiveList(cursor: cursor, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success:
                    let state = LiveListStore.shared.state.value
                    self.cursor = state.liveListCursor

                    let newItems = state.liveList
                        .filter { $0.liveID != self.currentLiveID }
                        .filter { Self.isCoHostSupported($0.seatTemplate) }

                    // Append new items after deduplication
                    let existingIDs = Set(self.liveList.map { $0.liveID })
                    let uniqueNewItems = newItems.filter { !existingIDs.contains($0.liveID) }
                    self.liveList.append(contentsOf: uniqueNewItems)
                    self.tableView.reloadData()

                    if self.cursor.isEmpty {
                        self.tableView.mj_footer?.endRefreshingWithNoMoreData()
                    } else {
                        self.tableView.mj_footer?.endRefreshing()
                    }

                case .failure:
                    self.tableView.mj_footer?.endRefreshing()
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func refreshList() {
        loadList()
    }

    @objc private func loadMoreList() {
        loadMore()
    }

    @objc private func closeTapped() {
        // Remove from the parent view (the caller manages the dismiss logic)
        dismiss()
    }

    // MARK: - Public Methods

    /// Present the panel as a half-screen panel in the specified view controller
    func show(in viewController: UIViewController) {
        guard let window = viewController.view.window else { return }

        // semi-transparent background dimming view
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimmingView.tag = 9999
        dimmingView.alpha = 0
        window.addSubview(dimmingView)
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Tap the dimming view to close
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        dimmingView.addGestureRecognizer(tapGesture)

        // add the panel
        window.addSubview(self)
        self.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.45)
            make.bottom.equalToSuperview()
        }

        // slide-up animation from the bottom
        self.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height * 0.45)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            dimmingView.alpha = 1
            self.transform = .identity
        }
    }

    /// dismiss the panel
    func dismiss() {
        let dimmingView = self.superview?.viewWithTag(9999)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            dimmingView?.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: self.bounds.height)
        }) { _ in
            dimmingView?.removeFromSuperview()
            self.removeFromSuperview()
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension CoHostUserListView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return liveList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CoHostUserCell.reuseIdentifier, for: indexPath) as? CoHostUserCell else {
            return UITableViewCell()
        }
        let liveInfo = liveList[indexPath.row]
        cell.configure(with: liveInfo)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let liveInfo = liveList[indexPath.row]
        dismiss()
        onSelectHost?(liveInfo)
    }
}

// MARK: - CoHostUserCell

/// Co-host user cell - displays the host avatar, nickname, and live room ID
private class CoHostUserCell: UITableViewCell {

    static let reuseIdentifier = "CoHostUserCell"

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        return label
    }()

    private let liveIDLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
        return label
    }()

    private let connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("livePK.coHost.connect".localized, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        button.layer.cornerRadius = 14
        button.isUserInteractionEnabled = false // Triggered by tapping the entire row
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        let highlightView = UIView()
        highlightView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectedBackgroundView = highlightView

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(liveIDLabel)
        contentView.addSubview(connectButton)

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            make.top.equalTo(avatarImageView).offset(2)
            make.trailing.lessThanOrEqualTo(connectButton.snp.leading).offset(-12)
        }

        liveIDLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(connectButton.snp.leading).offset(-12)
        }

        connectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(64)
            make.height.equalTo(28)
        }
    }

    func configure(with liveInfo: LiveInfo) {
        let owner = liveInfo.liveOwner
        nameLabel.text = owner.userName.isEmpty ? owner.userID : owner.userName
        liveIDLabel.text = "ID: \(liveInfo.liveID)"

        // Use Kingfisher to load the avatar
        let placeholder = UIImage(systemName: "person.circle.fill")
        avatarImageView.kf.setImage(
            with: URL(string: owner.avatarURL),
            placeholder: placeholder,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage,
            ]
        )
        avatarImageView.tintColor = UIColor.white.withAlphaComponent(0.3)
    }
}
