import Foundation
import UIKit
import SnapKit

protocol MessageInputMorePanelDelegate: AnyObject {
    func morePanelDidSelectAlbum()
    func morePanelDidSelectCamera()
    func morePanelDidSelectVideo()
    func morePanelDidSelectFile()
    func morePanelDidSelectVideoCall()
    func morePanelDidSelectAudioCall()
}

final class MessageInputMorePanel: UIView {
    weak var delegate: MessageInputMorePanelDelegate?

    /// Called after a tap cleared an item's red dot, so the owner can refresh the
    /// more button's own dot.
    var onRedDotDismissed: (() -> Void)?

    var hasVisibleRedDot: Bool {
        return actions.contains { $0.showRedDot && !dismissedRedDotIDs.contains($0.ID) }
    }

    var bottomSafeAreaInset: CGFloat = 0 {
        didSet {
            guard bottomSafeAreaInset != oldValue else { return }
            collectionBottomConstraint?.update(inset: Self.panelPadding + bottomSafeAreaInset)
        }
    }

    private let config: ChatMessageInputConfig

    fileprivate static let columns = 4

    fileprivate static let rowsPerPage = 2

    fileprivate static var pageSize: Int { columns * rowsPerPage }

    fileprivate static let iconSize: CGFloat = 56

    fileprivate static let iconTileCornerRadius: CGFloat = CGFloat(RadiusScheme.alertRadius)

    fileprivate static let iconGlyphSize: CGFloat = 28

    fileprivate static let redDotSize: CGFloat = 8

    fileprivate static let titleTopSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    fileprivate static let titleAreaHeight: CGFloat = 29

    fileprivate static let itemVerticalSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let panelPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private let collectionView: UICollectionView

    private let pageControl = UIPageControl()

    private var collectionBottomConstraint: Constraint?

    private var actions: [MessageInputMenuAction] = []

    private var dismissedRedDotIDs: Set<String> = []

    init(config: ChatMessageInputConfig) {
        self.config = config
        let layout = MorePanelPagedGridLayout(columns: Self.columns, rows: Self.rowsPerPage)
        layout.rowSpacing = Self.itemVerticalSpacing * 2
        let size = MessageInputAppearanceApplier.dimension(config._appearance?.morePanel?.itemSize, fallback: Self.iconSize)
        layout.itemHeight = size + Self.titleTopSpacing + Self.titleAreaHeight + Self.itemVerticalSpacing
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        setupActions()
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        MessageInputAppearanceApplier.update(self)
        updateCurrentPage()
    }

    private func setupActions() {
        var defaults: [MessageInputMenuAction] = [
            MessageInputMenuAction(
                ID: MessageInputDefaultActionIDs.album,
                title: LocalizedChatString("MorePhoto"),
                iconName: "more_picture",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectAlbum() }
            )
        ]
        if config._isShowPhotoTaker {
            defaults.append(MessageInputMenuAction(
                ID: MessageInputDefaultActionIDs.takePhoto,
                title: LocalizedChatString("MoreCamera"),
                iconName: "more_camera",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectCamera() }
            ))
            defaults.append(MessageInputMenuAction(
                ID: MessageInputDefaultActionIDs.recordVideo,
                title: LocalizedChatString("MoreVideo"),
                iconName: "more_video",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectVideo() }
            ))
        }
        defaults.append(MessageInputMenuAction(
            ID: MessageInputDefaultActionIDs.file,
            title: LocalizedChatString("MoreFile"),
            iconName: "more_file",
            onClick: { [weak self] in self?.delegate?.morePanelDidSelectFile() }
        ))
        if config._isShowVideoCall {
            defaults.append(MessageInputMenuAction(
                ID: MessageInputDefaultActionIDs.videoCall,
                title: LocalizedChatString("MoreVideoCall"),
                iconName: "more_video_call",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectVideoCall() }
            ))
        }
        if config._isShowAudioCall {
            defaults.append(MessageInputMenuAction(
                ID: MessageInputDefaultActionIDs.audioCall,
                title: LocalizedChatString("MoreVoiceCall"),
                iconName: "more_voice_call",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectAudioCall() }
            ))
        }
        if let customizer = config._actionCustomizer {
            let editor = CustomEditor(items: defaults)
            customizer(editor)
            actions = editor.build()
        } else {
            actions = defaults
        }
    }

    private func setupView() {
        MessageInputAppearanceApplier.apply(fill: config._appearance?.morePanel?.fill, to: self,
            defaultColor: TUIChatKitTheme.colors.bgColorOperate)
        collectionView.backgroundColor = .clear
        LanguageHelper.applyLayoutDirection(to: collectionView)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MorePanelCell.self, forCellWithReuseIdentifier: MorePanelCell.reuseID)
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(Self.panelPadding)
            collectionBottomConstraint = make.bottom.equalToSuperview()
                .inset(Self.panelPadding).constraint
        }
        let colors = TUIChatKitTheme.colors
        pageControl.isUserInteractionEnabled = false
        pageControl.hidesForSinglePage = true
        pageControl.pageIndicatorTintColor = colors.textColorDisable
        pageControl.currentPageIndicatorTintColor = colors.textColorPrimary
        pageControl.numberOfPages = pageCount
        pageControl.currentPage = 0
        addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom)
            make.centerX.equalToSuperview()
            make.height.equalTo(Self.panelPadding)
        }
    }

    private var pageCount: Int {
        return max(1, (actions.count + Self.pageSize - 1) / Self.pageSize)
    }

    fileprivate func updateCurrentPage() {
        let width = collectionView.bounds.width
        guard width > 0 else { return }
        let rawPage = Int((collectionView.contentOffset.x + width / 2) / width)
        let page = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft ? pageCount - 1 - rawPage : rawPage
        pageControl.currentPage = min(max(page, 0), pageCount - 1)
    }
}

// MARK: - UICollectionViewDataSource

extension MessageInputMorePanel: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MorePanelCell.reuseID, for: indexPath
        ) as! MorePanelCell
        let item = actions[indexPath.item]
        cell.configure(
            icon: item.icon ?? AtomicXChatResources.image(named: item.iconName),
            title: item.title,
            showRedDot: item.showRedDot && !dismissedRedDotIDs.contains(item.ID),
            appearance: config._appearance?.morePanel,
            index: indexPath.item
        )
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension MessageInputMorePanel: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = actions[indexPath.item]
        if action.showRedDot, dismissedRedDotIDs.insert(action.ID).inserted {
            collectionView.reloadItems(at: [indexPath])
            onRedDotDismissed?()
        }
        action.onClick()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCurrentPage()
    }
}

private final class MorePanelPagedGridLayout: UICollectionViewLayout {
    var itemHeight: CGFloat = 0

    var rowSpacing: CGFloat = 0

    private let columns: Int

    private let rows: Int

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []

    private var contentWidth: CGFloat = 0

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        return true
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: collectionView?.bounds.height ?? 0)
    }

    override func prepare() {
        super.prepare()
        cachedAttributes = []
        contentWidth = 0
        guard let collectionView, collectionView.numberOfSections > 0 else { return }
        let pageWidth = collectionView.bounds.width
        let count = collectionView.numberOfItems(inSection: 0)
        guard pageWidth > 0, count > 0 else { return }
        let pageSize = columns * rows
        let pageCount = (count + pageSize - 1) / pageSize
        contentWidth = pageWidth * CGFloat(pageCount)
        let itemWidth = floor(pageWidth / CGFloat(columns))
        let columnGap = columns > 1 ? max(pageWidth - itemWidth * CGFloat(columns), 0) / CGFloat(columns - 1) : 0
        for index in 0..<count {
            let page = index / pageSize
            let slot = index % pageSize
            let column = slot % columns
            let row = slot / columns
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
            attributes.frame = CGRect(
                x: CGFloat(page) * pageWidth + CGFloat(column) * (itemWidth + columnGap),
                y: CGFloat(row) * (itemHeight + rowSpacing),
                width: itemWidth,
                height: itemHeight
            )
            cachedAttributes.append(attributes)
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard cachedAttributes.indices.contains(indexPath.item) else { return nil }
        return cachedAttributes[indexPath.item]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return newBounds.size != collectionView?.bounds.size
    }
}

// MARK: - MorePanelCell

private final class MorePanelCell: UICollectionViewCell {
    static let reuseID = "MorePanelCell"

    private let iconTileView = UIView()

    private let iconImageView = UIImageView()

    private let titleLabel = UILabel()

    private let redDotView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        LanguageHelper.applyLayoutDirection(to: self)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: UIImage?, title: String, showRedDot: Bool, appearance: MessageInputMorePanelAppearance?, index: Int) {
        let colors = TUIChatKitTheme.colors
        iconImageView.image = icon
        iconImageView.tintColor = appearance?.itemIconTint ?? colors.textColorPrimary
        titleLabel.text = title
        titleLabel.textColor = appearance?.itemTitleColor ?? colors.textColorSecondary
        titleLabel.font = UIFont.systemFont(ofSize: MessageInputAppearanceApplier.dimension(
            appearance?.itemTitleSize, fallback: FontScheme.caption3Regular.pointSize))
        redDotView.isHidden = !showRedDot
        let size = MessageInputAppearanceApplier.dimension(appearance?.itemSize, fallback: MessageInputMorePanel.iconSize)
        let iconSize = MessageInputAppearanceApplier.dimension(appearance?.itemIconSize, fallback: MessageInputMorePanel.iconGlyphSize)
        iconTileView.snp.updateConstraints { make in make.width.height.equalTo(size) }
        iconImageView.snp.updateConstraints { make in make.width.height.equalTo(min(iconSize, size)) }
        iconTileView.layer.cornerRadius = MessageInputAppearanceApplier.cornerRadius(
            appearance?.itemCornerRadius, fallback: MessageInputMorePanel.iconTileCornerRadius,
            size: CGSize(width: size, height: size))
        let fills = appearance?.itemFills ?? []
        let fill = fills.isEmpty ? nil : fills[index % fills.count]
        MessageInputAppearanceApplier.apply(fill: fill, to: iconTileView, defaultColor: colors.bgColorInput)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        MessageInputAppearanceApplier.update(iconTileView)
    }

    private func setupCell() {
        let colors = TUIChatKitTheme.colors

        iconTileView.backgroundColor = colors.bgColorInput
        iconTileView.layer.cornerRadius = MessageInputMorePanel.iconTileCornerRadius
        iconTileView.layer.masksToBounds = true
        contentView.addSubview(iconTileView)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = colors.textColorPrimary
        iconTileView.addSubview(iconImageView)

        titleLabel.font = FontScheme.caption3Regular
        titleLabel.textColor = colors.textColorSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(titleLabel)

        // Sits on contentView rather than inside the tile, whose masksToBounds
        // would clip it.
        redDotView.backgroundColor = colors.textColorError
        redDotView.layer.cornerRadius = MessageInputMorePanel.redDotSize / 2
        redDotView.isUserInteractionEnabled = false
        redDotView.isHidden = true
        contentView.addSubview(redDotView)

        iconTileView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(MessageInputMorePanel.iconSize)
        }

        redDotView.snp.makeConstraints { make in
            make.top.equalTo(iconTileView.snp.top)
            make.trailing.equalTo(iconTileView.snp.trailing)
            make.width.height.equalTo(MessageInputMorePanel.redDotSize)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(MessageInputMorePanel.iconGlyphSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconTileView.snp.bottom).offset(MessageInputMorePanel.titleTopSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(MessageInputMorePanel.titleAreaHeight)
        }
    }
}
