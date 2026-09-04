import UIKit
import SnapKit
import Kingfisher

final class AvatarPickerSheetController: UIViewController {
    private static let panelHeightRatio: CGFloat = 0.6

    private static let panelCornerRadius: CGFloat = CGFloat(RadiusScheme.largeRadius)

    private static let headerHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let headerVerticalPadding: CGFloat = 14

    private static let titleFontSize: CGFloat = 16

    private static let closeButtonSize: CGFloat = 32

    private static let closeSymbolFontSize: CGFloat = 18

    private static let gridPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    fileprivate static let cellAvatarSize: CGFloat = 64

    private static let cellAvatarPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let cellAvatarCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let dimAlpha: CGFloat = 0.4

    private let imageUrlList: [String]

    private let columnCount: Int

    private let onImageSelected: (String) -> Void

    private let dimView = UIControl()

    private let panelView = UIView()

    private let titleLabel = UILabel()

    private let closeButton = UIButton(type: .custom)

    private var collectionView: UICollectionView?

    init(title: String, imageUrlList: [String], columnCount: Int = 4, onImageSelected: @escaping (String) -> Void) {
        self.imageUrlList = imageUrlList
        self.columnCount = max(1, columnCount)
        self.onImageSelected = onImageSelected
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        titleLabel.text = title
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
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Self.gridPadding,
            bottom: Self.gridPadding,
            right: Self.gridPadding
        )
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(AvatarPickerSheetCell.self, forCellWithReuseIdentifier: AvatarPickerSheetCell.reuseIdentifier)
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
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(Self.dimAlpha)
        panelView.backgroundColor = colors.bgColorOperate
        panelView.layer.cornerRadius = Self.panelCornerRadius
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.layer.masksToBounds = true

        titleLabel.font = UIFont.systemFont(ofSize: Self.titleFontSize, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary

        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(colors.textColorSecondary, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: Self.closeSymbolFontSize)

        collectionView?.backgroundColor = colors.bgColorOperate
    }

    @objc private func handleDismiss() {
        dismiss(animated: true)
    }
}

extension AvatarPickerSheetController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageUrlList.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AvatarPickerSheetCell.reuseIdentifier,
            for: indexPath
        ) as? AvatarPickerSheetCell else {
            return UICollectionViewCell()
        }
        cell.configure(imageUrl: imageUrlList[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageUrl = imageUrlList[indexPath.item]
        dismiss(animated: true) { [onImageSelected] in
            onImageSelected(imageUrl)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let totalPadding = Self.gridPadding * 2
        let itemWidth = floor((collectionView.bounds.width - totalPadding) / CGFloat(columnCount))
        let itemHeight = Self.cellAvatarSize + Self.cellAvatarPadding * 2
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

private final class AvatarPickerSheetCell: UICollectionViewCell {
    static let reuseIdentifier = "AvatarPickerSheetCell"

    private let avatarImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(AvatarPickerSheetController.cellAvatarSize)
        }
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = AvatarPickerSheetController.cellAvatarCornerRadius
        avatarImageView.layer.masksToBounds = true
        avatarImageView.backgroundColor = TUIChatKitTheme.colors.bgColorInput
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = nil
    }

    func configure(imageUrl: String) {
        avatarImageView.kf.setImage(with: URL(string: imageUrl))
    }
}
