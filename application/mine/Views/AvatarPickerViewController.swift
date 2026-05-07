//
//  AvatarPickerViewController.swift
//  mine
//
//       https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_N.png, N ∈ [1, 26]。
//

import UIKit
import SnapKit
import Kingfisher
import AtomicX

enum AvatarPickerURLs {
    static let count = 26

    static func url(at index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\(index).png"
    }

    static var all: [String] {
        return (1...count).map { url(at: $0) }
    }
}

///
/// ```swift
/// let vc = AvatarPickerViewController()
/// vc.currentAvatarURL = profile?.faceURL
/// vc.onConfirm = { [weak self] url in ... }
/// navigationController?.pushViewController(vc, animated: true)
/// ```
final class AvatarPickerViewController: UIViewController {

    // MARK: - Public

    var currentAvatarURL: String?

    var onConfirm: ((String) -> Void)?

    // MARK: - Private State

    private let avatarURLs: [String] = AvatarPickerURLs.all

    private var initialMatchedIndex: Int?

    private var selectedIndex: Int?

    // MARK: - Layout Constants

    private let columnCount: Int = 4
    private let sectionInset: CGFloat = 16
    private let itemSpacing: CGFloat = 12

    // MARK: - UI

    private lazy var flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = itemSpacing
        layout.minimumInteritemSpacing = itemSpacing
        layout.sectionInset = UIEdgeInsets(
            top: sectionInset,
            left: sectionInset,
            bottom: sectionInset,
            right: sectionInset
        )
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        cv.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(AvatarPickerCell.self, forCellWithReuseIdentifier: AvatarPickerCell.reuseID)
        return cv
    }()

    private lazy var confirmButton: AtomicButton = {
        let button = AtomicButton(
            variant: .text,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: MineLocalize("Demo.TRTC.Portal.Mine.profileOK"))
        )
        button.setClickAction { [weak self] _ in
            self?.onConfirmTapped()
        }
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        syncSelectedIndex()
        updateConfirmButtonEnabled()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateItemSize()
    }

    // MARK: - Setup

    private func setupUI() {
        title = MineLocalize("Demo.TRTC.Portal.Mine.profilePhoto")
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: confirmButton)

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func updateConfirmButtonEnabled() {
        confirmButton.isEnabled = (selectedIndex != nil)
    }

    private func syncSelectedIndex() {
        guard let current = currentAvatarURL, !current.isEmpty else { return }
        if let idx = avatarURLs.firstIndex(of: current) {
            initialMatchedIndex = idx
        }
    }

    private func updateItemSize() {
        let totalWidth = collectionView.bounds.width
        guard totalWidth > 0 else { return }
        let available = totalWidth - sectionInset * 2 - itemSpacing * CGFloat(columnCount - 1)
        let side = floor(available / CGFloat(columnCount))
        guard side > 0, flowLayout.itemSize.width != side else { return }
        flowLayout.itemSize = CGSize(width: side, height: side)
        flowLayout.invalidateLayout()
    }

    // MARK: - Actions

    @objc private func onConfirmTapped() {
        guard let idx = selectedIndex else { return }
        onConfirm?(avatarURLs[idx])
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension AvatarPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return avatarURLs.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AvatarPickerCell.reuseID,
            for: indexPath
        ) as! AvatarPickerCell
        let url = avatarURLs[indexPath.item]
        let highlightIndex = selectedIndex ?? initialMatchedIndex
        cell.configure(url: url, selected: indexPath.item == highlightIndex)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previousHighlight = selectedIndex ?? initialMatchedIndex
        selectedIndex = indexPath.item
        var reloadPaths: [IndexPath] = [indexPath]
        if let prev = previousHighlight, prev != indexPath.item {
            reloadPaths.append(IndexPath(item: prev, section: 0))
        }
        collectionView.reloadItems(at: reloadPaths)
        updateConfirmButtonEnabled()
    }
}

// MARK: - Cell

private final class AvatarPickerCell: UICollectionViewCell {

    static let reuseID = "AvatarPickerCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return iv
    }()

    private let selectionOverlay: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 8
        v.layer.borderWidth = 0
        v.isUserInteractionEnabled = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectionOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        applyDefaultBorder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        applyDefaultBorder()
    }

    func configure(url: String, selected: Bool) {
        if let u = URL(string: url) {
            imageView.kf.setImage(with: u)
        } else {
            imageView.image = nil
        }

        if selected {
            selectionOverlay.layer.borderWidth = 3
            selectionOverlay.layer.borderColor =
                ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
        } else {
            applyDefaultBorder()
        }
    }

    private func applyDefaultBorder() {
        selectionOverlay.layer.borderWidth = 1
        selectionOverlay.layer.borderColor =
            ThemeStore.shared.colorTokens.strokeColorSecondary.cgColor
    }
}
