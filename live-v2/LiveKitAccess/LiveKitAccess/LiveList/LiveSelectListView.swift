import AtomicXCore
import UIKit

protocol LiveSelectListViewDelegate: AnyObject {
    func liveSelectListView(_ view: LiveSelectListView, didSelect liveInfo: LiveInfo)
}

// 从 TUILiveKit 业务库迁移到接入层的两列瀑布流直播选择列表。对齐 Android：该列表属于接入 App（WaterfallActivity），
// 不属于业务库。数据由接入层自带的 LiveSelectListStore 直接调用 AtomicXCore 获取。
final class LiveSelectListView: UIView {
    weak var delegate: LiveSelectListViewDelegate?

    private let store = LiveSelectListStore()
    private let dataSource = LiveSelectListDataSource()
    private let collectionView: UICollectionView
    private let refreshControl = UIRefreshControl()
    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        configureUI()
        bindStore()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        store.refresh()
    }

    private func configureUI() {
        backgroundColor = LiveListPalette.background
        collectionView.backgroundColor = LiveListPalette.background
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.register(
            LiveSelectListItemView.self,
            forCellWithReuseIdentifier: LiveSelectListItemView.reuseIdentifier
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        statusLabel.textColor = LiveListPalette.secondaryText
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func bindStore() {
        store.onStateChanged = { [weak self] state in
            guard let self else { return }
            if !state.isLoading {
                self.dataSource.liveList = state.liveList
                self.collectionView.reloadData()
                self.refreshControl.endRefreshing()
            }
            self.statusLabel.text = state.errorMessage ?? (state.isLoading ? "加载中…" : "暂无直播")
            self.statusLabel.isHidden = !state.liveList.isEmpty
        }
    }

    @objc private func refresh() {
        store.refresh()
    }
}

extension LiveSelectListView: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 10 - 24) / 2)
        return CGSize(width: width, height: width * 1.35)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard dataSource.liveList.indices.contains(indexPath.item) else { return }
        delegate?.liveSelectListView(self, didSelect: dataSource.liveList[indexPath.item])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let remaining = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height
        if remaining < 200 {
            store.loadMore()
        }
    }
}

final class LiveSelectListDataSource: NSObject, UICollectionViewDataSource {
    var liveList: [LiveInfo] = []

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        liveList.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LiveSelectListItemView.reuseIdentifier,
            for: indexPath
        ) as? LiveSelectListItemView else {
            return UICollectionViewCell()
        }
        cell.bind(liveList[indexPath.item])
        return cell
    }
}
