import UIKit
import SnapKit
import Combine
import AtomicXCore

public final class RoomView: UIView {

    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    private var targetPageKey: String?
    private var speakerID: String?
    private var speakerSilentSince: Date?
    private static let speakerHoldInterval: TimeInterval = 1.0
    private static let localVolumeKey = ""

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
    private var isBatchUpdating = false
    private var playingPageKey: String?

    private let floatingView = RoomParticipantFloatView()

    private let flowLayout = RoomParticipantLayout()
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
        observeParticipants()
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
            showTargetPage()
            decidePlayablePage()
        } else {
            decidePlayablePageWorkItem?.cancel()
            setPlayingPage(nil)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        collectionView.layoutIfNeeded()
        if floatingView.superview === self {
            floatingView.frame = flowLayout.floatingFrame()
        }
    }

    private func setupViews() {
        collectionView.register(RoomParticipantCameraCell.self, forCellWithReuseIdentifier: Self.cameraCellIdentifier)
        collectionView.register(RoomParticipantScreenShareCell.self, forCellWithReuseIdentifier: Self.screenCellIdentifier)
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
        speakerSilentSince = nil
        flowLayout.floatingPosition = RoomParticipantLayout.FloatingWindowPosition()
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
            var volumes = volumes
            if let localID = localParticipant?.userID, !localID.isEmpty, let localVolume = volumes[Self.localVolumeKey] {
                volumes[localID] = localVolume
            }
            self?.updatePages(participants: participants,
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
    }

    private func updatePages(participants: [RoomParticipant],
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
        configureFloating()
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

        let current = candidates.first { $0.userID == speakerID }
        let loudest = candidates
            .filter { (volumes[$0.userID] ?? 0) > 0 }
            .max { (volumes[$0.userID] ?? 0) < (volumes[$1.userID] ?? 0) }

        if let current, (volumes[current.userID] ?? 0) > 0 {
            speakerSilentSince = nil
            return current
        }
        if let current {
            guard let loudest else {
                speakerSilentSince = nil
                return current
            }
            let now = Date()
            if speakerSilentSince == nil { speakerSilentSince = now }
            if now.timeIntervalSince(speakerSilentSince!) < Self.speakerHoldInterval { return current }
            speakerSilentSince = nil
            return loudest
        }
        return loudest
    }

    private static func makePageKeys(participants: [RoomParticipant], screen: RoomParticipant?) -> [String] {
        let screenKeys = screen.map { ["screen:\($0.userID)"] } ?? []
        let pageCount = (participants.count + RoomParticipantLayout.pageCapacity - 1) / RoomParticipantLayout.pageCapacity
        let participantKeys = (0..<pageCount).map { "participants:\($0)" }
        return screenKeys + participantKeys
    }

    private func decideTargetPage(_ nextKeys: [String]) {
        let previousKeys = pageKeys
        if previousKeys == nextKeys { return }

        let startedSharing = nextKeys.first?.hasPrefix("screen:") == true && nextKeys.first != previousKeys.first
        if startedSharing {
            targetPageKey = nextKeys.first
            flowLayout.floatingPosition = RoomParticipantLayout.FloatingWindowPosition()
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
        previousPageButton.alpha = hasPrevious ? 1 : 0.22
        nextPageButton.alpha = hasNext ? 1 : 0.22
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
            self.previousPageButton.alpha = self.previousPageButton.isEnabled ? 1 : 0.22
            self.nextPageButton.alpha = self.nextPageButton.isEnabled ? 1 : 0.22
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

    @discardableResult
    private func applyVideo(participants nextParticipants: [RoomParticipant],
                            screen: RoomParticipant?,
                            floating: RoomParticipant?,
                            localParticipantID: String?,
                            volumes: [String: Int]) -> Bool {
        let nextPageKeys = Self.makePageKeys(participants: nextParticipants, screen: screen)
        let nextItemKeys = (screen.map { ["screen:\($0.userID)"] } ?? [])
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

        if floating == nil {
            floatingView.release()
            floatingView.removeFromSuperview()
        }

        guard structureChanged else {
            refreshVisibleCells()
            return false
        }

        let leadingChanged = Self.leadingItemKeys(in: previousItemKeys) != Self.leadingItemKeys(in: nextItemKeys)
        guard !leadingChanged, previousItemKeys != nextItemKeys else {
            collectionView.reloadData()
            return true
        }

        let oldItems = previousItemKeys.filter { !$0.hasPrefix("screen:") }
        let newItems = nextItemKeys.filter { !$0.hasPrefix("screen:") }
        let oldSet = Set(oldItems)
        let newSet = Set(newItems)
        let deletions = oldItems.enumerated()
            .filter { !newSet.contains($0.element) }
            .map { IndexPath(item: $0.offset, section: 1) }
        let insertions = newItems.enumerated()
            .filter { !oldSet.contains($0.element) }
            .map { IndexPath(item: $0.offset, section: 1) }
        let oldIndexByKey = Dictionary(uniqueKeysWithValues: oldItems.enumerated().map { ($0.element, $0.offset) })
        let moves: [(from: IndexPath, to: IndexPath)] = newItems.enumerated().compactMap { newIndex, key in
            guard let oldIndex = oldIndexByKey[key], oldIndex != newIndex else { return nil }
            return (IndexPath(item: oldIndex, section: 1), IndexPath(item: newIndex, section: 1))
        }
        if deletions.isEmpty && insertions.isEmpty && moves.isEmpty {
            refreshVisibleCells()
            return true
        }

        guard !isBatchUpdating,
              collectionView.numberOfItems(inSection: 1) == oldItems.count,
              newItems.count == flowLayout.itemCount(inSection: 1) else {
            collectionView.reloadData()
            return true
        }
        isBatchUpdating = true
        collectionView.performBatchUpdates {
            if !deletions.isEmpty { collectionView.deleteItems(at: deletions) }
            if !insertions.isEmpty { collectionView.insertItems(at: insertions) }
            moves.forEach { collectionView.moveItem(at: $0.from, to: $0.to) }
        } completion: { [weak self] _ in
            self?.isBatchUpdating = false
            self?.refreshVisibleCells()
            self?.decidePlayablePage()
        }
        return true
    }

    private static func leadingItemKeys(in keys: [String]) -> [String] {
        keys.filter { $0.hasPrefix("screen:") }
    }

    private func refreshVisibleCells() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) else { continue }
            configure(cell, at: indexPath)
        }
    }

    private func participant(at indexPath: IndexPath) -> RoomParticipant? {
        if indexPath.section == 0 { return screenParticipant }
        let index = flowLayout.participantIndex(forItem: indexPath.item)
        return participants.indices.contains(index) ? participants[index] : nil
    }

    private func isPlayingItem(_ indexPath: IndexPath) -> Bool {
        let page = flowLayout.pageIndex(for: indexPath)
        return pageKeys.indices.contains(page) && pageKeys[page] == playingPageKey
    }

    private func setPlayingPage(_ pageKey: String?) {
        playingPageKey = pageKey
        syncPlayback()
    }

    private func syncPlayback() {
        for cell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }
            setPlaying(playingPageKey != nil && isPlayingItem(indexPath), for: cell)
        }
        updateFloatingVisibility()
        let floatingPageKey = pageKeys.first { $0.hasPrefix("screen:") }
        floatingView.setPlaying(!floatingView.isHidden && floatingPageKey == playingPageKey)
    }

    private func updateFloatingVisibility() {
        let floatingPageKey = pageKeys.first { $0.hasPrefix("screen:") }
        let isScreenPage = pageKeys.indices.contains(currentPageIndex)
            && floatingPageKey != nil
            && pageKeys[currentPageIndex] == floatingPageKey
        floatingView.isHidden = floatingView.superview !== self || !isScreenPage
    }

    private func configureFloating() {
        guard let participant = floatingParticipant else { return }
        let needsInitialLayout = floatingView.superview !== self
        if needsInitialLayout {
            insertSubview(floatingView, aboveSubview: collectionView)
        }
        floatingView.bind(participant: participant,
                          localParticipantID: localParticipantID,
                          volume: volumes[participant.userID] ?? 0,
                          networkQuality: networkQualities[participant.userID]?.quality)
        if floatingView.onFloatingPan == nil {
            floatingView.onFloatingPan = { [weak self] state, translation in
                guard let self else { return }
                self.flowLayout.handleFloatingPan(of: self.floatingView, state: state, translation: translation)
                switch state {
                case .ended, .cancelled, .failed:
                    self.setNeedsLayout()
                default:
                    break
                }
            }
        }
        updateFloatingVisibility()
        if needsInitialLayout { setNeedsLayout() }
    }

    private func configure(_ cell: UICollectionViewCell, at indexPath: IndexPath) {
        guard let participant = participant(at: indexPath) else { return }
        let shouldPlay = playingPageKey != nil && isPlayingItem(indexPath)
        let volume = volumes[participant.userID] ?? 0
        let networkQuality = networkQualities[participant.userID]?.quality

        switch cell {
        case let cell as RoomParticipantScreenShareCell:
            cell.bind(participant: participant,
                      localParticipantID: localParticipantID,
                      volume: volume,
                      networkQuality: networkQuality)
            cell.setPlaying(shouldPlay)
        case let cell as RoomParticipantCameraCell:
            cell.bind(participant: participant,
                      localParticipantID: localParticipantID,
                      volume: volume,
                      networkQuality: networkQuality)
            cell.setPlaying(shouldPlay)
        default:
            break
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

    fileprivate static let cameraCellIdentifier = "RoomParticipantCameraCell"
    fileprivate static let screenCellIdentifier = "RoomParticipantScreenShareCell"
    fileprivate static let CHROME_ANIMATION_DURATION: TimeInterval = 0.16
    fileprivate static let CHROME_AUTO_HIDE_DELAY: TimeInterval = 2.5

    public func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        flowLayout.itemCount(inSection: section)
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 ? Self.screenCellIdentifier : Self.cameraCellIdentifier
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
}

extension RoomView: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
}

extension RoomView: UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView,
                               willDisplay cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        setPlaying(playingPageKey != nil && isPlayingItem(indexPath), for: cell)
        decidePlayablePage()
    }

    public func collectionView(_ collectionView: UICollectionView,
                               didEndDisplaying cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        setPlaying(false, for: cell)
    }

    private func setPlaying(_ playing: Bool, for cell: UICollectionViewCell) {
        (cell as? RoomParticipantScreenShareCell)?.setPlaying(playing)
        (cell as? RoomParticipantCameraCell)?.setPlaying(playing)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let index = currentPageIndex
        guard index != reportedPageIndex else { return }
        reportedPageIndex = index
        updatePageIndicator()
        decidePlayablePage()
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
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
