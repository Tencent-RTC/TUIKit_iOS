import UIKit
import SnapKit
import Combine
import AtomicXCore

public final class RoomView: UIView {

    // State
    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    private var targetPageKey: String?
    private var speakerID: String?

    private var pageBeforeDrag = 0
    private var chromeAutoHideItem: DispatchWorkItem?
    private var reportedPageIndex = 0
    private var decidePlayablePageWorkItem: DispatchWorkItem?
    private var pageChromeVisible = false

    private var participants: [RoomParticipant] = []
    private var screenParticipant: RoomParticipant?
    private var floatingParticipant: RoomParticipant?
    private var localParticipantID: String?
    private var volumes: [String: Int] = [:]
    private var networkQualities: [String: NetworkInfo] = [:]
    private var pageKeys: [String] = []
    private var itemKeys: [String] = []
    private var playingPageKey: String?

    private var tileCache: [String: RoomParticipantTileView] = [:]

    // Subviews
    private let flowLayout = RoomVideoFlowLayout()
    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()
    private let pageIndicator = UIView()
    private let pageIndicatorLabel = UILabel()
    private let previousPageButton = UIButton(type: .custom)
    private let nextPageButton = UIButton(type: .custom)

    init(roomID: String) {
        self.roomID = roomID
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        decidePlayablePageWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
            observeParticipants()
            showTargetPage()
            decidePlayablePage()
        } else {
            cancellableSet.removeAll()
            decidePlayablePageWorkItem?.cancel()
            setPlayingPage(nil)
        }
    }

    private func setupViews() {
        collectionView.register(RoomVideoCell.self, forCellWithReuseIdentifier: Self.videoCellIdentifier)
        collectionView.register(RoomScreenCell.self, forCellWithReuseIdentifier: Self.screenCellIdentifier)
        collectionView.dataSource = self
        pageIndicator.addSubview(pageIndicatorLabel)
        addSubview(collectionView)
        addSubview(previousPageButton)
        addSubview(nextPageButton)
        addSubview(emptyLabel)
        addSubview(pageIndicator)
    }

    private func setupConstraints() {
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
        previousPageButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(32)
        }
        nextPageButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-8)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(32)
        }
        emptyLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(16)
            $0.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        pageIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-8)
            $0.height.equalTo(20)
        }
        pageIndicatorLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8))
        }
    }

    private func setupStyles() {
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.bounces = false
        collectionView.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleStageTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)

        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isUserInteractionEnabled = false

        pageIndicator.layer.cornerRadius = 8
        pageIndicator.isHidden = true
        pageIndicator.isUserInteractionEnabled = false
        pageIndicatorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        pageIndicatorLabel.textAlignment = .center

        previousPageButton.setImage(RoomKitResources.image(named: "roomkit_icon_page_arrow_prev"), for: .normal)
        nextPageButton.setImage(RoomKitResources.image(named: "roomkit_icon_page_arrow_next"), for: .normal)
        for button in [previousPageButton, nextPageButton] {
            button.layer.cornerRadius = 16
            button.isHidden = true
        }
        previousPageButton.accessibilityLabel = .roomViewPreviousPage
        nextPageButton.accessibilityLabel = .roomViewNextPage

        applyTheme()
    }

    private func setupBindings() {
        previousPageButton.addTarget(self, action: #selector(handlePreviousPageTap), for: .touchUpInside)
        nextPageButton.addTarget(self, action: #selector(handleNextPageTap), for: .touchUpInside)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleApplicationStateChanged),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(handleApplicationStateChanged),
                           name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgSurface
        emptyLabel.textColor = UIColor.roomKitFgSecondary
        pageIndicator.backgroundColor = UIColor.roomKitBgPageIndicator
        pageIndicatorLabel.textColor = UIColor.roomKitFgOnMedia
        for button in [previousPageButton, nextPageButton] {
            button.backgroundColor = UIColor.roomKitBgPageIndicator
        }
    }

    // private methods

    private var currentPageIndex: Int {
        let width = collectionView.bounds.width
        guard width > 0 else { return 0 }
        let index = Int((collectionView.contentOffset.x / width).rounded())
        return min(max(index, 0), max(flowLayout.pageCount - 1, 0))
    }

    private func observeParticipants() {
        cancellableSet.removeAll()
        targetPageKey = nil
        speakerID = nil
        flowLayout.floatingPosition = RoomVideoFlowLayout.FloatingWindowPosition()
        setPlayingPage(nil)
        networkQualities = [:]
        applyVideo(participants: [], screen: nil, floating: nil, localParticipantID: nil, volumes: [:])
        emptyLabel.isHidden = false
        updatePageIndicator()

        let store = RoomParticipantStore.create(roomID: roomID)
        let volumes = store.state
            .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.speakingUsers))
            .removeDuplicates()
            .throttle(for: .seconds(RoomMicLevelView.updateInterval), scheduler: RunLoop.main, latest: true)
        Publishers.CombineLatest4(
            store.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantList)),
            store.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantWithScreen)),
            store.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant)),
            volumes
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] participants, screenParticipant, localParticipant, volumes in
            self?.render(participants: participants,
                         screenParticipant: screenParticipant,
                         localParticipant: localParticipant,
                         volumes: volumes)
        }
        .store(in: &cancellableSet)

        store.state
            .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.networkQualities))
            .throttle(for: .seconds(RoomMicLevelView.updateInterval), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] qualities in
                guard let self else { return }
                self.networkQualities = qualities
                self.refreshVisibleCells()
            }
            .store(in: &cancellableSet)
        fetchParticipants()
    }

    func fetchParticipants() {
        RoomParticipantStore.create(roomID: roomID).getParticipantList(cursor: nil, completion: nil)
    }

    private func render(participants: [RoomParticipant],
                        screenParticipant: RoomParticipant?,
                        localParticipant: RoomParticipant?,
                        volumes: [String: Int]) {
        let validLocal = localParticipant.flatMap { $0.userID.isEmpty ? nil : $0 }
        let speaker = selectSpeaker(participants: participants, localParticipant: validLocal, volumes: volumes)
        speakerID = speaker?.userID
        var seen = Set<String>()
        let members = participants.filter { !$0.userID.isEmpty && seen.insert($0.userID).inserted }
        let screen = screenParticipant.flatMap { $0.userID.isEmpty ? nil : $0 }
        let floating = screen == nil ? nil : (speaker ?? validLocal)

        decideTargetPage(Self.makePageKeys(participants: members, screen: screen))
        let structureDidChange = applyVideo(participants: members,
                                            screen: screen,
                                            floating: floating,
                                            localParticipantID: validLocal?.userID,
                                            volumes: volumes)
        emptyLabel.isHidden = flowLayout.pageCount > 0
        if structureDidChange {
            updatePageIndicator()
            showTargetPage()
            decidePlayablePage()
        }
    }

    private func selectSpeaker(participants: [RoomParticipant],
                               localParticipant: RoomParticipant?,
                               volumes: [String: Int]) -> RoomParticipant? {
        var seen = Set<String>()
        let candidates = (participants + (localParticipant.map { [$0] } ?? [])).filter {
            !$0.userID.isEmpty && seen.insert($0.userID).inserted && $0.microphoneStatus == .on
        }
        guard let highestVolume = candidates.map({ volumes[$0.userID] ?? 0 }).max(), highestVolume > 0 else {
            return nil
        }
        if let previous = candidates.first(where: { $0.userID == speakerID }),
           volumes[previous.userID] == highestVolume {
            return previous
        }
        return candidates.first { volumes[$0.userID] == highestVolume }
    }

    private static func makePageKeys(participants: [RoomParticipant], screen: RoomParticipant?) -> [String] {
        let screenKeys = screen.map { ["screen:\($0.userID)"] } ?? []
        let participantKeys = stride(from: 0, to: participants.count, by: RoomVideoFlowLayout.pageCapacity)
            .map { "participants:\(participants[$0].userID)" }
        return screenKeys + participantKeys
    }

    private func decideTargetPage(_ nextKeys: [String]) {
        let previousKeys = pageKeys
        if previousKeys == nextKeys { return }

        let startedSharing = nextKeys.first?.hasPrefix("screen:") == true && nextKeys.first != previousKeys.first
        if startedSharing {
            targetPageKey = nextKeys.first
            flowLayout.floatingPosition = RoomVideoFlowLayout.FloatingWindowPosition()
            return
        }

        let currentPageKey = previousKeys.indices.contains(currentPageIndex) ? previousKeys[currentPageIndex] : nil
        let keyToKeep = targetPageKey ?? currentPageKey
        let targetIndex = nextKeys.firstIndex { $0 == keyToKeep } ?? min(currentPageIndex, max(nextKeys.count - 1, 0))
        targetPageKey = nextKeys.indices.contains(targetIndex) ? nextKeys[targetIndex] : nil
    }

    private func showTargetPage() {
        guard let key = targetPageKey else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.targetPageKey = nil
            self.collectionView.layoutIfNeeded()
            if let index = self.pageKeys.firstIndex(of: key) {
                self.collectionView.setContentOffset(
                    CGPoint(x: CGFloat(index) * self.collectionView.bounds.width, y: 0),
                    animated: false
                )
            }
            self.updatePageIndicator()
            self.decidePlayablePage()
        }
    }

    private func updatePageIndicator() {
        let pageCount = flowLayout.pageCount
        let currentPage = currentPageIndex
        pageIndicatorLabel.text = String(format: .roomViewPageNumberFormat, currentPage + 1, pageCount)
        let hasPrevious = currentPage > 0
        let hasNext = currentPage < pageCount - 1
        previousPageButton.isEnabled = hasPrevious
        nextPageButton.isEnabled = hasNext
        guard pageIndicator.alpha > 0 else { return }
        previousPageButton.alpha = hasPrevious ? 1 : Self.DISABLED_ALPHA
        nextPageButton.alpha = hasNext ? 1 : Self.DISABLED_ALPHA
    }

    @objc private func handleStageTap() {
        togglePageChrome()
    }

    private func togglePageChrome() {
        guard flowLayout.pageCount > 1 else { return }
        if pageChromeVisible { hidePageChrome() } else { showPageChrome() }
    }

    private func showPageChrome() {
        guard flowLayout.pageCount > 1 else { return }
        pageChromeVisible = true
        let views: [UIView] = [previousPageButton, nextPageButton, pageIndicator]
        views.forEach { view in
            view.isHidden = false
            view.layer.removeAllAnimations()
        }
        updatePageIndicator()
        UIView.animate(withDuration: Self.CHROME_ANIMATION_DURATION) {
            self.pageIndicator.alpha = 1
            self.previousPageButton.alpha = self.previousPageButton.isEnabled ? 1 : Self.DISABLED_ALPHA
            self.nextPageButton.alpha = self.nextPageButton.isEnabled ? 1 : Self.DISABLED_ALPHA
        }
        scheduleChromeAutoHide()
    }

    private func scheduleChromeAutoHide() {
        chromeAutoHideItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.hidePageChrome() }
        chromeAutoHideItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.CHROME_AUTO_HIDE_DELAY, execute: item)
    }

    private func hidePageChrome() {
        chromeAutoHideItem?.cancel()
        chromeAutoHideItem = nil
        pageChromeVisible = false
        let views: [UIView] = [previousPageButton, nextPageButton, pageIndicator]
        UIView.animate(withDuration: Self.CHROME_ANIMATION_DURATION) {
            views.forEach { $0.alpha = 0 }
        } completion: { _ in
            views.forEach { $0.isHidden = true }
        }
    }

    private func scrollToPage(_ index: Int) {
        showPageChrome()
        let target = min(max(index, 0), max(flowLayout.pageCount - 1, 0))
        decidePlayablePage()
        collectionView.setContentOffset(CGPoint(x: CGFloat(target) * collectionView.bounds.width, y: 0), animated: true)
    }

    private func decidePlayablePage() {
        decidePlayablePageWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.updatePlayablePage()
        }
        decidePlayablePageWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func updatePlayablePage() {
        let isViewVisible = isEffectivelyVisible && UIApplication.shared.applicationState != .background
        let isPageReady = targetPageKey == nil
        let hasActiveSubscription = !cancellableSet.isEmpty
        let canPlay = isViewVisible && isPageReady && hasActiveSubscription
        let currentPageKey = pageKeys.indices.contains(currentPageIndex) ? pageKeys[currentPageIndex] : nil
        setPlayingPage(canPlay ? currentPageKey : nil)
    }

    ///
    ///
    ///
    @discardableResult
    private func applyVideo(participants nextParticipants: [RoomParticipant],
                            screen: RoomParticipant?,
                            floating: RoomParticipant?,
                            localParticipantID: String?,
                            volumes: [String: Int]) -> Bool {
        let nextPageKeys = Self.makePageKeys(participants: nextParticipants, screen: screen)
        let nextItemKeys = (screen.map { ["screen:\($0.userID)"] } ?? [])
            + (floating != nil ? ["floating"] : [])
            + nextParticipants.map { "participant:\($0.userID)" }
        let structureChanged = nextItemKeys != itemKeys || nextPageKeys != pageKeys
        let previousItemKeys = itemKeys
        let previousPageCount = flowLayout.pageCount

        self.localParticipantID = localParticipantID
        self.volumes = volumes
        if !nextPageKeys.contains(where: { $0 == playingPageKey }) { setPlayingPage(nil) }
        participants = nextParticipants
        screenParticipant = screen
        floatingParticipant = floating
        pageKeys = nextPageKeys
        itemKeys = nextItemKeys
        flowLayout.update(participantCount: nextParticipants.count,
                          hasScreenShare: screen != nil,
                          hasFloatingWindow: floating != nil)

        pruneTiles()

        guard structureChanged else {
            refreshVisibleCells()
            return false
        }

        let pageCountChanged = previousPageCount != flowLayout.pageCount
        let leadingChanged = Self.leadingItemKeys(in: previousItemKeys) != Self.leadingItemKeys(in: nextItemKeys)
        guard !pageCountChanged, !leadingChanged, previousItemKeys != nextItemKeys else {
            collectionView.reloadData()
            return true
        }

        let oldItems = previousItemKeys
        let newItems = nextItemKeys
        let oldSet = Set(oldItems)
        let newSet = Set(newItems)
        guard oldItems.filter(newSet.contains) == newItems.filter(oldSet.contains) else {
            collectionView.reloadData()
            return true
        }
        let deletions = oldItems.enumerated()
            .filter { !newSet.contains($0.element) }
            .map { IndexPath(item: $0.offset, section: 0) }
        let insertions = newItems.enumerated()
            .filter { !oldSet.contains($0.element) }
            .map { IndexPath(item: $0.offset, section: 0) }
        if deletions.isEmpty && insertions.isEmpty {
            refreshVisibleCells()
            return true
        }
        collectionView.performBatchUpdates {
            if !deletions.isEmpty { collectionView.deleteItems(at: deletions) }
            if !insertions.isEmpty { collectionView.insertItems(at: insertions) }
        } completion: { [weak self] _ in
            self?.refreshVisibleCells()
            self?.decidePlayablePage()
        }
        return true
    }

    private static func leadingItemKeys(in keys: [String]) -> [String] {
        keys.filter { $0.hasPrefix("screen:") || $0 == "floating" }
    }

    private func pruneTiles() {
        let alive = Set(itemKeys)
        for (key, tile) in tileCache where !alive.contains(key) {
            tile.release()
            tile.removeFromSuperview()
            tileCache.removeValue(forKey: key)
        }
    }

    private func tileKey(forItem item: Int) -> String? {
        if flowLayout.isScreenItem(item) { return screenParticipant.map { "screen:\($0.userID)" } }
        if flowLayout.isFloatingItem(item) { return floatingParticipant.map { _ in "floating" } }
        let index = flowLayout.participantIndex(forItem: item)
        guard participants.indices.contains(index) else { return nil }
        return "participant:\(participants[index].userID)"
    }

    private func tile(forItem item: Int) -> RoomParticipantTileView? {
        guard let key = tileKey(forItem: item) else { return nil }
        if let cached = tileCache[key] { return cached }
        let streamType: VideoStreamType = flowLayout.isScreenItem(item) ? .screen : .camera
        let created = RoomParticipantTileView(streamType: streamType)
        tileCache[key] = created
        return created
    }

    private func refreshVisibleCells() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? RoomParticipantCell else { continue }
            configure(cell, at: indexPath.item)
        }
    }

    private func participant(forItem item: Int) -> RoomParticipant? {
        if flowLayout.isScreenItem(item) { return screenParticipant }
        if flowLayout.isFloatingItem(item) { return floatingParticipant }
        let index = flowLayout.participantIndex(forItem: item)
        return participants.indices.contains(index) ? participants[index] : nil
    }

    private func isPlayingItem(_ item: Int) -> Bool {
        let page = flowLayout.pageIndex(forItem: item)
        return pageKeys.indices.contains(page) && pageKeys[page] == playingPageKey
    }

    private func setPlayingPage(_ pageKey: String?) {
        playingPageKey = pageKey
        syncPlayback()
    }

    private func syncPlayback() {
        var playing = Set<ObjectIdentifier>()
        for case let cell as RoomParticipantCell in collectionView.visibleCells {
            guard let tile = cell.tile, let indexPath = collectionView.indexPath(for: cell) else { continue }
            let shouldPlay = playingPageKey != nil && isPlayingItem(indexPath.item)
            tile.setPlaying(shouldPlay)
            if shouldPlay { playing.insert(ObjectIdentifier(tile)) }
        }
        for tile in tileCache.values where !playing.contains(ObjectIdentifier(tile)) {
            tile.setPlaying(false)
        }
    }

    private func configure(_ cell: RoomParticipantCell, at item: Int) {
        guard let participant = participant(forItem: item), let tile = tile(forItem: item) else { return }
        cell.host(tile)
        tile.bind(participant: participant,
                  localParticipantID: localParticipantID,
                  volume: volumes[participant.userID] ?? 0,
                  networkQuality: networkQualities[participant.userID]?.quality)
        tile.setPlaying(playingPageKey != nil && isPlayingItem(item))

        if let videoCell = cell as? RoomVideoCell {
            let isFloating = flowLayout.isFloatingItem(item)
            if videoCell.isFloating != isFloating {
                videoCell.isFloating = isFloating
            }
            if isFloating {
                if videoCell.onFloatingPan == nil {
                    videoCell.onFloatingPan = { [weak self, weak videoCell] state, translation in
                        guard let videoCell else { return }
                        self?.flowLayout.handleFloatingPan(of: videoCell, state: state, translation: translation)
                    }
                }
            } else {
                videoCell.onFloatingPan = nil
            }
        }
    }

    private var isEffectivelyVisible: Bool {
        guard window != nil else { return false }
        var view: UIView? = self
        while let current = view {
            if current.isHidden || current.alpha == 0 { return false }
            view = current.superview
        }
        return true
    }
}

#if DEBUG
extension RoomView {

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if collectionView.frame.contains(point) {
            print("[RoomViewDiag] hit(\(Int(point.x)),\(Int(point.y))) -> \(result.map { String(describing: type(of: $0)) } ?? "nil")")
        }
        return result
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("[RoomViewDiag] touchesBegan")
        super.touchesBegan(touches, with: event)
    }
}
#endif

// private objc event methods
extension RoomView {

    @objc private func handlePreviousPageTap() {
        scrollToPage(currentPageIndex - 1)
    }

    @objc private func handleNextPageTap() {
        scrollToPage(currentPageIndex + 1)
    }

    @objc private func handleApplicationStateChanged() {
        decidePlayablePage()
    }
}

extension RoomView: UICollectionViewDataSource {

    fileprivate static let videoCellIdentifier = "RoomVideoCell"
    fileprivate static let screenCellIdentifier = "RoomScreenCell"
    fileprivate static let CHROME_ANIMATION_DURATION: TimeInterval = 0.16
    fileprivate static let DISABLED_ALPHA: CGFloat = 0.22
    fileprivate static let CHROME_AUTO_HIDE_DELAY: TimeInterval = 2.5

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        flowLayout.itemCount
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = flowLayout.isScreenItem(indexPath.item) ? Self.screenCellIdentifier : Self.videoCellIdentifier
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        guard let participantCell = cell as? RoomParticipantCell else { return cell }
        configure(participantCell, at: indexPath.item)
        return participantCell
    }
}

// Delegate
extension RoomView: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
}

extension RoomView: UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView,
                               willDisplay cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        guard let participantCell = cell as? RoomParticipantCell else { return }
        participantCell.tile?.setPlaying(playingPageKey != nil && isPlayingItem(indexPath.item))
        decidePlayablePage()
    }

    public func collectionView(_ collectionView: UICollectionView,
                               didEndDisplaying cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        guard let participantCell = cell as? RoomParticipantCell,
              let tile = participantCell.tile,
              tile.superview === participantCell.contentView else { return }
        tile.setPlaying(false)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let index = currentPageIndex
        guard index != reportedPageIndex else { return }
        reportedPageIndex = index
        updatePageIndicator()
        decidePlayablePage()
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        #if DEBUG
        print("[RoomViewDiag] scroll drag begin, offset.x=\(scrollView.contentOffset.x)")
        #endif
        pageBeforeDrag = currentPageIndex
        decidePlayablePage()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        decidePlayablePage()
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if currentPageIndex != pageBeforeDrag { showPageChrome() }
        decidePlayablePage()
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        decidePlayablePage()
    }
}

extension String {
    fileprivate static var roomViewPageNumberFormat: String { RoomKitResources.localizedString("roomkit.room_view.page_number") }
    fileprivate static var roomViewPreviousPage: String { RoomKitResources.localizedString("roomkit.room_view.prev_page") }
    fileprivate static var roomViewNextPage: String { RoomKitResources.localizedString("roomkit.room_view.next_page") }
}
