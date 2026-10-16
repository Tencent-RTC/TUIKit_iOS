import AtomicXCore
import Combine
import SnapKit
import UIKit

enum SwipeBehavior {
    case previewOnly
    case autoEnterRoom
}

@MainActor
final class PagerView: UIView, UICollectionViewDelegate {
    var onClose: (() -> Void)?
    var onLoadMore: (() -> Void)?

    private static let loadMoreThreshold = 2

    private let initialLiveID: String
    private let collectionView: UICollectionView
    private var adapter: InnerAdapter!

    private var currentItemID: String?
    private var pendingSlideInItemIDs: Set<String> = []
    private var didEmitWillSlideOut = false
    private var needsReloadAfterScroll = false
    private var currentPageDidLeaveScreen = false

    private var swipeBehavior = SwipeBehavior.previewOnly {
        didSet {
            guard swipeBehavior != oldValue else { return }
            applyJoinLiveEntranceEnabled()
        }
    }
    private var swipeDisabledByJoin = false
    private var swipeDisabledByCoGuest = false
    private var currentPlayerStatusCancellable: AnyCancellable?
    private weak var currentPageCell: PageCell?
    private weak var slidingInPageCell: PageCell?
    private weak var slidingOutPageCell: PageCell?

    init(initialLiveID: String = "") {
        self.initialLiveID = initialLiveID
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: PagerLayout())
        super.init(frame: .zero)
        adapter = InnerAdapter(owner: self)
        configureCollectionView()
        prependInitialLiveIDIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            onDetached()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateVisibleItemSafeAreas()
    }

    func setData(_ list: [LiveInfo]) {
        let merged = mergeWithInitialLiveID(deduplicated(list))
        adapter.setData(merged)

        guard adapter.count > 0 else {
            collectionView.reloadData()
            currentItemID = nil
            needsReloadAfterScroll = false
            return
        }

        if isScrolling {
            needsReloadAfterScroll = true
            return
        }

        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        resyncCurrentItemIDIfMissing()
    }

    func appendData(_ list: [LiveInfo]) {
        let deduped = deduplicated(list)
        guard !deduped.isEmpty else { return }

        var existingIndexByID: [String: Int] = [:]
        for (index, info) in adapter.dataList.enumerated() {
            existingIndexByID[info.liveID] = index
        }

        var toAppend: [LiveInfo] = []
        toAppend.reserveCapacity(deduped.count)
        for info in deduped {
            if let index = existingIndexByID[info.liveID] {
                adapter.updateItem(at: index, with: info)
            } else {
                toAppend.append(info)
            }
        }

        guard !toAppend.isEmpty else { return }
        let start = adapter.count
        adapter.appendData(toAppend)
        let indexPaths = (start..<adapter.count).map { IndexPath(item: $0, section: 0) }
        collectionView.insertItems(at: indexPaths)
    }

    func onDetached() {
        adapter.forEachPage { $0.stopAndLeaveChannel() }
        currentPageCell = nil
        slidingInPageCell = nil
        slidingOutPageCell = nil
        stopObservingCurrentPlayerStatus()
        swipeBehavior = .previewOnly
    }

    private var currentItem: Int {
        guard collectionView.bounds.height > 0, adapter.count > 0 else { return 0 }
        let page = Int(round(collectionView.contentOffset.y / collectionView.bounds.height))
        return min(max(page, 0), adapter.count - 1)
    }

    private var isUserInputEnabled: Bool {
        get { collectionView.isScrollEnabled }
        set { collectionView.isScrollEnabled = newValue }
    }

    private var isScrolling: Bool {
        collectionView.isDragging || collectionView.isTracking || collectionView.isDecelerating
    }

    private func configureCollectionView() {
        backgroundColor = LiveTheme.Color.canvasBackground
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset = .zero
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPrefetchingEnabled = false
        collectionView.delegate = self
        collectionView.dataSource = adapter
        collectionView.register(PageContainerCell.self, forCellWithReuseIdentifier: PageContainerCell.reuseIdentifier)

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func makePageCell(_ liveInfo: LiveInfo) -> PageCell {
        let pageCell = PageCell(
            liveInfo: liveInfo,
            getSwipeBehavior: { [weak self] in self?.swipeBehavior ?? .previewOnly },
            onCloseClicked: { [weak self] in self?.handleCloseClicked() },
            onJoinClicked: { [weak self] in self?.handleJoinClicked() },
            onDidSlideIn: { [weak self] in self?.handleDidSlideIn($0) },
            onDidSlideOut: { [weak self] in self?.handleDidSlideOut($0) },
            onJoinChannelStart: { [weak self] in self?.handleJoinChannelStart() },
            onJoinChannelResult: { [weak self] in self?.handleJoinChannelResult(pageCell: $0, result: $1) }
        )
        pageCell.playerView.contentSafeAreaInsets = safeAreaInsets
        logFeed("onCreatePlayerView", pageCell: pageCell)
        return pageCell
    }

    private func prependInitialLiveIDIfNeeded() {
        guard !initialLiveID.isEmpty else { return }
        var initialLiveInfo = LiveListStore.shared.state.value.liveList.first {
            $0.liveID == initialLiveID
        } ?? LiveInfo()
        initialLiveInfo.liveID = initialLiveID
        adapter.setData([initialLiveInfo])
        collectionView.reloadData()
    }

    private func mergeWithInitialLiveID(_ list: [LiveInfo]) -> [LiveInfo] {
        guard !initialLiveID.isEmpty else { return list }
        if let index = list.firstIndex(where: { $0.liveID == initialLiveID }) {
            var reordered = list
            let target = reordered.remove(at: index)
            reordered.insert(target, at: 0)
            return reordered
        }
        var initialLiveInfo = LiveListStore.shared.state.value.liveList.first {
            $0.liveID == initialLiveID
        } ?? LiveInfo()
        initialLiveInfo.liveID = initialLiveID
        initialLiveInfo.liveName = initialLiveID
        var merged = list
        merged.insert(initialLiveInfo, at: 0)
        return merged
    }

    private func deduplicated(_ list: [LiveInfo]) -> [LiveInfo] {
        var liveIDs = Set<String>()
        return list.filter { liveIDs.insert($0.liveID).inserted }
    }

    private func resyncCurrentItemIDIfMissing() {
        guard adapter.count > 0 else {
            currentItemID = nil
            return
        }
        guard let currentItemID else { return }
        guard adapter.position(ofItemID: currentItemID) == nil else { return }
        self.currentItemID = adapter.itemID(at: currentItem)
    }

    private func applyJoinLiveEntranceEnabled() {
        let enabled = swipeBehavior == .previewOnly
        adapter.forEachPage { $0.setJoinLiveEntranceEnabled(enabled) }
    }

    private func observeCurrentPlayerStatus(_ playerView: PlayerView) {
        currentPlayerStatusCancellable?.cancel()
        swipeDisabledByCoGuest = false
        updateSwipeEnabled()
        currentPlayerStatusCancellable = playerView.status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.swipeDisabledByCoGuest = status == .coGuest
                self.updateSwipeEnabled()
            }
    }

    private func stopObservingCurrentPlayerStatus() {
        currentPlayerStatusCancellable?.cancel()
        currentPlayerStatusCancellable = nil
        swipeDisabledByCoGuest = false
        updateSwipeEnabled()
    }

    private func updateSwipeEnabled() {
        isUserInputEnabled = !(swipeDisabledByJoin || swipeDisabledByCoGuest)
    }

    private func updateVisibleItemSafeAreas() {
        let insets = safeAreaInsets
        adapter.forEachPage { $0.playerView.contentSafeAreaInsets = insets }
    }

    private func handleDidSlideIn(_ pageCell: PageCell) {
        slidingInPageCell = nil
        currentPageCell = pageCell
        observeCurrentPlayerStatus(pageCell.playerView)
        guard let position = adapter.position(ofItemID: pageCell.liveID) else { return }
        let remainingCount = adapter.count - 1 - position
        if remainingCount <= Self.loadMoreThreshold {
            onLoadMore?()
        }
    }

    private func handleDidSlideOut(_ pageCell: PageCell) {
        slidingOutPageCell = nil
        if currentPageCell === pageCell {
            currentPageCell = nil
        }
    }

    private func handleCloseClicked() {
        swipeBehavior = .previewOnly
        onClose?()
    }

    private func handleJoinClicked() {
        swipeBehavior = .autoEnterRoom
    }

    private func handleJoinChannelStart() {
        swipeDisabledByJoin = true
        updateSwipeEnabled()
    }

    private func handleJoinChannelResult(pageCell: PageCell, result: Result<LiveInfo, Error>) {
        swipeDisabledByJoin = false
        updateSwipeEnabled()
        guard case .success(let liveInfo) = result,
              pageCell.liveID == liveInfo.liveID,
              adapter.page(forItemID: liveInfo.liveID) === pageCell,
              let index = adapter.position(ofItemID: liveInfo.liveID)
        else { return }
        adapter.updateItem(at: index, with: liveInfo)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !didEmitWillSlideOut, currentItemID != nil else { return }
        didEmitWillSlideOut = true
        notifyWillSlideOut(currentItemID)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settleScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            settleScroll()
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let itemID = adapter.itemID(at: indexPath.item) else { return }
        if currentItemID == nil {
            currentItemID = itemID
            currentPageDidLeaveScreen = false
            notifyWillSlideIn(itemID)
            notifyDidSlideIn(itemID)
            return
        }

        if itemID == currentItemID {
            guard currentPageDidLeaveScreen else { return }
            currentPageDidLeaveScreen = false
        }
        pendingSlideInItemIDs.insert(itemID)
        notifyWillSlideIn(itemID)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let itemID = (cell as? PageContainerCell)?.itemID else { return }
        if itemID == currentItemID, !currentPageDidLeaveScreen {
            currentPageDidLeaveScreen = true
            pendingSlideInItemIDs.remove(itemID)
            notifyDidSlideOut(itemID)
            return
        }
        guard pendingSlideInItemIDs.remove(itemID) != nil else { return }
        notifySlideInCancelled(itemID)
    }

    private func settleScroll() {
        defer {
            didEmitWillSlideOut = false
            flushPendingReloadIfNeeded()
        }
        guard let targetItemID = adapter.itemID(at: currentItem) else { return }
        if targetItemID != currentItemID {
            let outgoingItemID = currentItemID
            let outgoingAlreadyLeft = currentPageDidLeaveScreen
            pendingSlideInItemIDs.remove(targetItemID)
            if !outgoingAlreadyLeft {
                notifyDidSlideOut(outgoingItemID)
            }
            notifyDidSlideIn(targetItemID)
            currentItemID = targetItemID
            currentPageDidLeaveScreen = false
        } else if pendingSlideInItemIDs.remove(targetItemID) != nil {
            notifyDidSlideIn(targetItemID)
            currentPageDidLeaveScreen = false
        } else if didEmitWillSlideOut {
            notifySlideOutCancelled(currentItemID)
        }
    }

    private func flushPendingReloadIfNeeded() {
        guard needsReloadAfterScroll, !isScrolling else { return }
        needsReloadAfterScroll = false
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        resyncCurrentItemIDIfMissing()
    }

    private func notifyWillSlideIn(_ itemID: String?) {
        guard let pageCell = pageCell(for: itemID) else { return }
        logFeed("onWillSlideIn", pageCell: pageCell)
        if slidingInPageCell === pageCell { return }
        slidingInPageCell = pageCell
        pageCell.startPreview()
    }

    private func notifyDidSlideIn(_ itemID: String?) {
        guard let pageCell = pageCell(for: itemID),
              let position = adapter.position(ofItemID: pageCell.liveID)
        else { return }
        let remainingCount = adapter.count - 1 - position
        logFeed("onDidSlideIn", pageCell: pageCell, extra: "remainingCount=\(remainingCount)")
        pageCell.joinChannel()
    }

    private func notifySlideInCancelled(_ itemID: String?) {
        guard let pageCell = pageCell(for: itemID) else { return }
        logFeed("onSlideInCancelled", pageCell: pageCell)
        slidingInPageCell = nil
        pageCell.stopPreview()
    }

    private func notifyWillSlideOut(_ itemID: String?) {
        guard let pageCell = pageCell(for: itemID) else { return }
        logFeed("onWillSlideOut", pageCell: pageCell)
        if slidingOutPageCell === pageCell { return }
        slidingOutPageCell = pageCell
    }

    private func notifyDidSlideOut(_ itemID: String?) {
        guard let pageCell = pageCell(for: itemID) else { return }
        logFeed("onDidSlideOut", pageCell: pageCell, extra: "behavior=\(swipeBehavior)")
        pageCell.leaveChannel()
    }

    private func notifySlideOutCancelled(_ itemID: String?) {
        guard let pageCell = pageCell(for: itemID) else { return }
        logFeed("onSlideOutCancelled", pageCell: pageCell)
        slidingOutPageCell = nil
    }

    private func pageCell(for itemID: String?) -> PageCell? {
        guard let itemID else { return nil }
        return adapter.page(forItemID: itemID)
    }

    private func logFeed(_ event: String, pageCell: PageCell, extra: String? = nil) {
        let suffix = extra.map { " \($0)" } ?? ""
        let position = pageCell.liveID.isEmpty ? nil : adapter.position(ofItemID: pageCell.liveID)
        let liveID = pageCell.liveID.isEmpty ? "-" : pageCell.liveID
        let positionText = position.map(String.init) ?? "-"
        let viewID = String(UInt(bitPattern: ObjectIdentifier(pageCell.playerView).hashValue), radix: 16)
        LiveKitLog.info("[LiveListView] feedAdapter \(event): \(liveID), position: \(positionText)/\(adapter.count), view: \(viewID)\(suffix)")
    }

    @MainActor
    private final class InnerAdapter: NSObject, UICollectionViewDataSource {
        private weak var owner: PagerView?
        private var pageCache: [String: PageCell] = [:]
        private(set) var dataList: [LiveInfo] = []

        init(owner: PagerView) {
            self.owner = owner
            super.init()
        }

        var count: Int { dataList.count }

        func setData(_ list: [LiveInfo]) {
            dataList = list
            let liveIDs = Set(list.map(\.liveID))
            for key in pageCache.keys where !liveIDs.contains(key) {
                pageCache.removeValue(forKey: key)?.removeFromSuperview()
            }
            for liveInfo in list {
                pageCache[liveInfo.liveID]?.updateData(liveInfo)
            }
        }

        func appendData(_ list: [LiveInfo]) {
            guard !list.isEmpty else { return }
            dataList.append(contentsOf: list)
        }

        func updateItem(at position: Int, with liveInfo: LiveInfo) {
            guard dataList.indices.contains(position) else { return }
            dataList[position] = liveInfo
            pageCache[liveInfo.liveID]?.updateData(liveInfo)
        }

        func itemID(at position: Int) -> String? {
            guard dataList.indices.contains(position) else { return nil }
            let liveID = dataList[position].liveID
            return liveID.isEmpty ? nil : liveID
        }

        func position(ofItemID itemID: String) -> Int? {
            dataList.firstIndex { $0.liveID == itemID }
        }

        func page(forItemID itemID: String) -> PageCell? {
            pageCache[itemID]
        }

        func forEachPage(_ body: (PageCell) -> Void) {
            pageCache.values.forEach(body)
        }

        func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            dataList.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            guard let container = collectionView.dequeueReusableCell(
                withReuseIdentifier: PageContainerCell.reuseIdentifier,
                for: indexPath
            ) as? PageContainerCell,
                  dataList.indices.contains(indexPath.item),
                  let owner
            else {
                return UICollectionViewCell()
            }

            let liveInfo = dataList[indexPath.item]
            let itemID = liveInfo.liveID
            let pageCell: PageCell
            if let cached = pageCache[itemID] {
                pageCell = cached
                pageCell.updateData(liveInfo)
            } else {
                pageCell = owner.makePageCell(liveInfo)
                if !itemID.isEmpty {
                    pageCache[itemID] = pageCell
                }
            }
            container.host(pageCell, itemID: itemID)
            return container
        }
    }
}

private final class PagerLayout: UICollectionViewFlowLayout {
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        scrollDirection = .vertical
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
        itemSize = collectionView.bounds.size
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.size != collectionView?.bounds.size
    }
}

private final class PageContainerCell: UICollectionViewCell {
    static let reuseIdentifier = "TUILiveKit.PageContainerCell"

    private(set) var itemID: String?
    private weak var hostedPageCell: PageCell?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    func host(_ pageCell: PageCell, itemID: String) {
        self.itemID = itemID
        guard hostedPageCell !== pageCell else { return }
        if let previousContainer = pageCell.superview?.superview as? PageContainerCell {
            previousContainer.release(pageCell)
        }
        hostedPageCell?.removeFromSuperview()
        hostedPageCell = pageCell
        pageCell.removeFromSuperview()
        contentView.addSubview(pageCell)
        pageCell.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if hostedPageCell?.superview === contentView {
            hostedPageCell?.removeFromSuperview()
        }
        hostedPageCell = nil
        itemID = nil
    }

    private func release(_ pageCell: PageCell) {
        guard hostedPageCell === pageCell else { return }
        hostedPageCell = nil
        itemID = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
