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
    func participantTapped(view: ParticipantListView, participant: RoomParticipant)
}

// MARK: - ParticipantListView
public class ParticipantListView: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    public var backgroundMaskView: PanelMaskView?
    
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
    private var allParticipants: [RoomParticipant] = []
    private var cancellableSet = Set<AnyCancellable>()
    private let roomID: String
    
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
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.register(ParticipantListCell.self, forCellReuseIdentifier: ParticipantListCell.reuseIdentifier)
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
    
    // MARK: - BaseView Implementation
    func setupViews() {
        addSubview(containerView)
        
        containerView.addSubview(dropButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(tableView)
        containerView.addSubview(bottomBarView)
        
        bottomBarView.addSubview(muteAllAudioButton)
        bottomBarView.addSubview(muteAllVideoButton)
    }
    
    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
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
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(RoomSpacing.medium)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(bottomBarView.snp.top)
        }
    }
    
    func setupStyles() {
        backgroundColor = .clear
    }
    
    func setupBindings() {
    
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        muteAllAudioButton.addTarget(self, action: #selector(muteAllAudioButtonTapped), for: .touchUpInside)
        muteAllVideoButton.addTarget(self, action: #selector(muteAllVideoButtonTapped), for: .touchUpInside)
        
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participants in
                guard let self = self else { return }
                updateParticipants(participants)
            }
            .store(in: &cancellableSet)
        
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] participant in
                guard let self = self else { return }
                if let participant = participant, (participant.role == .admin || participant.role == .owner) {
                    bottomBarView.isHidden = false
                } else {
                    bottomBarView.isHidden = true
                }
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
}

// MARK: - Private Methods
extension ParticipantListView {
    private func updateParticipants(_ participants: [RoomParticipant]) {
        allParticipants = participants
        updateTitle()
        tableView.reloadData()
    }
    
    private func updateTitle() {
        titleLabel.text = .members.localizedReplace("\(allParticipants.count)")
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
}

// MARK: - UITableViewDataSource
extension ParticipantListView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allParticipants .count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ParticipantListCell.reuseIdentifier, for: indexPath) as? ParticipantListCell else {
            return UITableViewCell()
        }
        
        let participant = allParticipants[indexPath.row]
        cell.configure(with: participant, roomID: roomID)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ParticipantListView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let participant = allParticipants[indexPath.row]
        guard canInteractWith(participant: participant) else {
            return
        }
        participantTapped(for: participant)
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
    
    private func participantTapped(for participant: RoomParticipant) {
        delegate?.participantTapped(view: self, participant: participant)
    }
}

// MARK: - ParticipantListCell
private class ParticipantListCell: UITableViewCell {
    // MARK: - Properties
    static let reuseIdentifier = "ParticipantListCell"
    private var roomID: String = ""
    
    private var participant: RoomParticipant?
    
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    // MARK: - UI Components
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 24
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g7
        return label
    }()
    
    private lazy var roleIcon: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    private lazy var roleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        return label
    }()
    
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
    
    private lazy var dividerLine: UIView = {
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
    private func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(roleIcon)
        containerView.addSubview(roleLabel)
        
        contentView.addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(recordImageView)
        buttonStackView.addArrangedSubview(screenShareImageView)
        buttonStackView.addArrangedSubview(microphoneImageView)
        buttonStackView.addArrangedSubview(cameraImageView)
        contentView.addSubview(dividerLine)
    }
    
    private func setupConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        containerView.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.right.lessThanOrEqualTo(buttonStackView.snp.left).offset(-5)
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
        
        buttonStackView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }
        
        recordImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        screenShareImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        microphoneImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        cameraImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(buttonStackView.snp.right)
            make.height.equalTo(1)
        }
    }
    
    private func setupStyles() {
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    // MARK: - Public Methods
    func configure(with participant: RoomParticipant, roomID: String) {
        self.participant = participant
        self.roomID = roomID
        
        avatarImageView.kf.setImage(
            with: URL(string: participant.avatarURL),
            placeholder: ResourceLoader.loadImage("avatar_placeholder")
        )
        
        let currentUserID = participantStore.state.value.localParticipant?.userID ?? ""
        if participant.userID == currentUserID {
            let meText = String.me
            nameLabel.text = "\(participant.name)(\(meText))"
        } else {
            nameLabel.text = participant.name
        }
        
        updateRoleLabel(role: participant.role)
        
        updateScreenShareButton(status: participant.screenShareStatus)
        updateAudioButton(status: participant.microphoneStatus)
        updateVideoButton(status: participant.cameraStatus)
    }
    
    // MARK: - Private Methods
    private func updateRoleLabel(role: ParticipantRole) {
        switch role {
        case .owner:
            roleLabel.text = .owner
            roleLabel.textColor = RoomColors.b1d
            roleLabel.isHidden = false
            
            roleIcon.image = ResourceLoader.loadImage("room_owner_tag")
            roleIcon.isHidden = false
        case .admin:
            roleLabel.text = .administrator
            roleLabel.textColor = RoomColors.adminTagColor
            roleLabel.isHidden = false
            
            roleIcon.image = ResourceLoader.loadImage("room_admin_tag")
            roleIcon.isHidden = false
        default:
            roleLabel.isHidden = true
            roleIcon.isHidden = true
        }
        
        if role == .generalUser {
            nameLabel.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.top.equalToSuperview()
                make.bottom.equalToSuperview()
                make.right.equalToSuperview()
            }
        } else {
            nameLabel.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.top.equalToSuperview()
                make.right.equalToSuperview()
            }
            
            roleIcon.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.size.equalTo(CGSize(width: 14, height: 14))
                make.centerY.equalTo(roleLabel.snp.centerY)
            }
            
            roleLabel.snp.remakeConstraints { make in
                make.left.equalTo(roleIcon.snp.right).offset(2)
                make.top.equalTo(nameLabel.snp.bottom).offset(2)
                make.bottom.equalToSuperview()
                make.right.equalToSuperview()
            }
        }
    }
    
    private func updateScreenShareButton(status: DeviceStatus) {
        screenShareImageView.isHidden = status == .off
    }
        
    private func updateAudioButton(status: DeviceStatus) {
        let imageName = status == .on ? "room_member_unmute" : "room_member_mute"
        microphoneImageView.image = ResourceLoader.loadImage(imageName)
    }
    
    private func updateVideoButton(status: DeviceStatus) {
        let imageName = status == .on ? "room_member_camera_on" : "room_member_camera_off"
        cameraImageView.image = ResourceLoader.loadImage(imageName)
    }
}

fileprivate extension String {
    static let muteAll = "Mute all".localized
    static let unmuteAll = "Unmute all".localized
    static let stopAllVideo = "Stop all video".localized
    static let enableAllVideo = "Enable all video".localized
    static let more = "More".localized
    static let members = "Members(xxx)"
    static let me = "Me".localized
    static let owner = "Owner".localized
    static let administrator = "Administrator".localized
}
