import UIKit
import SnapKit
import AtomicXCore

final class ReactionEmojiPickerViewController: UIViewController {
    private static let heightScreenRatio: CGFloat = 0.6

    private static let minHeight: CGFloat = 400

    private static let maxHeight: CGFloat = 520

    private static let topCornerRadius = CGFloat(RadiusScheme.superLargeRadius)

    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)

    private static let bottomPadding = CGFloat(SpacingScheme.normalSpacing)

    private static let dragHandleAreaHeight: CGFloat = 32

    private static let dragHandleWidth: CGFloat = 40

    private static let dragHandleHeight: CGFloat = 16

    private static let dismissDragThresholdRatio: CGFloat = 0.15

    private static let dragAnimationDuration: TimeInterval = 0.18

    private static let presentAnimationDuration: TimeInterval = 0.25

    private static let backdropDimAlpha: CGFloat = 0.32

    private static let columns: CGFloat = 8

    private static let cellHeight: CGFloat = 44

    private static let emojiGlyphSize: CGFloat = 32

    private static let headerVerticalPadding = CGFloat(SpacingScheme.smallSpacing)

    private static let headerHeight: CGFloat = 12 + headerVerticalPadding * 2

    private let message: MessageInfo

    private let backdropView = UIView()

    private let sheetView = UIView()

    private let dragHandleArea = UIView()

    private var collectionView: UICollectionView!

    private var sections: [(title: String, emojis: [EmojiData])] = []

    private var sheetHeight: CGFloat = 0

    private var hasAnimatedIn = false

    static func present(message: MessageInfo) {
        guard let presenter = topViewController() else { return }
        let controller = ReactionEmojiPickerViewController(message: message)
        controller.modalPresentationStyle = .overFullScreen
        presenter.present(controller, animated: false)
    }

    private init(message: MessageInfo) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSections()
        constructViewHierarchy()
        setupViewStyle()
        bindInteraction()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    private func buildSections() {
        let allEmojis = EmojiManager.shared.getPickerEmojis()
        let emojiByName = Dictionary(uniqueKeysWithValues: allEmojis.compactMap { emoji -> (String, EmojiData)? in
            guard let name = emoji.name else { return nil }
            return (name, emoji)
        })
        let recentNames = EmojiManager.shared.getRecentEmojis(groupID: EmojiManager.shared.reactionGroupID())
        let recentEmojis = recentNames.compactMap { emojiByName[$0] }
        if !recentEmojis.isEmpty {
            sections.append((LocalizedChatString("ReactionRecentUsed"), recentEmojis))
        }
        if !allEmojis.isEmpty {
            sections.append((LocalizedChatString("ReactionAllEmojis"), allEmojis))
        }
    }

    private func constructViewHierarchy() {
        view.addSubview(backdropView)
        backdropView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(sheetView)
        sheetView.addSubview(dragHandleArea)

        let handleIcon = UIImageView()
        handleIcon.contentMode = .scaleAspectFit
        handleIcon.tintColor = ChatUIKitTheme.colors.strokeColorPrimary
        handleIcon.image = AtomicXChatResources.image(named: "message_chevron_down")?.withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "chevron.down")
        handleIcon.isUserInteractionEnabled = false
        dragHandleArea.addSubview(handleIcon)
        handleIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(Self.dragHandleWidth)
            make.height.equalTo(Self.dragHandleHeight)
        }

        let layout = ReactionPickerFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(ReactionPickerEmojiCell.self, forCellWithReuseIdentifier: ReactionPickerEmojiCell.reuseID)
        collectionView.register(
            ReactionPickerHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ReactionPickerHeaderView.reuseID
        )
        sheetView.addSubview(collectionView)

        dragHandleArea.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.dragHandleAreaHeight)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(dragHandleArea.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.bottom.equalToSuperview().offset(-Self.bottomPadding)
        }
    }

    private func setupViewStyle() {
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(Self.backdropDimAlpha)
        backdropView.alpha = 0
        sheetView.backgroundColor = ChatUIKitTheme.colors.bgColorDialog
        sheetView.layer.cornerRadius = Self.topCornerRadius
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.layer.masksToBounds = true
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
    }

    private func bindInteraction() {
        collectionView.dataSource = self
        collectionView.delegate = self
        backdropView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleHandleTap))
        dragHandleArea.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDragPan(_:)))
        dragHandleArea.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let windowHeight = view.bounds.height
        guard windowHeight > 0 else { return }
        let target = min(max(windowHeight * Self.heightScreenRatio, Self.minHeight), Self.maxHeight)
        if sheetHeight != target {
            sheetHeight = target
            if sheetView.frame == .zero {
                sheetView.frame = CGRect(x: 0, y: windowHeight, width: view.bounds.width, height: sheetHeight)
            } else if hasAnimatedIn {
                sheetView.frame = CGRect(x: 0, y: windowHeight - sheetHeight, width: view.bounds.width, height: sheetHeight)
            }
        }
    }

    private func animateIn() {
        hasAnimatedIn = true
        backdropView.alpha = 0
        UIView.animate(withDuration: Self.presentAnimationDuration, delay: 0, options: [.curveEaseOut]) {
            self.backdropView.alpha = 1
            self.sheetView.frame = CGRect(
                x: 0,
                y: self.view.bounds.height - self.sheetHeight,
                width: self.view.bounds.width,
                height: self.sheetHeight
            )
        }
    }

    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: Self.dragAnimationDuration, delay: 0, options: [.curveEaseIn]) {
            self.backdropView.alpha = 0
            self.sheetView.frame = CGRect(
                x: 0,
                y: self.view.bounds.height,
                width: self.view.bounds.width,
                height: self.sheetHeight
            )
        } completion: { _ in
            completion()
        }
    }

    @objc private func handleBackdropTap() {
        animateOut { [weak self] in self?.dismiss(animated: false) }
    }

    @objc private func handleHandleTap() {
        animateOut { [weak self] in self?.dismiss(animated: false) }
    }

    @objc private func handleDragPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .changed:
            guard translation.y > 0 else { return }
            sheetView.frame.origin.y = view.bounds.height - sheetHeight + translation.y
        case .ended, .cancelled:
            let dismissed = translation.y >= sheetHeight * Self.dismissDragThresholdRatio
            if dismissed {
                animateOut { [weak self] in self?.dismiss(animated: false) }
            } else {
                UIView.animate(withDuration: Self.dragAnimationDuration) {
                    self.sheetView.frame.origin.y = self.view.bounds.height - self.sheetHeight
                }
            }
        default:
            break
        }
    }

    private func handleEmojiSelected(_ emoji: EmojiData) {
        guard let name = emoji.name else { return }
        let hasReacted = message.reactionList.contains { $0.reactionID == name && $0.reactedByMyself }
        if !hasReacted {
            EmojiManager.shared.addRecentEmoji(emoji, groupID: EmojiManager.shared.reactionGroupID())
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("messageReactionToggle"),
            object: nil,
            userInfo: ["message": message, "reactionID": name]
        )
        animateOut { [weak self] in self?.dismiss(animated: false) }
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - UICollectionViewDataSource

extension ReactionEmojiPickerViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].emojis.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ReactionPickerEmojiCell.reuseID, for: indexPath
        ) as? ReactionPickerEmojiCell ?? ReactionPickerEmojiCell()
        cell.configure(with: sections[indexPath.section].emojis[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ReactionPickerHeaderView.reuseID,
            for: indexPath
        ) as? ReactionPickerHeaderView ?? ReactionPickerHeaderView()
        header.configure(title: sections[indexPath.section].title)
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ReactionEmojiPickerViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width) / Self.columns)
        return CGSize(width: width, height: Self.cellHeight)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: Self.headerHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleEmojiSelected(sections[indexPath.section].emojis[indexPath.item])
    }
}

// MARK: - Cell / Header / Layout

private final class ReactionPickerEmojiCell: UICollectionViewCell {
    static let reuseID = "ReactionPickerEmojiCell"

    private static let glyphSize: CGFloat = 32

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.glyphSize)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with emoji: EmojiData) {
        imageView.image = ReactionEmojiRenderer.image(for: emoji)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}

private final class ReactionPickerHeaderView: UICollectionReusableView {
    static let reuseID = "ReactionPickerHeaderView"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = FontScheme.caption3Regular
        titleLabel.textColor = ChatUIKitTheme.colors.textColorSecondary
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
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

private final class ReactionPickerFlowLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        return true
    }
}
