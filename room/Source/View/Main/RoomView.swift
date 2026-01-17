//
//  RoomView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/24.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore

struct DataChanges {
    let deletions: [IndexPath]
    let insertions: [IndexPath]
    let moves: [(from: IndexPath, to: IndexPath)]
    
    var hasChanges: Bool {
        return !deletions.isEmpty || !insertions.isEmpty || !moves.isEmpty
    }
}

// MARK: - RoomView Component
public class RoomView: UIView, BaseView {
    // MARK: - BaseView Properties
    public weak var routerContext: RouterContext?
    private let roomID: String
    
    private lazy var roomParticipantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    // MARK: - Constants
    private struct LayoutConstants {
        static let itemSize: CGSize = CGSize(width: 176, height: 176)
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
        return button
    }()
    
    private lazy var nextPageButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_next_page_icon"), for: .normal)
        return button
    }()
    
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
    
    public func setupBindings() {
        // MARK: - Real Data Binding
        roomParticipantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                updateParticipantList(participantList)
            }
            .store(in: &cancellableSet)
        
        roomParticipantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantWithScreen))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                updateScreenShareParticipant(participant)
            }
            .store(in: &cancellableSet)
        
        roomParticipantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.speakingUsers))
            .receive(on: RunLoop.main)
            .sink { [weak self] speakingUsers in
                guard let self = self else { return }
                updateVisibleCellsSpeakingStatus(speakingUsers)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - UICollectionViewDataSource
extension RoomView: UICollectionViewDataSource {
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
                return participantList.1.count 
            }
        }
        return participantList.1.count
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
                return cell
            } else {
                participant = participantList.1[indexPath.item]
            }
        } else {
            participant = participantList.1[indexPath.item]
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
            .receive(on: RunLoop.main)
            .removeDuplicates { oldParticipant, newParticipant in
                oldParticipant.screenShareStatus == newParticipant.screenShareStatus
            }
            .sink { [weak cell, weak self] participant in
                guard let cell = cell else { return }
                guard let self = self else { return }
                cell.updateUI(with: participant)
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
            .receive(on: RunLoop.main)
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
            .receive(on: RunLoop.main)
            .removeDuplicates { oldParticipant, newParticipant in
                oldParticipant.cameraStatus == newParticipant.cameraStatus
            }
            .sink { [weak cell, weak self] participant in
                guard let cell = cell else { return }
                guard let self = self else { return }
                cell.updateUI(with: participant)
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
            .receive(on: RunLoop.main)
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
            .receive(on: RunLoop.main)
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
            .receive(on: RunLoop.main)
            .share()
            .eraseToAnyPublisher()
    }
    
    private func isCellVisible(_ cell: UICollectionViewCell) -> Bool {
        let visibleCells = collectionView.visibleCells
        return visibleCells.contains(cell)
    }
}

// MARK: - UICollectionViewDelegate
extension RoomView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoStreamCell = cell as? RoomViewVideoStreamCell else { return }
        guard let videoParticipant = participantList.1[safe: indexPath.item] else { return }
        guard let participant = videoStreamCell.participant else { return }

        if videoParticipant.userID != participant.userID {
            videoStreamCell.reset()
            videoStreamCell.updateUI(with: videoParticipant)
            bindVideoStreamState(cell: videoStreamCell, with: videoParticipant)
        } else {
            if participant.cameraStatus == .on {
                videoStreamCell.participantView.setActive(isActive: true)
            } else {
                videoStreamCell.participantView.setActive(isActive: false)
            }
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoStreamCell = cell as? RoomViewVideoStreamCell else { return }
        videoStreamCell.participantView.setActive(isActive: false)
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
    }

}

// MARK: - Page Navigation
extension RoomView {
    private func updatePageButtons(targetPage: Int) {
        currentPage = targetPage
        
        previousPageButton.isHidden = currentPage == 0 || totalPages <= 1
        nextPageButton.isHidden = currentPage >= totalPages - 1 || totalPages <= 1
    }
    
    private func updateTotalPages() {
        let screenSharePages = participantList.0 != nil ? 1 : 0
        let participantPages = Int(ceil(Double(participantList.1.count) / Double(LayoutConstants.maxItemsPerPage)))
        totalPages = screenSharePages + participantPages
        
        updatePageButtons(targetPage: currentPage)
    }
}

// MARK: - Data Source Update
extension RoomView {
    private func updateParticipantList(_ newParticipantList: [RoomParticipant]) {
        let oldList = self.participantList.1
        
        let changes = calculateParticipantListChanges(from: oldList, to: newParticipantList)
    
        guard changes.hasChanges else {return}
        
        freshCollectionView { [ weak self] in
            guard let self = self else { return }
            collectionView.performBatchUpdates { [weak self] in
                guard let self = self else { return }
                participantList.1 = newParticipantList
                collectionView.deleteItems(at: changes.deletions)
                collectionView.insertItems(at: changes.insertions)
                changes.moves.forEach { [weak self] move in
                    guard let self = self else { return }
                    collectionView.moveItem(at: move.from, to: move.to)
                }
            }
        }
        
        updateTotalPages()
    }
    
    private func updateScreenShareParticipant(_ newParticipant: RoomParticipant?) {
        let oldParticipant = participantList.0
        
        if oldParticipant == nil && newParticipant == nil {
            return
        }
        
        if oldParticipant == nil && newParticipant != nil {
            participantList.0 = newParticipant
            collectionView.performBatchUpdates {
                collectionView.insertSections(IndexSet(integer: 0))
            }
            updateTotalPages()
            return
        }
        
        if oldParticipant != nil && newParticipant == nil {
            participantList.0 = nil
            collectionView.performBatchUpdates {
                collectionView.deleteSections(IndexSet(integer: 0))
            }
            updateTotalPages()
            return
        }
        
        if oldParticipant?.userID != newParticipant?.userID {
            participantList.0 = newParticipant
            collectionView.reloadSections(IndexSet(integer: 0))
            return
        }
        
        participantList.0 = newParticipant
        if let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? RoomViewScreenStreamCell,
           let participant = newParticipant {
            cell.updateUI(with: participant)
            bindScreenStreamState(cell: cell, with: participant)
        }
    }
    
    private func updateVisibleCellsSpeakingStatus(_ speakingUsers: [String: Int]) {
           self.speakingUsers = speakingUsers
           collectionView.visibleCells.forEach { cell in
               guard let indexPath = collectionView.indexPath(for: cell) else { return }
               
               var participantOpt: RoomParticipant?
               if participantList.0 != nil {
                   if indexPath.section != 0 {
                       participantOpt = participantList.1[indexPath.item]
                   }
               } else {
                   participantOpt = participantList.1[indexPath.item]
               }
               
               guard let participant = participantOpt else { return }
               
               if let participantCell = cell as? RoomViewVideoStreamCell {
                   let volume = speakingUsers[participant.userID] ?? 0
                   let isSpeaking = volume > 0
                   participantCell.updateSpeakingStatus(with: participant, isSpeaking: isSpeaking)
               }
           }
       }
}

// MARK: - Incremental Update Helpers
extension RoomView {
    private func calculateParticipantListChanges(from oldList: [RoomParticipant], to newList: [RoomParticipant]) -> DataChanges {
        let section = participantList.0 != nil ? 1 : 0
        var deletions: [IndexPath] = []
        var insertions: [IndexPath] = []
        var moves: [(from: IndexPath, to: IndexPath)] = []
        
        let oldIDs = oldList.map { $0.userID }
        let newIDs = newList.map { $0.userID }
        
        let oldIDToIndex = Dictionary(uniqueKeysWithValues: oldIDs.enumerated().map { ($1, $0) })
        let newIDToIndex = Dictionary(uniqueKeysWithValues: newIDs.enumerated().map { ($1, $0) })
        
        let deletedKeys = Set(oldIDs).subtracting(newIDs)
        let insertedKeys = Set(newIDs).subtracting(oldIDs)
        let retainedKeys = Set(oldIDs).intersection(newIDs)
        
        deletions = deletedKeys.compactMap { oldIDToIndex[$0] }.map { IndexPath(item: $0, section: section) }.sorted { $0.item > $1.item }
        insertions = insertedKeys.compactMap { newIDToIndex[$0] }.map { IndexPath(item: $0, section: section) }.sorted { $0.item < $1.item }
   
        var processedIndices = Set<String>()
        for key in retainedKeys {
            guard let oldIndex = oldIDToIndex[key],
                  let newIndex = newIDToIndex[key],
                  oldIndex != newIndex,
                  !processedIndices.contains(key) else {
                continue
            }
            let fromPath = IndexPath(item: oldIndex, section: section)
            let toPath = IndexPath(item: newIndex, section: section)
            if !deletions.contains(fromPath) && !insertions.contains(toPath) {
                moves.append((from: fromPath, to: toPath))
                processedIndices.insert(key)
            }
        }
        moves.sort { $0.from.item < $1.from.item }
        
        return DataChanges(
            deletions: deletions,
            insertions: insertions,
            moves: moves
        )
    }
    
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
}
