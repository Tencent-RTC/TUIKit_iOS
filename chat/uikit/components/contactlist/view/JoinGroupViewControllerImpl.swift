import AtomicXCore
import SnapKit
import UIKit

final class JoinGroupViewControllerImpl: RTCBaseView {
    var onEnterGroupChat: ((GroupInfo) -> Void)?

    var onJoinGroup: ((GroupInfo) -> Void)?

    private static let emptyTopMargin: CGFloat = CGFloat(SpacingScheme.titleSpacing)

    private static let loadingTopSpacing: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private let searchBar = ContactSearchBarView()

    private lazy var resultCell = ContactSearchResultCell { [weak self] in
        self?.handleResultTapped()
    }

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let emptyLabel = UILabel()

    private var foundGroup: GroupInfo?

    private var isJoinedFoundGroup = false

    private var isSearching = false

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func constructViewHierarchy() {
        addSubview(searchBar)
        addSubview(resultCell)
        addSubview(loadingIndicator)
        addSubview(emptyLabel)
    }

    public override func activateConstraints() {
        searchBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        resultCell.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        loadingIndicator.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(Self.loadingTopSpacing)
            make.centerX.equalToSuperview()
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(Self.emptyTopMargin)
            make.leading.trailing.equalToSuperview()
        }
    }

    public override func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        searchBar.placeholder = LocalizedChatString("GroupID")
        resultCell.isHidden = true
        emptyLabel.text = LocalizedChatString("ContactNoInformation")
        emptyLabel.font = FontScheme.caption1Regular
        emptyLabel.textColor = colors.textColorSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
    }

    public override func bindInteraction() {
        searchBar.onSubmit = { [weak self] in
            self?.searchGroup()
        }
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        backgroundTap.cancelsTouchesInView = false
        addGestureRecognizer(backgroundTap)
        GroupStore.shared.loadJoinedGroups(completion: nil)
    }

    private func searchGroup() {
        guard let keyword = currentKeyword(), !keyword.isEmpty else { return }
        foundGroup = nil
        resultCell.isHidden = true
        emptyLabel.isHidden = true
        isSearching = true
        loadingIndicator.startAnimating()
        GroupStore.shared.getGroupInfo(
            groupID: keyword,
            completion: GroupLookupHandler(
                onSuccess: { [weak self] group in
                    DispatchQueue.main.async {
                        self?.isSearching = false
                        self?.loadingIndicator.stopAnimating()
                        self?.applySearchResult(group)
                    }
                },
                onFailure: { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.isSearching = false
                        self?.loadingIndicator.stopAnimating()
                        self?.applySearchResult(nil)
                    }
                }
            )
        )
    }

    private func currentKeyword() -> String? {
        return searchBar.currentText.trimmingCharacters(in: .whitespaces)
    }

    private func applySearchResult(_ group: GroupInfo?) {
        foundGroup = group
        guard let group = group else {
            resultCell.isHidden = true
            emptyLabel.isHidden = false
            return
        }
        emptyLabel.isHidden = true
        resultCell.isHidden = false
        let isJoined = GroupStore.shared.state.value.joinedGroupList.contains { $0.groupID == group.groupID }
        isJoinedFoundGroup = isJoined
        resultCell.configure(
            avatarURL: group.avatarURL,
            name: ContactDisplayFormatter.name(for: group),
            identityLabelText: LocalizedChatString("GroupID"),
            identityValue: group.groupID,
            tip: isJoined ? LocalizedChatString("AlreadyInGroupTip") : nil
        )
    }

    private func handleResultTapped() {
        guard let group = foundGroup else { return }
        if isJoinedFoundGroup {
            onEnterGroupChat?(group)
        } else {
            onJoinGroup?(group)
        }
    }

    @objc private func handleBackgroundTapped() {
        endEditing(true)
    }
}
