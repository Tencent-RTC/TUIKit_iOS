//
//  StandardParticipantListView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/2/14.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore

// MARK: - StandardParticipantListView
class StandardParticipantListView: UIView, BaseView, ParticipantListContent {

    // MARK: - ParticipantListContent
    weak var actionDelegate: ParticipantListContentActionDelegate?
    var routerContext: RouterContext?

    // MARK: - Properties
    private let roomID: String

    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    private let roomStore: RoomStore = RoomStore.shared
    private var cancellableSet = Set<AnyCancellable>()

    
    private var allParticipants: [RoomParticipant] = []
    private var participantList: [RoomParticipant] = []
    
    private var allPending: [RoomParticipant] = []
    private var pendingList: [RoomParticipant] = []
    private var searchKeyword: String = ""
    private var isSegmentTapping: Bool = false
    private var isAdminVisible: Bool = false

    private var rejectedTipUserIDs: Set<String> = []
    private var rejectedTipDismissWorkItems: [String: DispatchWorkItem] = [:]
    private static let rejectedTipDuration: TimeInterval = 3.0

    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = RoomCornerRadius.extraLarge
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private lazy var dropButton: RoomDragHandleButton = RoomDragHandleButton()

    private lazy var searchContainer: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()

    private lazy var searchIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_participant_search")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var searchTextField: UITextField = {
        let field = UITextField()
        field.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        field.textColor = RoomColors.g7.withAlphaComponent(0.3)
        field.borderStyle = .none
        field.clearButtonMode = .never
        field.returnKeyType = .search
        field.delegate = self
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.attributedPlaceholder = NSAttributedString(
            string: .searchMembers,
            attributes: [
                .foregroundColor: RoomColors.g6.withAlphaComponent(0.3),
                .font: RoomFonts.pingFangSCFont(size: 14, weight: .medium)
            ]
        )
        field.inputAccessoryView = makeKeyboardToolbar()
        return field
    }()

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSearchKeyboard))
        toolbar.items = [flexibleSpace, doneButton]
        return toolbar
    }

    private lazy var topSegmentView: UISegmentedControl = {
        let topSegmentView = UISegmentedControl(frame: .zero)
        topSegmentView.insertSegment(withTitle: String.joined.localizedReplace("0"), at: 0, animated: true)
        topSegmentView.insertSegment(withTitle: String.notJoined.localizedReplace("0"), at: 1, animated: true)
        topSegmentView.selectedSegmentIndex = 0
        topSegmentView.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        topSegmentView.selectedSegmentTintColor = RoomColors.selectedSegmentTintColor.withAlphaComponent(0.3)
        topSegmentView.setTitleTextAttributes([
            .foregroundColor: RoomColors.g6,
            .font: RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        ], for: .normal)
        topSegmentView.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: RoomFonts.pingFangSCFont(size: 14, weight: .medium)
        ], for: .selected)
        return topSegmentView
    }()

    private lazy var scrollContainerView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.delegate = self
        return scrollView
    }()

    private lazy var participantTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.tag = 0
        tableView.register(ParticipantListCell.self, forCellReuseIdentifier: ParticipantListCell.cellReuseIdentifier)
        return tableView
    }()

    private lazy var pendingTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.tag = 2
        tableView.register(PendingListCell.self, forCellReuseIdentifier: PendingListCell.cellReuseIdentifier)
        return tableView
    }()

    private lazy var bottomBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var muteAllAudioButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(RoomColors.g6, for: .normal)
        button.setTitleColor(RoomColors.endTitleColor, for: .selected)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        button.backgroundColor = RoomColors.g3
        button.layer.cornerRadius = 6
        button.setTitle(.muteAll, for: .normal)
        button.setTitle(.unmuteAll, for: .selected)
        button.isHidden = true
        return button
    }()

    private lazy var muteAllVideoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(RoomColors.g6, for: .normal)
        button.setTitleColor(RoomColors.endTitleColor, for: .selected)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        button.backgroundColor = RoomColors.g3
        button.layer.cornerRadius = 6
        button.setTitle(.stopAllVideo, for: .normal)
        button.setTitle(.enableAllVideo, for: .selected)
        button.isHidden = true
        return button
    }()

    private lazy var callAllButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        button.backgroundColor = RoomColors.b1
        button.layer.cornerRadius = 6
        button.setTitle(.callAll, for: .normal)
        button.isHidden = true
        return button
    }()

    // MARK: - Initialization
    init(roomID: String) {
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
        rejectedTipDismissWorkItems.values.forEach { $0.cancel() }
    }

    // MARK: - BaseView
    func setupViews() {
        addSubview(containerView)
        containerView.addSubview(dropButton)
        containerView.addSubview(searchContainer)
        searchContainer.addSubview(searchIconView)
        searchContainer.addSubview(searchTextField)
        containerView.addSubview(topSegmentView)
        containerView.addSubview(scrollContainerView)
        scrollContainerView.addSubview(participantTableView)
        scrollContainerView.addSubview(pendingTableView)
        containerView.addSubview(bottomBarView)
        bottomBarView.addSubview(muteAllAudioButton)
        bottomBarView.addSubview(muteAllVideoButton)
        containerView.addSubview(callAllButton)
    }

    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.right.equalToSuperview()
        }

        searchContainer.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.medium)
            make.height.equalTo(36)
        }

        searchIconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }

        searchTextField.snp.makeConstraints { make in
            make.left.equalTo(searchIconView.snp.right).offset(8)
            make.right.equalToSuperview().offset(-12)
            make.top.bottom.equalToSuperview()
        }

        topSegmentView.snp.makeConstraints { make in
            make.top.equalTo(searchContainer.snp.bottom).offset(RoomSpacing.medium)
            make.left.equalToSuperview().offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.medium)
        }

        bottomBarView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(88)
        }

        callAllButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.medium)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(40)
        }

        scrollContainerView.snp.makeConstraints { make in
            make.top.equalTo(topSegmentView.snp.bottom).offset(RoomSpacing.medium)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(bottomBarView.snp.top)
        }

        participantTableView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview()
            make.width.equalTo(scrollContainerView.snp.width)
            make.height.equalTo(scrollContainerView.snp.height)
        }

        pendingTableView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalTo(participantTableView.snp.right)
            make.width.equalTo(scrollContainerView.snp.width)
            make.height.equalTo(scrollContainerView.snp.height)
            make.right.equalToSuperview()
        }

        muteAllAudioButton.snp.makeConstraints { make in
            make.top.equalTo(bottomBarView).offset(RoomSpacing.medium)
            make.right.equalTo(bottomBarView.snp.centerX).offset(-RoomSpacing.large)
            make.width.equalTo(108)
            make.height.equalTo(40)
        }

        muteAllVideoButton.snp.makeConstraints { make in
            make.centerY.equalTo(muteAllAudioButton)
            make.left.equalTo(bottomBarView.snp.centerX).offset(RoomSpacing.medium)
            make.width.equalTo(muteAllAudioButton)
            make.height.equalTo(40)
        }
    }

    func setupStyles() {
        backgroundColor = .clear
    }

    func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        topSegmentView.addTarget(self, action: #selector(topSegmentViewValueChanged(sender:)), for: .valueChanged)
        muteAllAudioButton.addTarget(self, action: #selector(muteAllAudioButtonTapped), for: .touchUpInside)
        muteAllVideoButton.addTarget(self, action: #selector(muteAllVideoButtonTapped), for: .touchUpInside)
        callAllButton.addTarget(self, action: #selector(callAllButtonTapped), for: .touchUpInside)
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)

        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                self.updateParticipants(participantList)
            }
            .store(in: &cancellableSet)

        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom?.participantCount))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantCount in
                guard let self = self else { return }
                let count = participantCount ?? 0
                self.topSegmentView.setTitle(.joined.localizedReplace("\(count)"), forSegmentAt: 0)
            }
            .store(in: &cancellableSet)

        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                let isAdmin = participant?.role == .admin || participant?.role == .owner
                self.isAdminVisible = isAdmin
                self.refreshBottomVisibility()
            }
            .store(in: &cancellableSet)

        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] currentRoom in
                guard let self = self else { return }
                if let currentRoom = currentRoom {
                    self.muteAllAudioButton.isHidden = false
                    self.muteAllVideoButton.isHidden = false
                    self.muteAllAudioButton.isSelected = currentRoom.isAllMicrophoneDisabled
                    self.muteAllVideoButton.isSelected = currentRoom.isAllCameraDisabled
                } else {
                    self.muteAllAudioButton.isHidden = true
                    self.muteAllVideoButton.isHidden = true
                }
            }
            .store(in: &cancellableSet)

        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.pendingParticipantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] pendingList in
                guard let self = self else { return }
                let filtered = pendingList.filter { $0.roomStatus != .inRoom }
                self.syncRejectedTips(newList: filtered)
                self.allPending = filtered
                self.topSegmentView.setTitle(.notJoined.localizedReplace("\(filtered.count)"), forSegmentAt: 1)
                self.applyPendingFilter()
            }
            .store(in: &cancellableSet)
    }

    private func syncRejectedTips(newList: [RoomParticipant]) {
        let previousStatusMap = Dictionary(
            allPending.map { ($0.userID, $0.roomStatus) },
            uniquingKeysWith: { first, _ in first }
        )
        let currentUserIDs = Set(newList.map { $0.userID })

        for userID in rejectedTipUserIDs.subtracting(currentUserIDs) {
            hideRejectedTip(for: userID)
        }

        for participant in newList {
            let userID = participant.userID
            if participant.roomStatus == .callRejected {
                if previousStatusMap[userID] != .callRejected {
                    showRejectedTip(for: userID)
                }
            } else {
                hideRejectedTip(for: userID)
            }
        }
    }

    private func showRejectedTip(for userID: String) {
        rejectedTipDismissWorkItems[userID]?.cancel()
        rejectedTipUserIDs.insert(userID)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.rejectedTipUserIDs.remove(userID)
            self.rejectedTipDismissWorkItems[userID] = nil
            self.pendingTableView.reloadData()
        }
        rejectedTipDismissWorkItems[userID] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rejectedTipDuration, execute: workItem)
    }

    private func hideRejectedTip(for userID: String) {
        rejectedTipDismissWorkItems[userID]?.cancel()
        rejectedTipDismissWorkItems[userID] = nil
        rejectedTipUserIDs.remove(userID)
    }

    // MARK: - Data
    private func updateParticipants(_ participants: [RoomParticipant]) {
        allParticipants = participants
        participantList = sortedJoined(filterBySearch(allParticipants))
        participantTableView.reloadData()
    }

    private func applyPendingFilter() {
        pendingList = sortedPending(filterBySearch(allPending))
        pendingTableView.reloadData()
    }

    
    private func filterBySearch(_ source: [RoomParticipant]) -> [RoomParticipant] {
        guard !searchKeyword.isEmpty else { return source }
        let keyword = searchKeyword.lowercased()
        return source.filter {
            $0.userName.lowercased().contains(keyword) || $0.userID.lowercased().contains(keyword)
        }
    }

    private func sortedJoined(_ list: [RoomParticipant]) -> [RoomParticipant] {
        let localUserID = participantStore.state.value.localParticipant?.userID ?? ""
        return list.sortedForParticipantList(localUserID: localUserID)
    }

    private func sortedPending(_ list: [RoomParticipant]) -> [RoomParticipant] {
        list.sorted { $0.userName < $1.userName }
    }

    private func refreshBottomVisibility() {
        let isNotJoinedTab = topSegmentView.selectedSegmentIndex == 1
        bottomBarView.isHidden = isNotJoinedTab || !isAdminVisible
        callAllButton.isHidden = !isNotJoinedTab
    }

    private func canInteractWith(participant: RoomParticipant) -> Bool {
        guard let localParticipant = participantStore.state.value.localParticipant else {
            return false
        }
        return localParticipant.role.rawValue < participant.role.rawValue
    }

    // MARK: - Actions
    @objc private func dropButtonTapped() {
        actionDelegate?.participantListContentRequestDismiss()
    }

    @objc private func topSegmentViewValueChanged(sender: UISegmentedControl) {
        isSegmentTapping = true
        let index = sender.selectedSegmentIndex
        let offsetX = CGFloat(index) * scrollContainerView.bounds.width
        scrollContainerView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
        refreshBottomVisibility()
    }

    @objc private func searchTextChanged(_ textField: UITextField) {
        if textField.markedTextRange != nil { return }
        searchKeyword = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        applySearch()
    }

    private func applySearch() {
        participantList = sortedJoined(filterBySearch(allParticipants))
        participantTableView.reloadData()
        pendingList = sortedPending(filterBySearch(allPending))
        pendingTableView.reloadData()
    }

    @objc private func dismissSearchKeyboard() {
        searchTextField.resignFirstResponder()
    }

    @objc private func muteAllAudioButtonTapped(sender: UIButton) {
        actionDelegate?.participantListContent(muteAllAudioDisable: !sender.isSelected)
    }

    @objc private func muteAllVideoButtonTapped(sender: UIButton) {
        actionDelegate?.participantListContent(muteAllVideoDisable: !sender.isSelected)
    }

    @objc private func callAllButtonTapped() {
        let userIDs = allPending.map { $0.userID }
        guard !userIDs.isEmpty else { return }
        roomStore.callUserToRoom(roomID: roomID,
                                 userIDList: userIDs,
                                 timeout: 10,
                                 extensionInfo: nil) { _ in
        }
    }
}

// MARK: - UIScrollViewDelegate
extension StandardParticipantListView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == scrollContainerView, scrollView.bounds.width > 0, !isSegmentTapping else { return }
        let offsetX = scrollView.contentOffset.x
        let pageWidth = scrollView.bounds.width
        let pageIndex = Int(round(offsetX / pageWidth))
        if topSegmentView.selectedSegmentIndex != pageIndex {
            topSegmentView.selectedSegmentIndex = pageIndex
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == scrollContainerView else { return }
        isSegmentTapping = false
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == scrollContainerView else { return }
        isSegmentTapping = false
    }
}

// MARK: - UITableViewDataSource
extension StandardParticipantListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == participantTableView {
            return participantList.count
        }
        if tableView == pendingTableView {
            return pendingList.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == participantTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ParticipantListCell.cellReuseIdentifier, for: indexPath) as? ParticipantListCell else {
                return UITableViewCell()
            }
            let participant = participantList[indexPath.row]
            cell.configure(with: participant, roomID: roomID, roomType: .standard)
            return cell
        }

        if tableView == pendingTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: PendingListCell.cellReuseIdentifier, for: indexPath) as? PendingListCell else {
                return UITableViewCell()
            }
            let pending = pendingList[indexPath.row]
            cell.configure(with: pending, roomID: roomID,
                           showRejectedTip: rejectedTipUserIDs.contains(pending.userID))
            cell.onCallTapped = { [weak self] participant in
                guard let self = self else { return }
                self.roomStore.callUserToRoom(
                    roomID: self.roomID,
                    userIDList: [participant.userID],
                    timeout: 60,
                    extensionInfo: nil
                ) { _ in
                }
            }
            return cell
        }
        return UITableViewCell()
    }
}

// MARK: - UITableViewDelegate
extension StandardParticipantListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard tableView == participantTableView else { return }
        let participant = participantList[indexPath.row]
        guard canInteractWith(participant: participant) else { return }
        actionDelegate?.participantListContent(didTap: participant, isAudience: false)
    }
}

// MARK: - UITextFieldDelegate
extension StandardParticipantListView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Localized
fileprivate extension String {
    static let muteAll = "roomkit_mute_all_audio".localized
    static let unmuteAll = "roomkit_unmute_all_audio".localized
    static let stopAllVideo = "roomkit_disable_all_video".localized
    static let enableAllVideo = "roomkit_enable_all_video".localized
    static let joined = "roomkit_tab_joined"
    static let notJoined = "roomkit_tab_pending"
    static let callAll = "roomkit_call_everyone".localized
    static let searchMembers = "roomkit_search_members".localized
}
