import AtomicXCore
import SnapKit
import UIKit

final class AddFriendViewControllerImpl: RTCBaseView {
    var onAddContact: ((ContactInfo) -> Void)?

    private static let myIDTopSpacing: CGFloat = 80

    private static let searchBarContainerInsets = UIEdgeInsets(
        top: CGFloat(SpacingScheme.iconIconSpacing),
        left: CGFloat(SpacingScheme.bubbleSpacing),
        bottom: CGFloat(SpacingScheme.iconIconSpacing),
        right: CGFloat(SpacingScheme.bubbleSpacing)
    )

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let loadingTopSpacing: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let emptyFontSize: CGFloat = 17

    private let searchBar = ContactSearchBarView()

    private lazy var resultCell = ContactSearchResultCell { [weak self] in
        self?.handleResultTapped()
    }

    private let myIDLabel = UILabel()

    private let emptyLabel = UILabel()

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var foundContact: ContactInfo?

    private var hasSearched = false

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func constructViewHierarchy() {
        addSubview(searchBar)
        addSubview(myIDLabel)
        addSubview(resultCell)
        addSubview(emptyLabel)
        addSubview(loadingIndicator)
    }

    public override func activateConstraints() {
        searchBar.containerInsets = Self.searchBarContainerInsets
        searchBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        myIDLabel.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(Self.myIDTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
        }
        resultCell.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(Self.myIDTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(Self.loadingTopSpacing)
            make.centerX.equalToSuperview()
        }
    }

    public override func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        searchBar.placeholder = LocalizedChatString("ProfileUserID")
        myIDLabel.font = FontScheme.caption2Regular
        myIDLabel.textColor = colors.textColorSecondary
        myIDLabel.textAlignment = .center
        emptyLabel.text = LocalizedChatString("ContactNoInformation")
        emptyLabel.font = .systemFont(ofSize: Self.emptyFontSize)
        emptyLabel.textColor = colors.textColorSecondary
        emptyLabel.textAlignment = .center
        resultCell.isHidden = true
        emptyLabel.isHidden = true
        refreshMyIDLabel()
    }

    public override func bindInteraction() {
        searchBar.onSubmit = { [weak self] in
            self?.searchUser()
        }
        searchBar.onQueryChange = { [weak self] _ in
            guard let self = self else { return }
            if self.searchBar.currentText.isEmpty {
                self.hasSearched = false
                self.foundContact = nil
                self.resultCell.isHidden = true
                self.emptyLabel.isHidden = true
                self.refreshMyIDLabel()
            }
        }
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        backgroundTap.cancelsTouchesInView = false
        addGestureRecognizer(backgroundTap)
        ContactStore.shared.loadFriends(completion: nil)
    }

    private func refreshMyIDLabel() {
        let showMyID = !hasSearched
        myIDLabel.isHidden = !showMyID
        if showMyID {
            let myUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
            myIDLabel.text = String(
                format: LocalizedChatString("ContactLabelValueFormat"),
                LocalizedChatString("ContactMyUserID"),
                myUserID
            )
        }
    }

    private func searchUser() {
        let keyword = searchBar.currentText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        hasSearched = true
        refreshMyIDLabel()
        foundContact = nil
        resultCell.isHidden = true
        emptyLabel.isHidden = true
        loadingIndicator.startAnimating()
        ContactStore.shared.getContactInfo(
            userIDList: [keyword],
            completion: ContactLookupHandler(
                onSuccess: { [weak self] list in
                    DispatchQueue.main.async {
                        self?.loadingIndicator.stopAnimating()
                        self?.applySearchResult(list.first)
                    }
                },
                onFailure: { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.loadingIndicator.stopAnimating()
                        self?.applySearchResult(nil)
                    }
                }
            )
        )
    }

    private func applySearchResult(_ contact: ContactInfo?) {
        foundContact = contact
        guard let contact = contact else {
            resultCell.isHidden = true
            emptyLabel.isHidden = false
            return
        }
        emptyLabel.isHidden = true
        resultCell.isHidden = false
        resultCell.configure(
            avatarURL: contact.avatarURL,
            name: ContactDisplayFormatter.name(for: contact),
            identityLabelText: LocalizedChatString("ProfileUserID"),
            identityValue: contact.userID,
            tip: contact.isFriend ? LocalizedChatString("AlreadyFriendTip") : nil
        )
    }

    private func handleResultTapped() {
        guard let contact = foundContact, !contact.isFriend else { return }
        onAddContact?(contact)
    }

    @objc private func handleBackgroundTapped() {
        searchBar.hideKeyboard()
    }
}
