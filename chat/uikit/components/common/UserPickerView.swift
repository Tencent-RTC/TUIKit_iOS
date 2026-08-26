import AtomicXCore
import SnapKit
import UIKit

final class UserPickerView: UIView {
    var onSelectionChanged: (([UserPickerItem]) -> Void)?

    var onReachEnd: (() -> Void)?

    var onUserInteraction: (() -> Void)?

    var selectedItems: [UserPickerItem] {
        selectedOrder.compactMap { allKnownItems[$0] }
    }

    private static let rowHeight: CGFloat = 60

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let indexBarReserved: CGFloat = 26

    private static let sectionHeaderHeight: CGFloat = 32

    private static let indexBarEndPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let indexBarVerticalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let centerBubbleSize: CGFloat = 80

    private static let centerBubbleDismissDelay: TimeInterval = 0.15

    private static let centerBubbleBackgroundAlpha: CGFloat = 0.9

    private var userList: [UserPickerItem] = []

    private var maxCount: Int = 1

    private var preselectedIDs: Set<String> = []

    private var sectionedItems: [(letter: String, items: [UserPickerItem])] = []

    private var allKnownItems: [String: UserPickerItem] = [:]

    private var selectedIDs: Set<String> = []

    private var selectedOrder: [String] = []

    private var bubbleDismissWorkItem: DispatchWorkItem?

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = Self.rowHeight
        table.keyboardDismissMode = .onDrag
        table.register(UserPickerRowCell.self, forCellReuseIdentifier: UserPickerRowCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        return table
    }()

    private let indexBar = AtomicIndexBarView()

    private let centerBubbleLabel = UILabel()

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindIndexBar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(userList: [UserPickerItem], maxCount: Int = 1, defaultSelectedItems: Set<String> = []) {
        self.userList = userList
        self.maxCount = maxCount
        self.preselectedIDs = defaultSelectedItems
        userList.forEach { allKnownItems[$0.userID] = $0 }
        rebuildSections()
        tableView.reloadData()
    }

    func setInitialSelectedIDs(_ ids: Set<String>) {
        let editableIDs = ids.filter { allKnownItems[$0] != nil && !preselectedIDs.contains($0) }
        selectedIDs = Set(editableIDs)
        selectedOrder = userList.map(\.userID).filter { selectedIDs.contains($0) }
        tableView.reloadData()
    }

    private func constructViewHierarchy() {
        addSubview(tableView)
        addSubview(indexBar)
        addSubview(centerBubbleLabel)
    }

    private func activateConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        indexBar.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.indexBarEndPadding)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Self.indexBarVerticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.indexBarVerticalPadding)
        }
        centerBubbleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.centerBubbleSize)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        tableView.backgroundColor = colors.bgColorOperate

        indexBar.isHidden = true

        centerBubbleLabel.font = FontScheme.body1Bold
        centerBubbleLabel.textColor = colors.textColorPrimary
        centerBubbleLabel.textAlignment = .center
        centerBubbleLabel.backgroundColor = colors.bgColorBubbleReciprocal.withAlphaComponent(Self.centerBubbleBackgroundAlpha)
        centerBubbleLabel.layer.cornerRadius = Self.centerBubbleSize / 2
        centerBubbleLabel.layer.masksToBounds = true
        centerBubbleLabel.isHidden = true
    }

    private func bindIndexBar() {
        indexBar.onLetterSelected = { [weak self] letter in
            guard let self = self else { return }
            if let section = self.sectionedItems.firstIndex(where: { $0.letter == letter }),
               !self.sectionedItems[section].items.isEmpty {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: section), at: .top, animated: false)
            }
            self.indexBar.setCurrentLetter(letter)
            self.showCenterBubble(letter)
        }
        indexBar.onDragStart = { [weak self] in
            self?.bubbleDismissWorkItem?.cancel()
        }
        indexBar.onDragEnd = { [weak self] in
            guard let self = self else { return }
            let workItem = DispatchWorkItem { [weak self] in
                self?.centerBubbleLabel.isHidden = true
            }
            self.bubbleDismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.centerBubbleDismissDelay, execute: workItem)
        }
    }

    private func showCenterBubble(_ letter: String) {
        bubbleDismissWorkItem?.cancel()
        centerBubbleLabel.text = letter
        centerBubbleLabel.isHidden = false
    }

    private func rebuildSections() {
        let azItems = userList.map {
            AZOrderedListItem(userID: $0.userID, avatarURL: $0.avatarURL, title: $0.title, extraData: $0)
        }
        let grouped = AZOrderedListSorter.group(azItems)
        sectionedItems = grouped.sections.map { section in
            (section.sectionTitle, section.items.compactMap { $0.extraData as? UserPickerItem })
        }
        let letters = sectionedItems.map { $0.letter }
        indexBar.setLetters(letters)
        indexBar.isHidden = letters.isEmpty
    }

    private func isSelected(_ item: UserPickerItem) -> Bool {
        selectedIDs.contains(item.userID) || preselectedIDs.contains(item.userID)
    }

    private func isLocked(_ item: UserPickerItem) -> Bool {
        item.isDisabled || preselectedIDs.contains(item.userID)
    }

    private func toggle(_ item: UserPickerItem) {
        guard !isLocked(item) else { return }
        let willSelect = !selectedIDs.contains(item.userID)
        if maxCount == 1 {
            selectedIDs.removeAll()
            selectedOrder.removeAll()
            if willSelect {
                selectedIDs.insert(item.userID)
                selectedOrder.append(item.userID)
            }
        } else {
            if willSelect {
                selectedIDs.insert(item.userID)
                selectedOrder.append(item.userID)
            } else {
                selectedIDs.remove(item.userID)
                selectedOrder.removeAll { $0 == item.userID }
            }
        }
        tableView.reloadData()
        onSelectionChanged?(selectedItems)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension UserPickerView: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sectionedItems.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sectionedItems[section].items.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Self.sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = ChatUIKitTheme.colors.bgColorDialog
        let label = UILabel()
        label.text = sectionedItems[section].letter
        label.font = FontScheme.caption2Bold
        label.textColor = ChatUIKitTheme.colors.textColorPrimary
        header.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: UserPickerRowCell.reuseIdentifier,
            for: indexPath
        ) as? UserPickerRowCell else {
            return UITableViewCell()
        }
        let item = sectionedItems[indexPath.section].items[indexPath.row]
        cell.configure(item: item, isSelected: isSelected(item), isLocked: isLocked(item))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        onUserInteraction?()
        toggle(sectionedItems[indexPath.section].items[indexPath.row])
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onUserInteraction?()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let firstVisible = tableView.indexPathsForVisibleRows?.first,
              sectionedItems.indices.contains(firstVisible.section) else { return }
        indexBar.setCurrentLetter(sectionedItems[firstVisible.section].letter)

        guard let lastSection = sectionedItems.indices.last,
              let lastRowCount = sectionedItems.last?.items.count,
              lastRowCount > 0,
              let lastVisible = tableView.indexPathsForVisibleRows?.last,
              lastVisible.section == lastSection,
              lastVisible.row >= lastRowCount - 1 else { return }
        onReachEnd?()
    }
}

// MARK: - UserPickerRowCell

private final class UserPickerRowCell: UITableViewCell {
    static let reuseIdentifier = "UserPickerRowCell"

    private static let checkboxSize: CGFloat = 16

    private static let checkboxAvatarSpacing: CGFloat = 10

    private static let avatarTextSpacing: CGFloat = 12

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let indexBarReserved: CGFloat = 26

    private let checkboxView = SelectionCheckBox()

    private let avatarView = ChatAvatarView(size: .m, isRound: false)

    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: UserPickerItem, isSelected: Bool, isLocked: Bool) {
        let colors = ChatUIKitTheme.colors
        checkboxView.isChecked = isSelected
        checkboxView.isLocked = isLocked
        nameLabel.text = item.title
        nameLabel.textColor = isLocked ? colors.textColorSecondary : colors.textColorPrimary
        avatarView.configure(avatarURL: item.avatarURL, fallbackName: item.title)
    }

    private func constructViewHierarchy() {
        contentView.addSubview(checkboxView)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
    }

    private func activateConstraints() {
        checkboxView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.checkboxSize)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(checkboxView.snp.trailing).offset(Self.checkboxAvatarSpacing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ChatAvatarSize.m.size)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarTextSpacing)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.indexBarReserved)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        contentView.backgroundColor = colors.bgColorOperate
        nameLabel.font = FontScheme.body4Regular
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
    }
}
