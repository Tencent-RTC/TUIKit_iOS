//
//  StandardRoomView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/1/30.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore

// MARK: - StandardRoomView Component
class StandardRoomView: UIView, BaseView {
    public weak var routerContext: RouterContext?
    private let roomID: String
    
    private lazy var roomParticipantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    // MARK: - Constants
    private struct LayoutConstants {
        static let itemSpacing: CGFloat = RoomSpacing.small // 8pt
        static let lineSpacing: CGFloat = RoomSpacing.small // 8pt
        static let maxItemsPerPage: Int = 6
        static let maxColumns: Int = 2
        static let maxRows: Int = 3
    }
    
    // MARK: - Properties
    var participantList: (RoomParticipant?, [RoomParticipant]) = (nil, [])
    var speakingUsers: [String : Int] = [:]
    private var cancellableSet = Set<AnyCancellable>()
    private var currentPage: Int = 0
    private var totalPages: Int = 0

    private var orientationButtonHidden: Bool = true
    private var orientationButtonIsLandscape: Bool = false
    private var currentScreenSharerID: String?
    
    private lazy var streamManager: SingleStreamManager = {
        let manager = SingleStreamManager(roomID: roomID, hostView: self)
        manager.onRenderReleased = { [weak self] userID in
            self?.restoreGridCellRender(userID: userID)
        }
        return manager
    }()

    private enum LayoutMode: Equatable {
        case singleFullScreen
        case remoteFullScreenWithLocal
        case grid
        case screenShareSingle
        case screenShareWithSpeaker
    }

    private var layoutMode: LayoutMode {
        let count = participantList.1.count
        let hasScreenShare = participantList.0 != nil
        if hasScreenShare {
            return count >= 2 ? .screenShareWithSpeaker : .screenShareSingle
        }
        if count == 1 { return .singleFullScreen }
        if count == 2 { return .remoteFullScreenWithLocal }
        return .grid
    }

    private var localUserID: String {
        LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }
    
    private var displayParticipants: [RoomParticipant] {
        switch layoutMode {
        case .remoteFullScreenWithLocal:
            return participantList.1.filter { $0.userID != localUserID }
        default:
            return participantList.1
        }
    }
    
    // MARK: - UI Components
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: RoomViewFlowLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.decelerationRate = .fast
        collectionView.register(RoomViewVideoStreamCell.self, forCellWithReuseIdentifier: RoomViewVideoStreamCell.reuseIdentifier)
        collectionView.register(RoomViewScreenStreamCell.self, forCellWithReuseIdentifier: RoomViewScreenStreamCell.reuseIdentifier)
        return collectionView
    }()
    
    private lazy var previousPageButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_previous_page_icon"), for: .normal)
        button.isHidden = true
        return button
    }()
    
    private lazy var nextPageButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_next_page_icon"), for: .normal)
        button.isHidden = true
        return button
    }()

    private var singleStreamView: RoomSingleStreamView {
        return streamManager.singleStreamView
    }

    // MARK: - Initialization
    public init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("\(type(of: self)) deinit")
    }
    
    // MARK: - BaseView Implementation
    public func setupViews() {
        addSubview(collectionView)
        addSubview(previousPageButton)
        addSubview(nextPageButton)
        addSubview(singleStreamView)
    }
    
    public func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
         
        previousPageButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        nextPageButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }
    
    public func setupStyles() {
        backgroundColor = .clear
    }
    
    public func setScrollEnabled(_ enabled: Bool) {
        collectionView.isScrollEnabled = enabled
    }

    func setScreenStreamOrientationButtonHidden(_ hidden: Bool) {
        orientationButtonHidden = hidden
        for cell in collectionView.visibleCells {
            if let screenCell = cell as? RoomViewScreenStreamCell {
                screenCell.setOrientationSwitchButtonHidden(hidden)
            }
        }
    }

    func updateScreenStreamOrientationButtonImage(isLandscape: Bool) {
        orientationButtonIsLandscape = isLandscape
        for cell in collectionView.visibleCells {
            if let screenCell = cell as? RoomViewScreenStreamCell {
                screenCell.updateOrientationSwitchButtonImage(isLandscape: isLandscape)
            }
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let isLandscape = bounds.width > bounds.height
        if isLandscape != orientationButtonIsLandscape {
            updateScreenStreamOrientationButtonImage(isLandscape: isLandscape)
        }
        streamManager.updateFrame()
    }

    public func setupBindings() {
        // MARK: - Real Data Binding
        roomParticipantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                updateParticipantList(participantList)
            }
            .store(in: &cancellableSet)
        
        roomParticipantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantWithScreen))
            .removeDuplicates { $0?.userID == $1?.userID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                updateScreenShareParticipant(participant)
                onScreenSharerChanged(newSharerID: participant?.userID)
            }
            .store(in: &cancellableSet)
        
        roomParticipantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.speakingUsers))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speakingUsers in
                guard let self = self else { return }
                updateVisibleCellsSpeakingStatus(speakingUsers)
            }
            .store(in: &cancellableSet)
    }

    // MARK: - Screen Sharer & Orientation

    private func onScreenSharerChanged(newSharerID: String?) {
        if currentScreenSharerID == newSharerID { return }
        currentScreenSharerID = newSharerID
        updateOrientationSwitchButtonVisibility()
        if newSharerID == nil || newSharerID?.isEmpty == true {
            forcePortraitIfLandscape()
        }
    }

    private func updateOrientationSwitchButtonVisibility() {
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let hasRemoteSharer = currentScreenSharerID != nil
            && !(currentScreenSharerID?.isEmpty ?? true)
            && currentScreenSharerID != localUserID
        let shouldShow = hasRemoteSharer
        setScreenStreamOrientationButtonHidden(!shouldShow)
    }

    private func forcePortraitIfLandscape() {
        guard let viewController = findViewController() as? RoomMainViewController else { return }
        if viewController.isLandscapeMode {
            viewController.isLandscapeMode = false
            if #available(iOS 16.0, *) {
                viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
                if let windowScene = viewController.view.window?.windowScene {
                    let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                    windowScene.requestGeometryUpdate(geometry)
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return nil
    }

}

// MARK: - UICollectionViewDataSource
extension StandardRoomView: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        if participantList.0 != nil {
            return 2
        } else {
            return 1
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if participantList.0 != nil {
            if section == 0 {
                return 1
            } else {
                return displayParticipants.count
            }
        }
        return displayParticipants.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let participant: RoomParticipant
        if let screenShareParticipant = participantList.0 {
            if indexPath.section == 0 {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomViewScreenStreamCell.reuseIdentifier, for: indexPath) as? RoomViewScreenStreamCell else {
                    return UICollectionViewCell()
                }
                cell.updateUI(with: screenShareParticipant)
                bindScreenStreamState(cell: cell, with: screenShareParticipant)
                cell.setOrientationSwitchButtonHidden(orientationButtonHidden)
                cell.updateOrientationSwitchButtonImage(isLandscape: orientationButtonIsLandscape)
                return cell
            } else {
                participant = displayParticipants[indexPath.item]
            }
        } else {
            participant = displayParticipants[indexPath.item]
        }
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RoomViewVideoStreamCell.reuseIdentifier,
            for: indexPath
        ) as? RoomViewVideoStreamCell else {
            return UICollectionViewCell()
        }
        
        cell.updateUI(with: participant)
        bindVideoStreamState(cell: cell, with: participant)
        let volume = speakingUsers[participant.userID] ?? 0
        let isSpeaking = volume > 0
        cell.updateSpeakingStatus(with: participant, isSpeaking: isSpeaking)
        return cell
    }
    
    private func bindScreenStreamState(cell: RoomViewScreenStreamCell, with participant: RoomParticipant) {
        let screenParticipantPublisher = createScreenParticipantPublisher(for: participant.userID)
        screenParticipantPublisher
            .removeDuplicates { oldParticipant, newParticipant in
                oldParticipant.screenShareStatus == newParticipant.screenShareStatus
            }
            .sink { [weak cell, weak self] participant in
                guard let cell = cell else { return }
                guard let self = self else { return }
                cell.updateUI(with: participant)
                cell.participantView.setFillMode(fillMode: .fit)
                cell.participantView.updateParticipant(participant: participant)
                cell.participantView.updateStreamType(streamType: .screen)
                if isCellVisible(cell) {
                    if participant.screenShareStatus == .on {
                        cell.participantView.setActive(isActive: true)
                    } else {
                        cell.participantView.setActive(isActive: false)
                    }
                }
            }
            .store(in: &cell.cancellableSet)
        
        screenParticipantPublisher
            .removeDuplicates { oldParticipant, newParticipant in
                oldParticipant.name == newParticipant.name &&
                oldParticipant.role == newParticipant.role &&
                oldParticipant.microphoneStatus == newParticipant.microphoneStatus
            }
            .sink { [weak cell] participant in
                guard let cell = cell else { return }
                cell.updateUI(with: participant)
            }
            .store(in: &cell.cancellableSet)
    }
    
    private func bindVideoStreamState(cell: RoomViewVideoStreamCell, with participant: RoomParticipant) {
        let videoParticipantPublisher = createVideoParticipantPublisher(for: participant.userID)
        videoParticipantPublisher
            .removeDuplicates { oldParticipant, newParticipant in
                oldParticipant.cameraStatus == newParticipant.cameraStatus
            }
            .sink { [weak cell, weak self] participant in
                guard let cell = cell else { return }
                guard let self = self else { return }
                cell.updateUI(with: participant)
                cell.participantView.setFillMode(fillMode: .fill)
                cell.participantView.updateParticipant(participant: participant)
                cell.participantView.updateStreamType(streamType: .camera)
                if isCellVisible(cell) {
                    if participant.cameraStatus == .on {
                        cell.participantView.setActive(isActive: true)
                    } else {
                        cell.participantView.setActive(isActive: false)
                    }
                }
            }
            .store(in: &cell.cancellableSet)
        
        videoParticipantPublisher
            .removeDuplicates { oldParticipant, newParticipant in
                oldParticipant.name == newParticipant.name &&
                oldParticipant.role == newParticipant.role &&
                oldParticipant.microphoneStatus == newParticipant.microphoneStatus &&
                oldParticipant.avatarURL ==  newParticipant.avatarURL
        }
        .sink { [weak cell] participant in
            guard let cell = cell else { return }
            cell.updateUI(with: participant)
        }
        .store(in: &cell.cancellableSet)
    }
    
    private func createVideoParticipantPublisher(for userID: String) -> AnyPublisher<RoomParticipant, Never> {
        let participantPublisher = roomParticipantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
            .map { participantList -> RoomParticipant? in
                participantList.first { $0.userID == userID }
            }
            .eraseToAnyPublisher()
        return participantPublisher
            .compactMap{ $0 }
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }
    
    private func createScreenParticipantPublisher(for userID: String) -> AnyPublisher<RoomParticipant, Never> {
        let participantPublisher = roomParticipantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantWithScreen))
            .map { participant -> RoomParticipant? in
                if participant?.userID == userID {
                    return participant
                }
                return nil
            }
            .eraseToAnyPublisher()
        
        return participantPublisher
            .compactMap{ $0 }
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }
    
    private func isCellVisible(_ cell: UICollectionViewCell) -> Bool {
        let visibleCells = collectionView.visibleCells
        return visibleCells.contains(cell)
    }
}

// MARK: - UICollectionViewDelegate
extension StandardRoomView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoStreamCell = cell as? RoomViewVideoStreamCell else { return }
        guard let videoParticipant = displayParticipants[safe: indexPath.item] else { return }

        if videoStreamCell.participant?.userID != videoParticipant.userID {
            videoStreamCell.reset()
            videoStreamCell.updateUI(with: videoParticipant)
            bindVideoStreamState(cell: videoStreamCell, with: videoParticipant)
        }
        activateVideoRender(for: videoStreamCell, userID: videoParticipant.userID)
    }

    private func activateVideoRender(for cell: RoomViewVideoStreamCell, userID: String) {
        let latest = roomParticipantStore.state.value.participantList.first { $0.userID == userID }
        guard let participant = latest ?? cell.participant else { return }
        cell.updateUI(with: participant)
        cell.participantView.setFillMode(fillMode: .fill)
        cell.participantView.updateStreamType(streamType: .camera)
        cell.participantView.updateParticipant(participant: participant)
        cell.participantView.setActive(isActive: participant.cameraStatus == .on)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoStreamCell = cell as? RoomViewVideoStreamCell else { return }
        if let currentIndexPath = collectionView.indexPath(for: cell), currentIndexPath != indexPath {
            return
        }
        let releasedUserID = videoStreamCell.participant?.userID
        videoStreamCell.participantView.setActive(isActive: false)
        if let releasedUserID = releasedUserID {
            streamManager.restoreRenderIfShowing(userID: releasedUserID)
        }
    }
    
    // MARK: - Custom Paging Logic
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }

        let currentOffset = scrollView.contentOffset.x
        
        var targetPage: Int
        if velocity.x > 0.5 {
            targetPage = Int(ceil(currentOffset / pageWidth))
        } else if velocity.x < -0.5 {
            targetPage = Int(floor(currentOffset / pageWidth))
        } else {
            targetPage = Int(round(currentOffset / pageWidth))
        }
        
        let maxPage = Int(ceil(scrollView.contentSize.width / pageWidth)) - 1
        targetPage = max(0, min(targetPage, maxPage))
        
        targetContentOffset.pointee.x = CGFloat(targetPage) * pageWidth

                
        updatePageButtons(targetPage: targetPage)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        
        let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))
        if currentPage != self.currentPage {
            self.currentPage = currentPage
            updatePageButtons(targetPage: currentPage)
        }

        streamManager.handleScroll(offsetX: scrollView.contentOffset.x, pageWidth: pageWidth)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        notifyStreamManagerScrollEnd(scrollView)
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        notifyStreamManagerScrollEnd(scrollView)
    }

    private func notifyStreamManagerScrollEnd(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        streamManager.handleScrollEnd(offsetX: scrollView.contentOffset.x, pageWidth: pageWidth)
    }
}

// MARK: - Page Navigation
extension StandardRoomView {
    private func updatePageButtons(targetPage: Int) {
        currentPage = targetPage
        
        previousPageButton.isHidden = currentPage == 0 || totalPages <= 1
        nextPageButton.isHidden = currentPage >= totalPages - 1 || totalPages <= 1
    }
    
    private func updateTotalPages() {
        let screenSharePages = participantList.0 != nil ? 1 : 0
        let participantPages = Int(ceil(Double(displayParticipants.count) / Double(LayoutConstants.maxItemsPerPage)))
        totalPages = screenSharePages + participantPages
        
        updatePageButtons(targetPage: currentPage)
    }
}

// MARK: - Data Source Update
extension StandardRoomView {
    private func updateParticipantList(_ newParticipantList: [RoomParticipant]) {
        let oldDisplayIDs = displayParticipants.map { $0.userID }
        participantList.1 = newParticipantList
        let newDisplayIDs = displayParticipants.map { $0.userID }

        if oldDisplayIDs == newDisplayIDs {
            updateVisibleCells()
        } else {
            reloadData()
        }

        streamManager.updateLayoutMode(participants: newParticipantList,
                                       hasScreenShare: participantList.0 != nil,
                                       speakingUsers: speakingUsers)
        updateTotalPages()
    }

    private func updateVisibleCells() {
        let participantSection = participantList.0 != nil ? 1 : 0
        collectionView.visibleCells.forEach { cell in
            guard let videoCell = cell as? RoomViewVideoStreamCell else { return }
            guard let indexPath = collectionView.indexPath(for: cell) else { return }
            guard indexPath.section == participantSection else { return }
            guard indexPath.item < displayParticipants.count else { return }
            let participant = displayParticipants[indexPath.item]

            if videoCell.participant?.userID == participant.userID {
                guard videoCell.participant != participant else { return }
                videoCell.updateUI(with: participant)
            } else {
                videoCell.cancellableSet.removeAll()
                videoCell.updateUI(with: participant)
                bindVideoStreamState(cell: videoCell, with: participant)
                let volume = speakingUsers[participant.userID] ?? 0
                videoCell.updateSpeakingStatus(with: participant, isSpeaking: volume > 0)
            }
        }
    }

    private func updateScreenShareParticipant(_ newParticipant: RoomParticipant?) {
        let oldSharerID = participantList.0?.userID
        participantList.0 = newParticipant

        if oldSharerID != newParticipant?.userID {
            reloadData()
        } else {
            updateVisibleCells()
        }

        streamManager.updateLayoutMode(participants: participantList.1,
                                       hasScreenShare: newParticipant != nil,
                                       speakingUsers: speakingUsers)
        updateTotalPages()
    }
    
    private func updateVisibleCellsSpeakingStatus(_ speakingUsers: [String: Int]) {
        self.speakingUsers = speakingUsers
        collectionView.visibleCells.forEach { cell in
            guard let indexPath = collectionView.indexPath(for: cell) else { return }

            var participantOpt: RoomParticipant?
            if participantList.0 != nil {
                if indexPath.section != 0 {
                    participantOpt = displayParticipants[safe: indexPath.item]
                }
            } else {
                participantOpt = displayParticipants[safe: indexPath.item]
            }

            guard let participant = participantOpt else { return }

            if let participantCell = cell as? RoomViewVideoStreamCell {
                let volume = speakingUsers[participant.userID] ?? 0
                let isSpeaking = volume > 0
                participantCell.updateSpeakingStatus(with: participant, isSpeaking: isSpeaking)
            }
        }

        streamManager.updateSpeakingStatus(participants: participantList.1,
                                           speakingUsers: speakingUsers,
                                           collectionViewOffsetX: collectionView.contentOffset.x)
    }
}

// MARK: - Helpers
extension StandardRoomView {
    private func freshCollectionView(block: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        block()
        CATransaction.commit()
    }
    
    func reloadData() {
        freshCollectionView { [weak self] in
            guard let self = self else { return }
            collectionView.reloadData()
        }
    }
    
    func getVideoVisibleCell(_ participant: RoomParticipant) -> RoomViewVideoStreamCell? {
        let cellArray = collectionView.visibleCells
        guard let cell = cellArray.first(where: { cell in
            if let videoStreamCell = cell as? RoomViewVideoStreamCell, videoStreamCell.participant == participant {
                return true
            } else {
                return false
            }
        }) as? RoomViewVideoStreamCell else { return nil }
        return cell
    }

    private func restoreGridCellRender(userID: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let participantSection = participantList.0 != nil ? 1 : 0
            for cell in collectionView.visibleCells {
                guard let videoCell = cell as? RoomViewVideoStreamCell else { continue }
                guard let indexPath = collectionView.indexPath(for: cell),
                      indexPath.section == participantSection else { continue }
                guard let participant = videoCell.participant, participant.userID == userID else { continue }
                guard participant.cameraStatus == .on || participant.screenShareStatus == .on else { continue }
                videoCell.participantView.setActive(isActive: true)
            }
        }
    }
}
