//
//  ParticipantListView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/25.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore
import Kingfisher

public protocol ParticipantListViewDelegate: AnyObject {
    func muteAllAudioButtonTapped(disable: Bool)
    func muteAllVideoButtonTapped(disable: Bool)
    func participantTapped(view: ParticipantListView, participant: RoomParticipant, isAudience: Bool)
}

// MARK: - ParticipantListView
public class ParticipantListView: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    weak public var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    public var panelHeight: CGFloat {
        return UIScreen.main.bounds.height * 0.8
    }
    
    public weak var delegate: ParticipantListViewDelegate?
   
    // MARK: - Properties
    
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    private let roomStore: RoomStore = RoomStore.shared
    private var participantList: [RoomParticipant] = []
    private var audienceList: [RoomParticipant] = []
    private var cancellableSet = Set<AnyCancellable>()
    private let roomID: String
    private let roomType: RoomType
    private var isSegmentTapping: Bool = false
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = RoomCornerRadius.extraLarge
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var dropButton: UIButton = {
        let dropButton = UIButton()
        dropButton.setImage(ResourceLoader.loadImage("room_drop_arrow"), for: .normal)
        dropButton.imageView?.contentMode = .center
        return dropButton
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g7
        label.textAlignment = .left
        return label
    }()
    
    private lazy var topSegmentView: UISegmentedControl = {
        let topSegmentView = UISegmentedControl(frame: .zero)
        topSegmentView.insertSegment(withTitle: .participant.localizedReplace("0"), at: 0, animated: true)
        topSegmentView.insertSegment(withTitle: .audience.localizedReplace("0"), at: 1, animated: true)
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
    
    // MARK: - Initialization
    public init(roomID: String, roomType: RoomType) {
        self.roomID = roomID
        self.roomType = roomType
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - BaseView Implementation
    func setupViews() {
        addSubview(containerView)
        containerView.addSubview(dropButton)
        if roomType == .standard {
            containerView.addSubview(titleLabel)
            containerView.addSubview(participantTableView)
            
            containerView.addSubview(bottomBarView)
            bottomBarView.addSubview(muteAllAudioButton)
            bottomBarView.addSubview(muteAllVideoButton)
        } else {
            containerView.addSubview(topSegmentView)
            containerView.addSubview(scrollContainerView)
            scrollContainerView.addSubview(participantTableView)
            scrollContainerView.addSubview(audienceTableView)
        }
    }
    
    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        if roomType == .standard {
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
                make.left.equalToSuperview().offset(RoomSpacing.standard)
                make.right.equalToSuperview().offset(-RoomSpacing.standard)
            }
            
            participantTableView.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(RoomSpacing.medium)
                make.left.right.equalToSuperview()
                make.bottom.equalTo(bottomBarView.snp.top)
            }
            
            bottomBarView.snp.makeConstraints { make in
                make.left.right.bottom.equalToSuperview()
                make.height.equalTo(88)
            }
            
            muteAllAudioButton.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(RoomSpacing.medium)
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
        } else {
            topSegmentView.snp.makeConstraints { make in
                make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
                make.left.equalToSuperview().offset(RoomSpacing.medium)
                make.right.equalToSuperview().offset(-RoomSpacing.medium)
            }
            
            scrollContainerView.snp.makeConstraints { make in
                make.top.equalTo(topSegmentView.snp.bottom).offset(RoomSpacing.medium)
                make.left.right.equalToSuperview()
                make.bottom.equalToSuperview()
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
        }
    }
    
    func setupStyles() {
        backgroundColor = .clear
    }
    
    func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        muteAllAudioButton.addTarget(self, action: #selector(muteAllAudioButtonTapped), for: .touchUpInside)
        muteAllVideoButton.addTarget(self, action: #selector(muteAllVideoButtonTapped), for: .touchUpInside)
        
        if roomType == .standard {
            bindingStandardState()
        } else {
            topSegmentView.addTarget(self, action: #selector(topSegmentViewValueChanged(sender:)), for: .valueChanged)
            bindingWebinarState()
        }
        
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                updateParticipants(participantList)
            }
            .store(in: &cancellableSet)
    }
    
    private func bindingStandardState() {
        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom?.participantCount))
             .receive(on: RunLoop.main)
             .sink { [weak self] participantCount in
                 guard let self = self else { return }
                 titleLabel.text = .members.localizedReplace("\(participantCount ?? 0)")
             }
             .store(in: &cancellableSet)
        
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                bottomBarView.isHidden = !(participant?.role == .admin || participant?.role == .owner)
            }
            .store(in: &cancellableSet)
        
        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] currentRoom in
                guard let self = self else { return }
                if let currentRoom = currentRoom {
                    muteAllAudioButton.isHidden = false
                    muteAllVideoButton.isHidden = false
                    
                    muteAllAudioButton.isSelected = currentRoom.isAllMicrophoneDisabled
                    muteAllVideoButton.isSelected = currentRoom.isAllCameraDisabled
                } else {
                    muteAllAudioButton.isHidden = true
                    muteAllVideoButton.isHidden = true
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func bindingWebinarState() {
        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom?.participantCount))
             .receive(on: RunLoop.main)
             .sink { [weak self] participantCount in
                 guard let self = self else { return }
                 topSegmentView.setTitle(.participant.localizedReplace("\(participantCount ?? 0)"), forSegmentAt: 0)
             }
             .store(in: &cancellableSet)
        
        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom?.audienceCount))
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceCount in
                guard let self = self else { return }
                topSegmentView.setTitle(.audience.localizedReplace("\(audienceCount ?? 0)"), forSegmentAt: 1)
            }
            .store(in: &cancellableSet)
        
        let adminPublisher = participantStore.state.subscribe(StatePublisherSelector(keyPath: \.adminList))
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.audienceList))
            .combineLatest(adminPublisher)
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceList, adminList in
                guard let self = self else { return }
                updateAudienceList(audienceList: audienceList, adminList: adminList)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Private Methods
extension ParticipantListView {
    private func updateParticipants(_ participants: [RoomParticipant]) {
        participantList = sortParticipants(participants)
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
        
        self.audienceList = sortParticipants(newAudienceList)
        audienceTableView.reloadData()
    }
    
    private func sortParticipants(_ participants: [RoomParticipant]) -> [RoomParticipant] {
        let localUserID = participantStore.state.value.localParticipant?.userID ?? ""
        
        return participants.sorted { p1, p2 in
            let rolePriority1 = getRolePriority(p1, localUserID: localUserID)
            let rolePriority2 = getRolePriority(p2, localUserID: localUserID)
            
            if rolePriority1 != rolePriority2 {
                return rolePriority1 < rolePriority2
            }
            
            let devicePriority1 = getDevicePriority(p1)
            let devicePriority2 = getDevicePriority(p2)
            
            if devicePriority1 != devicePriority2 {
                return devicePriority1 < devicePriority2
            }
            
            return p1.userName < p2.userName
        }
    }
    
    private func getRolePriority(_ participant: RoomParticipant, localUserID: String) -> Int {
        if participant.userID == localUserID { return 0 }
        if participant.role == .owner { return 1 }
        if participant.role == .admin { return 2 }
        return 3
    }
    
    private func getDevicePriority(_ participant: RoomParticipant) -> Int {
        if participant.screenShareStatus == .on { return 0 }
        if participant.cameraStatus == .on && participant.microphoneStatus == .on { return 1 }
        if participant.cameraStatus == .on { return 2 }
        if participant.microphoneStatus == .on { return 3 }
        return 4
    }
}

// MARK: - Actions
extension ParticipantListView {
    @objc private func dropButtonTapped() {
        dismiss()
    }
    
    @objc private func muteAllAudioButtonTapped(sender: UIButton) {
        delegate?.muteAllAudioButtonTapped(disable: !sender.isSelected)
    }
    
    @objc private func muteAllVideoButtonTapped(sender: UIButton) {
        delegate?.muteAllVideoButtonTapped(disable: !sender.isSelected)
    }
    
    @objc private func topSegmentViewValueChanged(sender: UISegmentedControl) {
        isSegmentTapping = true
        let index = sender.selectedSegmentIndex
        let offsetX = CGFloat(index) * scrollContainerView.bounds.width
        scrollContainerView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
    }
    
}

// MARK: - UIScrollViewDelegate
extension ParticipantListView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == scrollContainerView, scrollView.bounds.width > 0, !isSegmentTapping else { return }
        let offsetX = scrollView.contentOffset.x
        let pageWidth = scrollView.bounds.width
        let pageIndex = Int(round(offsetX / pageWidth))
        if topSegmentView.selectedSegmentIndex != pageIndex {
            topSegmentView.selectedSegmentIndex = pageIndex
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == scrollContainerView else { return }
        isSegmentTapping = false
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == scrollContainerView else { return }
        isSegmentTapping = false
    }
}

// MARK: - UITableViewDataSource
extension ParticipantListView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == participantTableView {
            return participantList.count
        }
        
        if tableView == audienceTableView {
            return audienceList.count
        }
        return 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == participantTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ParticipantListCell.cellReuseIdentifier, for: indexPath) as? ParticipantListCell else {
                return UITableViewCell()
            }
            
            let participant = participantList[indexPath.row]
            cell.configure(with: participant, roomID: roomID, roomType: roomType)
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
extension ParticipantListView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var participant: RoomParticipant?
        var isAudience: Bool = false
        if tableView == participantTableView {
            participant = participantList[indexPath.row]
        }
        
        if tableView == audienceTableView {
            participant = audienceList[indexPath.row]
            isAudience = true
        }
       
        guard let participant = participant else { return }
        
        guard canInteractWith(participant: participant) else {
            return
        }
        participantTapped(for: participant, isAudience: isAudience)
    }
    
    private func canInteractWith(participant: RoomParticipant) -> Bool {
        guard let localParticipant = participantStore.state.value.localParticipant else {
            return false
        }
        
        if localParticipant.role.rawValue < participant.role.rawValue {
            return true
        }
        return false
    }
    
    private func participantTapped(for participant: RoomParticipant, isAudience: Bool) {
        delegate?.participantTapped(view: self, participant: participant, isAudience: isAudience)
    }
}

// MARK: - BaseParticipantCell
private class BaseParticipantCell: UITableViewCell {
    // MARK: - Properties
    var roomID: String = ""
    
    lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    // MARK: - UI Components
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 24
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g7
        return label
    }()
    
    lazy var roleIcon: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    lazy var roleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        return label
    }()
    
    lazy var dividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        return view
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(roleIcon)
        containerView.addSubview(roleLabel)
        contentView.addSubview(dividerLine)
    }
    
    func setupConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.right.equalToSuperview()
        }
        
        roleIcon.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.size.equalTo(CGSize(width: 14, height: 14))
            make.centerY.equalTo(roleLabel.snp.centerY)
        }
        
        roleLabel.snp.makeConstraints { make in
            make.left.equalTo(roleIcon.snp.right).offset(2)
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview()
            make.right.equalToSuperview()
        }
    }
    
    func setupStyles() {
        contentView.backgroundColor = RoomColors.g2
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    // MARK: - Common Methods
    func configureBasicInfo(participant: RoomParticipant, roomID: String) {
        self.roomID = roomID
        
        avatarImageView.kf.setImage(
            with: URL(string: participant.avatarURL),
            placeholder: ResourceLoader.loadImage("avatar_placeholder")
        )
        
        let currentUserID = participantStore.state.value.localParticipant?.userID ?? ""
        nameLabel.text = participant.userID == currentUserID
            ? "\(participant.name)(\(String.me))"
            : participant.name
        
        updateRoleLabel(role: participant.role)
    }
    
    func updateRoleLabel(role: ParticipantRole) {
        switch role {
        case .owner:
            roleLabel.text = .owner
            roleLabel.textColor = RoomColors.b1d
            roleIcon.image = ResourceLoader.loadImage("room_owner_tag")
            roleLabel.isHidden = false
            roleIcon.isHidden = false
        case .admin:
            roleLabel.text = .administrator
            roleLabel.textColor = RoomColors.adminTagColor
            roleIcon.image = ResourceLoader.loadImage("room_admin_tag")
            roleLabel.isHidden = false
            roleIcon.isHidden = false
        default:
            roleLabel.isHidden = true
            roleIcon.isHidden = true
        }
        
        if role == .generalUser {
            nameLabel.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            nameLabel.snp.remakeConstraints { make in
                make.left.top.right.equalToSuperview()
            }
            
            roleIcon.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.size.equalTo(CGSize(width: 14, height: 14))
                make.centerY.equalTo(roleLabel.snp.centerY)
            }
            
            roleLabel.snp.remakeConstraints { make in
                make.left.equalTo(roleIcon.snp.right).offset(2)
                make.top.equalTo(nameLabel.snp.bottom).offset(2)
                make.bottom.right.equalToSuperview()
            }
        }
    }
}

// MARK: - ParticipantListCell
private class ParticipantListCell: BaseParticipantCell {
    // MARK: - Additional UI Components
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = RoomSpacing.large
        stackView.alignment = .trailing
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    private lazy var recordImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_recording_tag")
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var screenShareImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_screen_share_tag")
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var microphoneImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    private lazy var cameraImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    // MARK: - Setup Methods
    override func setupViews() {
        super.setupViews()
        contentView.addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(recordImageView)
        buttonStackView.addArrangedSubview(screenShareImageView)
        buttonStackView.addArrangedSubview(microphoneImageView)
        buttonStackView.addArrangedSubview(cameraImageView)
    }
    
    override func setupConstraints() {
        super.setupConstraints()
        
        containerView.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.right.lessThanOrEqualTo(buttonStackView.snp.left).offset(-5)
        }
        
        buttonStackView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }
        
        [recordImageView, screenShareImageView, microphoneImageView, cameraImageView].forEach { imageView in
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(20)
            }
        }
        
        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(buttonStackView.snp.right)
            make.height.equalTo(1)
        }
    }
    
    // MARK: - Public Methods
    func configure(with participant: RoomParticipant, roomID: String, roomType: RoomType) {
        configureBasicInfo(participant: participant, roomID: roomID)
        
        if roomType == .standard {
            screenShareImageView.isHidden = participant.screenShareStatus == .off
            cameraImageView.image = ResourceLoader.loadImage(participant.cameraStatus == .on ? "room_member_camera_on" : "room_member_camera_off")
            microphoneImageView.image = ResourceLoader.loadImage(participant.microphoneStatus == .on ? "room_member_unmute" : "room_member_mute")
        } else {
            screenShareImageView.isHidden = true
            cameraImageView.isHidden = true
            microphoneImageView.image = ResourceLoader.loadImage(participant.microphoneStatus == .on ? "room_member_unmute" : "room_member_mute")
        }
    }
}

// MARK: - AudienceListCell
private class AudienceListCell: BaseParticipantCell {
    // MARK: - Setup Methods
    override func setupConstraints() {
        super.setupConstraints()
        
        containerView.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.right.equalToSuperview().offset(-RoomSpacing.large)
        }
        
        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(containerView.snp.right)
            make.height.equalTo(1)
        }
    }
    
    // MARK: - Public Methods
    func configure(with audience: RoomParticipant, roomID: String) {
        configureBasicInfo(participant: audience, roomID: roomID)
    }
}

fileprivate extension String {
    static let muteAll = "roomkit_mute_all_audio".localized
    static let unmuteAll = "roomkit_unmute_all_audio".localized
    static let stopAllVideo = "roomkit_disable_all_video".localized
    static let enableAllVideo = "roomkit_enable_all_video".localized
    static let more = "roomkit_more".localized
    static let members = "roomkit_member_count"
    static let me = "roomkit_me".localized
    static let owner = "roomkit_role_owner".localized
    static let administrator = "roomkit_role_admin".localized
    static let participant = "roomkit_participant".localized
    static let audience = "roomkit_audience".localized
}
