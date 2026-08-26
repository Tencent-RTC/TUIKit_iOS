import UIKit
import SnapKit
import Kingfisher

final class ChatBackgroundPickerViewController: UIViewController {
    private static let panelHeightRatio: CGFloat = 0.65

    private static let panelCornerRadius: CGFloat = CGFloat(RadiusScheme.largeRadius)

    private static let headerHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerVerticalPadding: CGFloat = 14

    private static let closeButtonSize: CGFloat = 32

    private static let columnCount: CGFloat = 2

    private static let gridPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let cellSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let previewHeight: CGFloat = 120

    private static let dimAlpha: CGFloat = 0.4

    private let conversationID: String

    private let onSelected: (String?) -> Void

    private let items = ChatBackgroundPresetProvider.presetItems()

    private let selectedURI: String?

    private let dimView = UIControl()

    private let panelView = UIView()

    private let titleLabel = UILabel()

    private let closeButton = UIButton(type: .custom)

    private var collectionView: UICollectionView?

    init(conversationID: String, onSelected: @escaping (String?) -> Void) {
        self.conversationID = conversationID
        self.onSelected = onSelected
        self.selectedURI = ChatBackgroundStore.shared.imageURI(forConversationID: conversationID)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    private func constructViewHierarchy() {
        view.addSubview(dimView)
        view.addSubview(panelView)
        panelView.addSubview(titleLabel)
        panelView.addSubview(closeButton)
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Self.cellSpacing
        layout.minimumLineSpacing = Self.cellSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Self.gridPadding,
            bottom: Self.gridPadding,
            right: Self.gridPadding
        )
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(ChatBackgroundPreviewCell.self, forCellWithReuseIdentifier: ChatBackgroundPreviewCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        self.collectionView = collectionView
        panelView.addSubview(collectionView)
    }

    private func activateConstraints() {
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        panelView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(UIScreen.main.bounds.height * Self.panelHeightRatio)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(Self.headerVerticalPadding)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.headerHorizontalPadding)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(Self.closeButtonSize)
        }
        collectionView?.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.headerVerticalPadding)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func bindInteraction() {
        dimView.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(Self.dimAlpha)
        panelView.backgroundColor = colors.bgColorOperate
        panelView.layer.cornerRadius = Self.panelCornerRadius
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.layer.masksToBounds = true
        titleLabel.text = LocalizedChatString("SelectChatBackground")
        titleLabel.font = FontScheme.caption1Bold
        titleLabel.textColor = colors.textColorPrimary
        closeButton.setTitle("×", for: .normal)
        closeButton.setTitleColor(colors.textColorSecondary, for: .normal)
        closeButton.titleLabel?.font = FontScheme.body3Regular
        collectionView?.backgroundColor = colors.bgColorOperate
    }

    @objc private func handleDismiss() {
        dismiss(animated: true)
    }

    private func isItemSelected(_ item: ChatBackgroundPresetItem) -> Bool {
        if item.isDefault {
            return selectedURI == nil
        }
        return item.imageURI == selectedURI
    }
}

extension ChatBackgroundPickerViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ChatBackgroundPreviewCell.reuseIdentifier,
            for: indexPath
        ) as? ChatBackgroundPreviewCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: items[indexPath.item], isSelected: isItemSelected(items[indexPath.item]))
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let totalSpacing = Self.gridPadding * 2 + Self.cellSpacing * (Self.columnCount - 1)
        let width = (collectionView.bounds.width - totalSpacing) / Self.columnCount
        return CGSize(width: width, height: Self.previewHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelected(items[indexPath.item].imageURI)
        dismiss(animated: true)
    }
}

final class ChatBackgroundPreviewCell: UICollectionViewCell {
    static let reuseIdentifier = "ChatBackgroundPreviewCell"

    private static let contentCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let selectedBorderWidth: CGFloat = 2

    private let previewImageView = UIImageView()

    private let defaultLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(previewImageView)
        contentView.addSubview(defaultLabel)
        previewImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        defaultLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        let colors = ChatUIKitTheme.colors
        contentView.backgroundColor = colors.bgColorTopBar
        contentView.layer.cornerRadius = Self.contentCornerRadius
        contentView.layer.masksToBounds = true
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        defaultLabel.font = FontScheme.caption2Regular
        defaultLabel.textColor = colors.textColorSecondary
        defaultLabel.text = LocalizedChatString("ChatBackgroundDefault")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ChatBackgroundPresetItem, isSelected: Bool) {
        let colors = ChatUIKitTheme.colors
        contentView.layer.borderWidth = isSelected ? Self.selectedBorderWidth : 0
        contentView.layer.borderColor = isSelected ? colors.buttonColorPrimaryDefault.cgColor : nil
        if item.isDefault {
            previewImageView.isHidden = true
            previewImageView.image = nil
            defaultLabel.isHidden = false
        } else {
            defaultLabel.isHidden = true
            previewImageView.isHidden = false
            if let thumbnail = item.thumbnailURI {
                previewImageView.kf.setImage(with: URL(string: thumbnail))
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.kf.cancelDownloadTask()
        previewImageView.image = nil
        contentView.layer.borderWidth = 0
    }
}
