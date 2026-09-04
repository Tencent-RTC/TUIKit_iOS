import UIKit
import Combine
import SnapKit
import Kingfisher

final class EmojiPickerView: UIView {
    var onEmojiSelected: ((EmojiData) -> Void)?

    var onCustomEmojiSelected: ((EmojiGroup, EmojiData) -> Void)?

    var onDelete: (() -> Void)?

    var onSend: (() -> Void)?

    var bottomSafeAreaInset: CGFloat = 0 {
        didSet {
            guard bottomSafeAreaInset != oldValue else { return }
            applyBottomSafeAreaInset()
        }
    }

    private static let littleColumnCount: CGFloat = 8

    private static let bigColumnCount: CGFloat = 5

    private static let tabStripHeight: CGFloat = 40

    private static let tabIconSize: CGFloat = 28

    private static let tabIconSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let horizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerHeight: CGFloat = 30

    private static let deleteButtonSize = CGSize(width: 40, height: 30)

    private static let sendButtonSize = CGSize(width: 50, height: 30)

    private static let actionButtonSpacing: CGFloat = 10

    private static let actionButtonPadding: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private static let actionButtonBottomContentInset: CGFloat = 10

    private static let tabDividerHeight: CGFloat = 0.5

    private static let tabStackContentInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

    private static let deleteIconPointSize: CGFloat = 14

    private static let selectedTabAlpha: CGFloat = 1.0

    private static let unselectedTabAlpha: CGFloat = 0.4

    private static let itemWidthChangeThreshold: CGFloat = 0.5

    private let collectionLayout = UICollectionViewFlowLayout()

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)

    private let deleteButton = UIButton(type: .system)

    private let sendButton = UIButton(type: .system)

    private let tabStrip = UIView()

    private let tabDivider = UIView()

    private let tabScrollView = UIScrollView()

    private let tabStackView = UIStackView()

    private var tabButtons: [UIButton] = []

    private var sendButtonBottomConstraint: Constraint?

    private var tabStripHeightConstraint: Constraint?

    private var currentGroupIndex = 0

    private var groupsChangeCancellable: AnyCancellable?

    private var recentEmojis: [EmojiData] = []

    private var allEmojis: [EmojiData] = []

    private var sections: [EmojiSection] = []

    private var itemWidth: CGFloat = 0

    private enum EmojiSection {
        case recent
        case all
    }

    private var lastLayoutHeight: CGFloat = 0

    private var groups: [EmojiGroup] {
        return EmojiConfig.shared.emojiGroups
    }

    private var currentGroup: EmojiGroup? {
        guard !groups.isEmpty else { return nil }
        let safeIndex = max(0, min(currentGroupIndex, groups.count - 1))
        return groups[safeIndex]
    }

    private var currentColumnCount: CGFloat {
        return (currentGroup?.isLittleEmoji ?? true) ? Self.littleColumnCount : Self.bigColumnCount
    }

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        rebuildTabs()
        reloadEmojis()
        groupsChangeCancellable = EmojiConfig.shared.groupsDidChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.rebuildTabs()
                self?.reloadEmojis()
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    func reloadRecentEmojis() {
        guard let group = currentGroup, group.isLittleEmoji else {
            recentEmojis = []
            rebuildSections()
            collectionView.reloadData()
            return
        }
        recentEmojis = EmojiManager.shared.getRecentEmojiDataList(groupID: group.id)
        rebuildSections()
        collectionView.reloadData()
    }

    // MARK: - Private Helpers

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayoutIfNeeded()
    }

    private func constructViewHierarchy() {
        addSubview(collectionView)
        addSubview(tabStrip)
        tabStrip.addSubview(tabDivider)
        tabStrip.addSubview(tabScrollView)
        tabScrollView.addSubview(tabStackView)
        addSubview(deleteButton)
        addSubview(sendButton)
    }

    private func activateConstraints() {
        tabStrip.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            tabStripHeightConstraint = make.height.equalTo(Self.tabStripHeight).constraint
        }
        tabDivider.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.tabDividerHeight)
        }
        tabScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tabStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.tabStackContentInsets)
            make.height.equalToSuperview()
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(tabStrip.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        sendButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.actionButtonPadding)
            sendButtonBottomConstraint = make.bottom.equalToSuperview().offset(-Self.actionButtonPadding).constraint
            make.width.equalTo(Self.sendButtonSize.width)
            make.height.equalTo(Self.sendButtonSize.height)
        }
        deleteButton.snp.makeConstraints { make in
            make.trailing.equalTo(sendButton.snp.leading).offset(-Self.actionButtonSpacing)
            make.centerY.equalTo(sendButton)
            make.width.equalTo(Self.deleteButtonSize.width)
            make.height.equalTo(Self.deleteButtonSize.height)
        }
    }

    private func bindInteraction() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiGridCell.self, forCellWithReuseIdentifier: EmojiGridCell.reuseID)
        collectionView.register(
            EmojiSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: EmojiSectionHeaderView.reuseID
        )
        deleteButton.addTarget(self, action: #selector(handleDeleteTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(handleSendTapped), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        clipsToBounds = true

        collectionLayout.minimumInteritemSpacing = 0
        collectionLayout.minimumLineSpacing = 0
        collectionLayout.sectionInset = UIEdgeInsets(
            top: 0, left: Self.horizontalInset, bottom: 0, right: Self.horizontalInset
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(
            top: 0, left: 0, bottom: Self.actionButtonBottomContentInset, right: 0
        )

        let deleteImage = UIImage(systemName: "delete.left")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.deleteIconPointSize, weight: .medium))
        deleteButton.setImage(deleteImage, for: .normal)
        deleteButton.tintColor = colors.textColorPrimary
        deleteButton.backgroundColor = colors.buttonColorSecondaryDefault
        deleteButton.layer.cornerRadius = Self.deleteButtonSize.height / 2
        deleteButton.layer.masksToBounds = true

        sendButton.setTitle(LocalizedChatString("Send"), for: .normal)
        sendButton.setTitleColor(colors.textColorButton, for: .normal)
        sendButton.titleLabel?.font = FontScheme.caption2Medium
        sendButton.backgroundColor = colors.buttonColorPrimaryDefault
        sendButton.layer.cornerRadius = Self.sendButtonSize.height / 2
        sendButton.layer.masksToBounds = true

        tabStrip.backgroundColor = colors.bgColorOperate
        tabDivider.backgroundColor = colors.strokeColorPrimary
        tabScrollView.showsHorizontalScrollIndicator = false
        tabStackView.axis = .horizontal
        tabStackView.spacing = Self.tabIconSpacing
        tabStackView.alignment = .center
    }

    private func rebuildTabs() {
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()
        for (index, group) in groups.enumerated() {
            let button = UIButton(type: .custom)
            button.frame = CGRect(x: 0, y: 0, width: Self.tabIconSize, height: Self.tabIconSize)
            button.imageView?.contentMode = .scaleAspectFit
            button.tag = index
            button.addTarget(self, action: #selector(handleTabTapped(_:)), for: .touchUpInside)
            if let iconPath = group.menuPath, !iconPath.isEmpty {
                if iconPath.hasPrefix("http") {
                    button.kf.setImage(with: URL(string: iconPath), for: .normal)
                } else {
                    button.setImage(EmojiCache.shared.getImageFromCache(iconPath), for: .normal)
                }
            }
            tabStackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.width.height.equalTo(Self.tabIconSize)
            }
            tabButtons.append(button)
        }
        updateTabStripVisibility()
        updateTabSelection()
    }

    private func updateTabStripVisibility() {
        let showTabs = groups.count > 1
        tabStrip.isHidden = !showTabs
        tabStripHeightConstraint?.update(offset: showTabs ? Self.tabStripHeight : 0)
    }

    private func updateTabSelection() {
        for (index, button) in tabButtons.enumerated() {
            button.alpha = index == currentGroupIndex ? Self.selectedTabAlpha : Self.unselectedTabAlpha
        }
    }

    @objc private func handleTabTapped(_ sender: UIButton) {
        guard sender.tag != currentGroupIndex else { return }
        currentGroupIndex = sender.tag
        updateTabSelection()
        reloadEmojis()
    }

    private func applyBottomSafeAreaInset() {
        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: Self.actionButtonBottomContentInset + bottomSafeAreaInset,
            right: 0
        )
        sendButtonBottomConstraint?.update(offset: -(Self.actionButtonPadding + bottomSafeAreaInset))
    }

    private func reloadEmojis() {
        let totalWidth = bounds.width - Self.horizontalInset * 2
        if totalWidth > 0 {
            itemWidth = floor(totalWidth / currentColumnCount)
        }
        guard let group = currentGroup else {
            allEmojis = []
            recentEmojis = []
            sections = []
            collectionView.reloadData()
            return
        }
        allEmojis = EmojiManager.shared.pickerVisibleEmojis(in: group)
        if group.isLittleEmoji {
            recentEmojis = EmojiManager.shared.getRecentEmojiDataList(groupID: group.id)
        } else {
            recentEmojis = []
        }
        deleteButton.isHidden = !group.isLittleEmoji
        sendButton.isHidden = !group.isLittleEmoji
        rebuildSections()
        collectionView.reloadData()
    }

    private func rebuildSections() {
        var result: [EmojiSection] = []
        if !recentEmojis.isEmpty {
            result.append(.recent)
        }
        result.append(.all)
        sections = result
    }

    private func emojis(in section: EmojiSection) -> [EmojiData] {
        switch section {
        case .recent: return recentEmojis
        case .all: return allEmojis
        }
    }

    private func headerTitle(for section: EmojiSection) -> String {
        switch section {
        case .recent: return LocalizedChatString("TUIChatFaceGroupRecentEmojiName")
        case .all: return LocalizedChatString("TUIChatFaceGroupAllEmojiName")
        }
    }

    private func updateLayoutIfNeeded() {
        let totalWidth = bounds.width - Self.horizontalInset * 2
        let currentHeight = bounds.height
        let previousHeight = lastLayoutHeight
        lastLayoutHeight = currentHeight
        guard totalWidth > 0, currentHeight > 0 else { return }
        let heightBecameVisible = previousHeight == 0 && currentHeight > 0
        let newWidth = floor(totalWidth / currentColumnCount)
        let widthChanged = abs(newWidth - itemWidth) > Self.itemWidthChangeThreshold
        if widthChanged {
            itemWidth = newWidth
        }
        if widthChanged || heightBecameVisible {
            collectionView.reloadData()
        }
    }

    @objc private func handleDeleteTapped() {
        onDelete?()
    }

    @objc private func handleSendTapped() {
        onSend?()
    }
}

// MARK: - UICollectionViewDataSource

extension EmojiPickerView: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis(in: sections[section]).count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EmojiGridCell.reuseID, for: indexPath
        ) as? EmojiGridCell ?? EmojiGridCell()
        let emoji = emojis(in: sections[indexPath.section])[indexPath.item]
        cell.configure(with: emoji)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: EmojiSectionHeaderView.reuseID,
            for: indexPath
        ) as? EmojiSectionHeaderView ?? EmojiSectionHeaderView()
        header.configure(title: headerTitle(for: sections[indexPath.section]))
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EmojiPickerView: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = itemWidth > 0 ? itemWidth : (bounds.width - Self.horizontalInset * 2) / currentColumnCount
        return CGSize(width: width, height: width)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if currentGroup?.isLittleEmoji == false {
            return CGSize(width: collectionView.bounds.width, height: 0)
        }
        return CGSize(width: collectionView.bounds.width, height: Self.headerHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let group = currentGroup else { return }
        let emoji = emojis(in: sections[indexPath.section])[indexPath.item]
        if group.isLittleEmoji {
            EmojiManager.shared.addRecentEmoji(emoji, groupID: group.id)
            onEmojiSelected?(emoji)
        } else {
            onCustomEmojiSelected?(group, emoji)
        }
    }
}

// MARK: - Cell

private final class EmojiGridCell: UICollectionViewCell {
    static let reuseID = "EmojiGridCell"

    private static let imageScaleFactor: CGFloat = 0.7

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalToSuperview().multipliedBy(Self.imageScaleFactor)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with emoji: EmojiData) {
        if let url = emoji.url, !url.isEmpty {
            imageView.kf.setImage(with: URL(string: url))
            return
        }
        imageView.image = EmojiManager.cachedImage(for: emoji)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}

// MARK: - Section Header

private final class EmojiSectionHeaderView: UICollectionReusableView {
    static let reuseID = "EmojiSectionHeaderView"

    private static let titleLeadingInset: CGFloat = 6

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = FontScheme.caption2Regular
        titleLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.titleLeadingInset)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}
