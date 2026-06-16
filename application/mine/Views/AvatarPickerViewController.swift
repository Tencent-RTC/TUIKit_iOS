//
//  AvatarPickerViewController.swift
//  mine
//
//  自研头像选择页 —— 替代第三方 TUISelectAvatarController。
//
//  设计目标：
//    1. 颜色/字体完全走 ThemeStore，支持 light / dark / system 三态切换；
//    2. 不依赖 TIMCommon / TUICore 的 UI 资源，只使用 AtomicX + Kingfisher；
//    3. 候选头像池与原 TUISelectAvatarController 保持一致：
//       https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_N.png, N ∈ [1, 26]。
//

import UIKit
import SnapKit
import Kingfisher
import AtomicX

// MARK: - 头像数据源

/// 候选头像 URL 集合。与原 `TUISelectAvatarController` 的 `userAvatar` 场景保持一致，
/// 以确保替换第三方实现后用户可见的候选头像不变。
enum AvatarPickerURLs {
    static let count = 26

    static func url(at index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\(index).png"
    }

    static var all: [String] {
        return (1...count).map { url(at: $0) }
    }
}

// MARK: - 视图控制器

/// 头像选择页。
///
/// 使用方式：
/// ```swift
/// let vc = AvatarPickerViewController()
/// vc.currentAvatarURL = profile?.faceURL
/// vc.onConfirm = { [weak self] url in ... }
/// navigationController?.pushViewController(vc, animated: true)
/// ```
final class AvatarPickerViewController: UIViewController {

    // MARK: - Public

    /// 当前选中的头像 URL，用于进入页面时高亮已有头像。
    var currentAvatarURL: String?

    /// 用户点击"确认"后回调，参数为最终选择的头像 URL。
    var onConfirm: ((String) -> Void)?

    // MARK: - Private State

    private let avatarURLs: [String] = AvatarPickerURLs.all

    /// 进入页面时根据 `currentAvatarURL` 匹配到候选池的下标，仅用于 cell 的"已有头像"高亮预览。
    /// 它不代表用户在本次会话中的"选择"，因此不会让右上角确认按钮变为可点态。
    private var initialMatchedIndex: Int?

    /// 用户在本次会话中主动点击选择的头像下标。
    /// 仅当它非空时，右上角确认按钮才可点击。对齐原 `TUISelectAvatarController`
    /// 的 `currentSelectCardItem` 语义：初始为 nil，必须有点击动作后才会赋值。
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

    /// 右上角"确认"按钮。
    ///
    /// 行为对齐原 `TUISelectAvatarController`：
    /// - 未选中任何头像时，按钮 `isEnabled = false`，点击无响应；
    /// - 选中某张头像后，按钮 `isEnabled = true`，可点击提交。
    ///
    /// 使用 `AtomicButton` 的 `.text / .primary / .xsmall` 预设：
    /// - 可用态文字走 `buttonColorPrimaryDefault`（主色蓝）；
    /// - 禁用态文字由 `AtomicButton` 内部自动切换为 `buttonColorPrimaryDisabled`（淡化主色），
    ///   这是 AtomicX 设计体系里"主色按钮禁用态"的标准语义；
    /// - 字体与主题切换均由 `AtomicButton` 内部订阅 `ThemeStore` 自动生效，无需手动刷新。
    private lazy var confirmButton: AtomicButton = {
        let button = AtomicButton(
            variant: .text,
            colorType: .primary,
            size: .xsmall,
            content: .textOnly(text: MineLocalize("mine_profile_btn_confirm"))
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
        title = MineLocalize("mine_profile_avatar")
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: confirmButton)

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    /// 根据 `selectedIndex` 刷新确认按钮的可用态。
    ///
    /// 颜色切换逻辑交给 `AtomicButton` 内部（`isEnabled` 变化时自动在
    /// `buttonColorPrimaryDefault` 与 `buttonColorPrimaryDisabled` 之间切换），
    /// 这里只负责设置业务语义的 `isEnabled`。
    private func updateConfirmButtonEnabled() {
        confirmButton.isEnabled = (selectedIndex != nil)
    }

    /// 根据 `currentAvatarURL` 匹配候选池下标，仅用于在 cell 上高亮"已有头像"，
    /// 不会影响右上角确认按钮的可点状态。
    private func syncSelectedIndex() {
        guard let current = currentAvatarURL, !current.isEmpty else { return }
        if let idx = avatarURLs.firstIndex(of: current) {
            initialMatchedIndex = idx
        }
    }

    /// 根据容器宽度计算每个 item 的正方形边长。
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

    /// 确认按钮点击。
    ///
    /// 对齐原 `TUISelectAvatarController.rightBarButtonClick` 的语义：
    /// 未选中任何头像时，点击无效（不回调、不 pop）。这里通过 `isEnabled = false`
    /// 在 UI 层就阻止了点击，此处仅做兜底，避免竞态情况下 `selectedIndex` 为空仍触发。
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
        // 用户已主动选择则以用户选择为准，否则显示"已有头像"的预览高亮
        let highlightIndex = selectedIndex ?? initialMatchedIndex
        cell.configure(url: url, selected: indexPath.item == highlightIndex)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 首次点击：之前的高亮可能来自 initialMatchedIndex，需要把它一起刷新为未选态
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

/// 单个头像方块。通过 `ThemeStore` 的 `buttonColorPrimaryDefault` 高亮选中态边框，
/// 未选中态使用 `strokeColorSecondary`，整体背景与主题背景一致。
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
