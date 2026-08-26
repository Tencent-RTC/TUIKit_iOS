import AtomicXCore
import Combine
import SnapKit
import UIKit

final class CreateGroupConversationViewControllerImpl: RTCBaseView {
    var onConfirm: (([UserPickerItem]) -> Void)?

    private static let bottomBarHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let bottomBarVerticalPadding: CGFloat = 10

    private static let bottomBarSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let dividerHeight: CGFloat = 0.5

    private static let previewAvatarSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let confirmButtonHeight: CGFloat = 36

    private static let confirmButtonCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let confirmButtonHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private let pickerView = UserPickerView()

    private let searchBar = ContactSearchBarView()

    private let bottomBar = UIView()

    private let bottomDivider = UIView()

    private let previewScrollView = UIScrollView()

    private let previewStack = UIStackView()

    private let confirmButton = UIButton(type: .custom)

    private var cancellables = Set<AnyCancellable>()

    private var allItems: [UserPickerItem] = []

    private var currentQuery = ""

    private var currentSelection: [UserPickerItem] = []

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func constructViewHierarchy() {
        addSubview(searchBar)
        addSubview(pickerView)
        addSubview(bottomBar)
        bottomBar.addSubview(bottomDivider)
        bottomBar.addSubview(previewScrollView)
        previewScrollView.addSubview(previewStack)
        bottomBar.addSubview(confirmButton)
    }

    public override func activateConstraints() {
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        bottomDivider.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.bottomBarHorizontalPadding)
            make.top.equalTo(bottomBar.safeAreaLayoutGuide).offset(Self.bottomBarVerticalPadding)
            make.bottom.equalTo(bottomBar.safeAreaLayoutGuide).offset(-Self.bottomBarVerticalPadding)
            make.height.equalTo(Self.confirmButtonHeight)
        }
        previewScrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.bottomBarHorizontalPadding)
            make.trailing.equalTo(confirmButton.snp.leading).offset(-Self.bottomBarSpacing)
            make.centerY.equalTo(confirmButton)
            make.height.equalTo(ChatAvatarSize.m.size)
        }
        previewStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
        pickerView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }

    public override func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        bottomBar.backgroundColor = colors.bgColorOperate
        bottomDivider.backgroundColor = colors.strokeColorSecondary

        previewScrollView.showsHorizontalScrollIndicator = false
        previewStack.axis = .horizontal
        previewStack.spacing = Self.previewAvatarSpacing
        previewStack.alignment = .center

        confirmButton.titleLabel?.font = FontScheme.caption2Bold
        confirmButton.setTitleColor(colors.textColorButton, for: .normal)
        confirmButton.layer.cornerRadius = Self.confirmButtonCornerRadius
        confirmButton.layer.masksToBounds = true
        confirmButton.contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: Self.confirmButtonHorizontalPadding,
            bottom: 0,
            right: Self.confirmButtonHorizontalPadding
        )
        updateConfirmButton()
    }

    public override func bindInteraction() {
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        searchBar.onQueryChange = { [weak self] query in
            self?.currentQuery = query
            self?.applyFilter()
        }
        pickerView.onSelectionChanged = { [weak self] selection in
            self?.currentSelection = selection
            self?.updateConfirmButton()
            self?.refreshPreviews()
        }
        pickerView.onUserInteraction = { [weak self] in
            self?.searchBar.hideKeyboard()
        }
        subscribeFriendList()
        ContactStore.shared.loadFriends(completion: nil)
    }

    private func subscribeFriendList() {
        ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friendList in
                self?.allItems = ConversationCreateSupport.userPickerItems(from: friendList)
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }

    private func applyFilter() {
        let keyword = currentQuery.trimmingCharacters(in: .whitespaces)
        let filtered: [UserPickerItem]
        if keyword.isEmpty {
            filtered = allItems
        } else {
            filtered = allItems.filter {
                $0.title.range(of: keyword, options: .caseInsensitive) != nil
                    || $0.userID.range(of: keyword, options: .caseInsensitive) != nil
            }
        }
        pickerView.configure(userList: filtered, maxCount: 0)
    }

    private func updateConfirmButton() {
        let colors = ChatUIKitTheme.colors
        let count = currentSelection.count
        confirmButton.setTitle(String(format: LocalizedChatString("ConfirmSelectionFormat"), count), for: .normal)
        confirmButton.backgroundColor = count > 0 ? colors.textColorLink : colors.textColorDisable
    }

    private func refreshPreviews() {
        previewStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in currentSelection {
            let avatar = ChatAvatarView(size: .m, isRound: false)
            avatar.configure(avatarURL: item.avatarURL, fallbackName: item.title)
            avatar.snp.makeConstraints { make in
                make.width.height.equalTo(ChatAvatarSize.m.size)
            }
            previewStack.addArrangedSubview(avatar)
        }
        previewScrollView.layoutIfNeeded()
        let maxOffsetX = max(0, previewScrollView.contentSize.width - previewScrollView.bounds.width)
        let targetX = previewScrollView.effectiveUserInterfaceLayoutDirection == .rightToLeft ? 0 : maxOffsetX
        previewScrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
    }

    @objc private func handleConfirm() {
        guard !currentSelection.isEmpty else { return }
        onConfirm?(currentSelection)
    }
}
