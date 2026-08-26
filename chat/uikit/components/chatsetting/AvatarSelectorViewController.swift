import Kingfisher
import SnapKit
import UIKit

public final class AvatarSelectorViewController: ChatSettingBaseViewController {
    private static let gridPadding: CGFloat = 10

    private static let cellSpacing: CGFloat = 10

    fileprivate static let cellCornerRadius: CGFloat = 10

    fileprivate static let selectedBorderWidth: CGFloat = 3

    fileprivate static let checkmarkSize: CGFloat = 24

    fileprivate static let checkmarkInset: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let contentTopSpacing: CGFloat = 10

    private static let contentBottomSpacing: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private let imageUrlList: [String]

    private let column: Int

    private let onComplete: (String?) -> Void

    private var selectedImageUrl: String? {
        didSet { doneButton.isEnabled = selectedImageUrl != nil }
    }

    private let doneButton = UIButton(type: .custom)

    private var collectionView: UICollectionView?

    public init(imageUrlList: [String], column: Int = 3, onComplete: @escaping (String?) -> Void) {
        self.imageUrlList = imageUrlList
        self.column = max(1, column)
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("ChooseAvatar"))
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        doneButton.addTarget(self, action: #selector(handleDoneTapped), for: .touchUpInside)
    }

    private func constructViewHierarchy() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Self.cellSpacing
        layout.minimumLineSpacing = Self.cellSpacing
        layout.sectionInset = UIEdgeInsets(
            top: Self.contentTopSpacing,
            left: Self.gridPadding,
            bottom: Self.contentBottomSpacing,
            right: Self.gridPadding
        )
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(AvatarSelectorCell.self, forCellWithReuseIdentifier: AvatarSelectorCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        self.collectionView = collectionView
        view.addSubview(collectionView)
        view.addSubview(doneButton)
    }

    private func activateConstraints() {
        collectionView?.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        collectionView?.backgroundColor = colors.bgColorOperate
        doneButton.setTitle(LocalizedChatString("Done"), for: .normal)
        doneButton.setTitleColor(colors.textColorLink, for: .normal)
        doneButton.setTitleColor(colors.textColorTertiary, for: .disabled)
        doneButton.titleLabel?.font = FontScheme.caption1Regular
        doneButton.isEnabled = false
        setNavTrailingView(doneButton)
    }

    @objc private func handleDoneTapped() {
        onComplete(selectedImageUrl)
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension AvatarSelectorViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageUrlList.count
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AvatarSelectorCell.reuseIdentifier,
            for: indexPath
        ) as? AvatarSelectorCell else {
            return UICollectionViewCell()
        }
        let imageUrl = imageUrlList[indexPath.item]
        cell.configure(imageUrl: imageUrl, isSelected: imageUrl == selectedImageUrl)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedImageUrl = imageUrlList[indexPath.item]
        collectionView.reloadData()
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let totalSpacing = Self.gridPadding * 2 + Self.cellSpacing * CGFloat(column - 1)
        let itemWidth = floor((collectionView.bounds.width - totalSpacing) / CGFloat(column))
        return CGSize(width: itemWidth, height: itemWidth)
    }
}

private final class AvatarSelectorCell: UICollectionViewCell {
    static let reuseIdentifier = "AvatarSelectorCell"

    private let avatarImageView = UIImageView()

    private let selectionBorderView = UIView()

    private let checkmarkImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = nil
    }

    func configure(imageUrl: String, isSelected: Bool) {
        avatarImageView.kf.setImage(with: URL(string: imageUrl))
        selectionBorderView.isHidden = !isSelected
        checkmarkImageView.isHidden = !isSelected
    }

    private func constructViewHierarchy() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(selectionBorderView)
        contentView.addSubview(checkmarkImageView)
    }

    private func activateConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectionBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        checkmarkImageView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(AvatarSelectorViewController.checkmarkInset)
            make.width.height.equalTo(AvatarSelectorViewController.checkmarkSize)
        }
    }

    private func setupViewStyle() {
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = AvatarSelectorViewController.cellCornerRadius
        avatarImageView.layer.masksToBounds = true
        avatarImageView.backgroundColor = ChatUIKitTheme.colors.bgColorInput
        selectionBorderView.layer.cornerRadius = AvatarSelectorViewController.cellCornerRadius
        selectionBorderView.layer.borderWidth = AvatarSelectorViewController.selectedBorderWidth
        selectionBorderView.layer.borderColor = ChatUIKitTheme.colors.textColorLink.cgColor
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = ChatUIKitTheme.colors.textColorLink
    }
}
