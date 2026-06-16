import AlbumPickerCore
import UIKit

internal protocol WhatsAppAddMoreRowDelegate: AnyObject {
    func addMoreRowDidTapConfirm(_ row: WhatsAppBottomAddMoreRow)
}

internal class WhatsAppBottomAddMoreRow: UIView {

    private static let rowHeight: CGFloat = 70
    private static let thumbnailSize: CGFloat = 48
    private static let confirmButtonSize: CGFloat = 44
    private static let sendIconSize: CGFloat = 20
    private static let cellIdentifier = "AddMoreThumbnailCell"

    internal weak var delegate: WhatsAppAddMoreRowDelegate?

    private let store: AlbumPickerStore
    private let theme = AlbumPickerCoreTheme.shared
    private var medias: [AlbumMediaModel] = []
    private var collectionView: UICollectionView!

    internal init(store: AlbumPickerStore) {
        self.store = store
        super.init(frame: .zero)
        isHidden = true
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func show(medias: [AlbumMediaModel]) {
        guard !medias.isEmpty else { return }
        self.medias = medias
        collectionView.reloadData()
        isHidden = false
        scrollToLast()
    }

    internal func hide() {
        isHidden = true
    }

    internal func update(medias: [AlbumMediaModel]) {
        if medias.isEmpty {
            hide()
        } else {
            self.medias = medias
            collectionView.reloadData()
            scrollToLast()
        }
    }
}

private extension WhatsAppBottomAddMoreRow {
    func setupViews() {
        collectionView = createCollectionView()
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        let confirmBtn = createConfirmButton()
        addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { make in
            make.leading.equalTo(collectionView.snp.trailing)
                .offset(AlbumPickerCoreTheme.spacing8)
            make.trailing.equalToSuperview().offset(
                -AlbumPickerCoreTheme.spacing8
            )
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.confirmButtonSize)
        }

        snp.makeConstraints { make in
            make.height.equalTo(Self.rowHeight)
        }
    }

    func createCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = AlbumPickerCoreTheme.spacing6
        layout.itemSize = CGSize(
            width: Self.thumbnailSize,
            height: Self.thumbnailSize
        )
        let verticalPadding =
            (Self.rowHeight - Self.thumbnailSize) / 2
        layout.sectionInset = UIEdgeInsets(
            top: verticalPadding, left: AlbumPickerCoreTheme.spacing8,
            bottom: verticalPadding, right: AlbumPickerCoreTheme.spacing8
        )

        let cv = UICollectionView(
            frame: .zero, collectionViewLayout: layout
        )
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(
            AddMoreThumbnailCell.self,
            forCellWithReuseIdentifier: Self.cellIdentifier
        )
        return cv
    }

    func createConfirmButton() -> UIView {
        let container = UIView()
        container.backgroundColor = theme.currentPrimaryColor
        container.layer.cornerRadius = Self.confirmButtonSize / 2
        container.clipsToBounds = true

        let iconView = UIImageView()
        iconView.image = theme.confirmButtonIcon
            ?? UIImage(systemName: "checkmark")
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.sendIconSize)
        }

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleConfirm)
        )
        container.addGestureRecognizer(tap)
        return container
    }

    func scrollToLast() {
        guard !medias.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let currentCount = collectionView.numberOfItems(inSection: 0)
            guard currentCount > 0 else { return }
            collectionView.scrollToItem(
                at: IndexPath(item: currentCount - 1, section: 0),
                at: .right,
                animated: true
            )
        }
    }

    @objc func handleConfirm() {
        delegate?.addMoreRowDidTapConfirm(self)
    }
}

extension WhatsAppBottomAddMoreRow: UICollectionViewDataSource {
    internal func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        medias.count
    }

    internal func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.cellIdentifier,
            for: indexPath
        ) as? AddMoreThumbnailCell else {
            return UICollectionViewCell()
        }
        guard indexPath.item < medias.count
        else { return cell }
        cell.configure(
            with: medias[indexPath.item], store: store
        )
        return cell
    }
}

extension WhatsAppBottomAddMoreRow: UICollectionViewDelegate {}

private class AddMoreThumbnailCell: UICollectionViewCell {

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius =
            AlbumPickerCoreTheme.shared.normalRadius
        return imageView
    }()

    private var currentMediaId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        currentMediaId = nil
    }

    fileprivate func configure(with media: AlbumMediaModel, store: AlbumPickerStore) {
        currentMediaId = media.id
        store.loadMediaThumbnail(for: media) { [weak self] image in
            guard self?.currentMediaId == media.id
            else { return }
            self?.imageView.image = image
        }
    }
}
