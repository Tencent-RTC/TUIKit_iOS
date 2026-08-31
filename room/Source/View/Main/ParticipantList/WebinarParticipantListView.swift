//
//  WebinarParticipantListView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/2/14.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore

// MARK: - WebinarParticipantListView
class WebinarParticipantListView: UIView, BaseView, ParticipantListContent {

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

    private var participantList: [RoomParticipant] = []
    private var audienceList: [RoomParticipant] = []
    private var isSegmentTapping: Bool = false

    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = RoomCornerRadius.extraLarge
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private lazy var dropButton: RoomDragHandleButton = RoomDragHandleButton()

    private lazy var topSegmentView: UISegmentedControl = {
        let topSegmentView = UISegmentedControl(frame: .zero)
        topSegmentView.insertSegment(withTitle: String.participant.localizedReplace("0"), at: 0, animated: true)
        topSegmentView.insertSegment(withTitle: String.audience.localizedReplace("0"), at: 1, animated: true)
        topSegmentView.selectedSegmentIndex = 0
        topSegmentView.selectedSegmentTintColor = RoomColors.g3
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

    private lazy var audienceTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.tag = 1
        tableView.register(AudienceListCell.self, forCellReuseIdentifier: AudienceListCell.cellReuseIdentifier)
        return tableView
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

    // MARK: - BaseView
    func setupViews() {
        addSubview(containerView)
        containerView.addSubview(dropButton)
        containerView.addSubview(topSegmentView)
        containerView.addSubview(scrollContainerView)
        scrollContainerView.addSubview(participantTableView)
        scrollContainerView.addSubview(audienceTableView)
        containerView.addSubview(muteAllAudioButton)
    }

    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.right.equalToSuperview()
        }

        topSegmentView.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.medium)
        }

        scrollContainerView.snp.makeConstraints { make in
            make.top.equalTo(topSegmentView.snp.bottom).offset(RoomSpacing.medium)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(muteAllAudioButton.snp.top).offset(-5)
        }

        participantTableView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview()
            make.width.equalTo(scrollContainerView.snp.width)
            make.height.equalTo(scrollContainerView.snp.height)
        }

        audienceTableView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalTo(participantTableView.snp.right)
            make.width.equalTo(scrollContainerView.snp.width)
            make.height.equalTo(scrollContainerView.snp.height)
            make.right.equalToSuperview()
        }

        muteAllAudioButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.left.equalToSuperview().offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.medium)
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
                self.topSegmentView.setTitle(.participant.localizedReplace("\(participantCount ?? 0)"), forSegmentAt: 0)
            }
            .store(in: &cancellableSet)

        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom?.audienceCount))
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceCount in
                guard let self = self else { return }
                self.topSegmentView.setTitle(.audience.localizedReplace("\(audienceCount ?? 0)"), forSegmentAt: 1)
            }
            .store(in: &cancellableSet)

        let adminPublisher = participantStore.state.subscribe(StatePublisherSelector(keyPath: \.adminList))
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.audienceList))
            .combineLatest(adminPublisher)
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceList, adminList in
                guard let self = self else { return }
                self.updateAudienceList(audienceList: audienceList, adminList: adminList)
            }
            .store(in: &cancellableSet)

        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                self.muteAllAudioButton.isHidden = !(participant?.role == .admin || participant?.role == .owner)
            }
            .store(in: &cancellableSet)

        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] currentRoom in
                guard let self = self else { return }
                if let currentRoom = currentRoom {
                    self.muteAllAudioButton.isSelected = currentRoom.isAllMicrophoneDisabled
                }
            }
            .store(in: &cancellableSet)
    }

    // MARK: - Data
    private func updateParticipants(_ participants: [RoomParticipant]) {
        let localUserID = participantStore.state.value.localParticipant?.userID ?? ""
        participantList = participants.sortedForParticipantList(localUserID: localUserID)
        participantTableView.reloadData()
    }

    private func updateAudienceList(audienceList: [RoomUser], adminList: [RoomUser]) {
        let adminUsrIDList = adminList.map { $0.userID }
        var newAudienceList: [RoomParticipant] = []
        audienceList.forEach { audience in
            var participant = RoomParticipant()
            participant.userID = audience.userID
            participant.userName = audience.userName
            participant.avatarURL = audience.avatarURL
            participant.role = adminUsrIDList.contains(audience.userID) ? .admin : .generalUser
            newAudienceList.append(participant)
        }

        let localUserID = participantStore.state.value.localParticipant?.userID ?? ""
        self.audienceList = newAudienceList.sortedForParticipantList(localUserID: localUserID)
        audienceTableView.reloadData()
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
    }

    @objc private func muteAllAudioButtonTapped(sender: UIButton) {
        actionDelegate?.participantListContent(muteAllAudioDisable: !sender.isSelected)
    }
}

// MARK: - UIScrollViewDelegate
extension WebinarParticipantListView: UIScrollViewDelegate {
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
extension WebinarParticipantListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == participantTableView {
            return participantList.count
        }
        if tableView == audienceTableView {
            return audienceList.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == participantTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ParticipantListCell.cellReuseIdentifier, for: indexPath) as? ParticipantListCell else {
                return UITableViewCell()
            }
            let participant = participantList[indexPath.row]
            cell.configure(with: participant, roomID: roomID, roomType: .webinar)
            return cell
        }

        if tableView == audienceTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AudienceListCell.cellReuseIdentifier, for: indexPath) as? AudienceListCell else {
                return UITableViewCell()
            }
            let audience = audienceList[indexPath.row]
            cell.configure(with: audience, roomID: roomID)
            return cell
        }
        return UITableViewCell()
    }
}

// MARK: - UITableViewDelegate
extension WebinarParticipantListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var participant: RoomParticipant?
        var isAudience = false
        if tableView == participantTableView {
            participant = participantList[indexPath.row]
        } else if tableView == audienceTableView {
            participant = audienceList[indexPath.row]
            isAudience = true
        }

        guard let participant = participant else { return }
        guard canInteractWith(participant: participant) else { return }
        actionDelegate?.participantListContent(didTap: participant, isAudience: isAudience)
    }
}

// MARK: - Localized
fileprivate extension String {
    static let muteAll = "roomkit_mute_all_audio".localized
    static let unmuteAll = "roomkit_unmute_all_audio".localized
    static let participant = "roomkit_participant".localized
    static let audience = "roomkit_audience".localized
}
