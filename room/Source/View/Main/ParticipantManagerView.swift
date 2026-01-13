//
//  ParticipantManagerView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/25.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Kingfisher
import Combine

// MARK: - Action Item
struct ParticipantActionItem {
    let icon: UIImage?
    let title: String
    let textColor: UIColor
    let action: () -> Void
    
    init(icon: UIImage?, title: String, textColor: UIColor = RoomColors.g7, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.textColor = textColor
        self.action = action
    }
}

public protocol ParticipantManagerViewDelegate: AnyObject {
    func handleTransferHost(view: ParticipantManagerView, participant: RoomParticipant)
    func handleSetAsAdmin(view: ParticipantManagerView, participant: RoomParticipant)
    func handleKickOut(view: ParticipantManagerView, participant: RoomParticipant)
    func handleInviteToOpenDevice(view: ParticipantManagerView, device: DeviceType, participant: RoomParticipant)
}

// MARK: - ParticipantManagerView
public class ParticipantManagerView: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    public var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    public var panelHeight: CGFloat {
        let headerHeight: CGFloat = 100
        let itemHeight: CGFloat = 56
        let totalItemsHeight = CGFloat(actionItems.count) * itemHeight
        let bottomSafeArea = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        return headerHeight + totalItemsHeight + bottomSafeArea + 20
    }
    
    public weak var delegate: ParticipantManagerViewDelegate?
    
    // MARK: - Properties
    private var participant: RoomParticipant
    private let roomID: String
    private var actionItems: [ParticipantActionItem] = []
    private var cancellableSet = Set<AnyCancellable>()
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = RoomCornerRadius.extraLarge
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var dropButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_drop_arrow"), for: .normal)
        button.imageView?.contentMode = .center
        return button
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
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
        tableView.isScrollEnabled = false
        tableView.register(ParticipantManagerCell.self, forCellReuseIdentifier: ParticipantManagerCell.reuseIdentifier)
        return tableView
    }()
    
    // MARK: - Initialization
    public init(participant: RoomParticipant, roomID: String) {
        self.participant = participant
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        setupActionItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(dropButton)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(tableView)
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.width.height.equalTo(40)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(RoomSpacing.small)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    private func setupStyles() {
        backgroundColor = .clear
        avatarImageView.kf.setImage(with: URL(string: participant.avatarURL), placeholder: ResourceLoader.loadImage("avatar_placeholder"))
        nameLabel.text = participant.name
    }
    
    private func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participants in
                guard let self = self else { return }
                let oldParticipant = participant
                if let newParticipant = participants.first(where: { $0.userID == oldParticipant.userID }) {
                    participant = newParticipant
                    nameLabel.text = newParticipant.name
                    setupActionItems()
                } else {
                    dismiss()
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func setupActionItems() {
        actionItems.removeAll()
        setupRemoteActionItems()
        tableView.reloadData()
    }
    
    private func setupRemoteActionItems() {
        if participantStore.state.value.localParticipant?.role == .admin {
            actionItems.append(contentsOf: [
                ParticipantActionItem(
                    icon: participant.microphoneStatus == .off ?   ResourceLoader.loadImage("room_mic_off_red") :
                        ResourceLoader.loadImage("room_mic_on_big"),
                    title: participant.microphoneStatus == .off ?
                        .askToUnmute :
                        .mute,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleAudioDevice(disable: participant.microphoneStatus == .on)
                    },
                ParticipantActionItem(
                    icon: participant.cameraStatus == .off ?   ResourceLoader.loadImage("camera_close") :
                        ResourceLoader.loadImage("camera_open"),
                    title: participant.cameraStatus == .off ?
                        .askToStartVideo :
                        .stopVideo,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleVideoDevice(disable: participant.cameraStatus == .on)
                    },
                ParticipantActionItem(
                    icon: ResourceLoader.loadImage("room_kickout"),
                    title: .remove,
                    textColor: RoomColors.endTitleColor) { [weak self] in
                        guard let self = self else { return }
                        handleKickOut()
                    }
            ])
        } else if participantStore.state.value.localParticipant?.role == .owner {
            actionItems.append(contentsOf: [
                ParticipantActionItem(
                    icon: participant.microphoneStatus == .off ?   ResourceLoader.loadImage("room_mic_off_red") :
                        ResourceLoader.loadImage("room_mic_on_big"),
                    title: participant.microphoneStatus == .off ?
                        .askToUnmute :
                        .mute,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleAudioDevice(disable: participant.microphoneStatus == .on)
                    },
                ParticipantActionItem(
                    icon: participant.cameraStatus == .off ?   ResourceLoader.loadImage("camera_close") :
                        ResourceLoader.loadImage("camera_open"),
                    title: participant.cameraStatus == .off ?
                        .askToStartVideo :
                        .stopVideo,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleVideoDevice(disable: participant.cameraStatus == .on)
                    },
                ParticipantActionItem(
                    icon: ResourceLoader.loadImage("room_transfer_owner"),
                    title: .makeHost,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleTransferHost()
                    },
                ParticipantActionItem(
                    icon: participant.role == .admin ? ResourceLoader.loadImage("room_undo_administrator") :
                        ResourceLoader.loadImage("room_set_admin"),
                    title: participant.role == .admin ?
                        .undoAdministrator :
                        .setAsAdministrator,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleSetAsAdmin()
                    },
                ParticipantActionItem(
                    icon: ResourceLoader.loadImage("room_kickout"),
                    title: .remove,
                    textColor: RoomColors.endTitleColor) { [weak self] in
                        guard let self = self else { return }
                        handleKickOut()
                    }
            ])
        }
        
    }
}

// MARK: - Action Handlers
extension ParticipantManagerView {
    @objc private func dropButtonTapped() {
        dismiss()
    }
    
    private func handleAudioDevice(disable: Bool) {
        if disable {
            participantStore.closeParticipantDevice(userID: participant.userID, device: .microphone) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success: break
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
                dismiss(animated: true)
            }
        } else {
            delegate?.handleInviteToOpenDevice(view: self, device: .microphone, participant: participant)
        }
    }
    
    private func handleVideoDevice(disable: Bool) {
        if disable {
            participantStore.closeParticipantDevice(userID: participant.userID, device: .camera) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success: break
                case .failure(let err):
                    showToast(InternalError(code: err.code, message: err.message).localizedMessage)
                }
                dismiss(animated: true)
            }
        } else {
            delegate?.handleInviteToOpenDevice(view: self, device: .camera, participant: participant)
        }
    }
    
    private func handleTransferHost() {
        delegate?.handleTransferHost(view: self, participant: participant)
    }
    
    private func handleSetAsAdmin() {
        delegate?.handleSetAsAdmin(view: self, participant: participant)
    }
    
    private func handleChangeName() {
        if let parentView = parentView {
            let changeNameView = RoomChangeNicknameView(currentName: participant.name)
            changeNameView.delegate = self
            changeNameView.show(in: parentView, animated: true)
        }
    }
    
    private func handleMuteMessage(disable: Bool) {
        participantStore.disableUserMessage(userID: participant.userID, disable: disable) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success: break
            case .failure(let err):
                showToast(InternalError(code: err.code, message: err.message).localizedMessage)
            }
            dismiss(animated: true)
        }
    }
    
    private func handleKickOut() {
        delegate?.handleKickOut(view: self, participant: participant)
    }
}

// MARK: - UITableViewDataSource
extension ParticipantManagerView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actionItems.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ParticipantManagerCell.reuseIdentifier, for: indexPath) as? ParticipantManagerCell else {
            return UITableViewCell()
        }
        
        let item = actionItems[indexPath.row]
        cell.configure(with: item)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ParticipantManagerView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = actionItems[indexPath.row]
        item.action()
    }
}

// MARK: - RoomChangeNicknameViewDelegate
extension ParticipantManagerView: RoomChangeNicknameViewDelegate {
    public func changeNickname(view: RoomChangeNicknameView, didConfirmName name: String) {
        participantStore.updateParticipantNameCard(userID: participant.userID, nameCard: name) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                nameLabel.text = name
                dismiss()
            case .failure(_):
                break
            }
        }
    }
}

private class ParticipantManagerCell: UITableViewCell {
    // MARK: - Properties
    static let reuseIdentifier = "ParticipantManagerCell"
    
    // MARK: - UI Components
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        return label
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
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dividerLine)
    }
    
    private func setupConstraints() {
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
        }
        
        dividerLine.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.left)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    private func setupStyles() {
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    // MARK: - Public Methods
    func configure(with item: ParticipantActionItem) {
        iconImageView.image = item.icon
        titleLabel.text = item.title
        titleLabel.textColor = item.textColor
    }
}

fileprivate extension String {
    static let modifyName = "Modify the name".localized
    static let askToUnmute = "Ask to unmute".localized
    static let mute = "Mute".localized
    static let askToStartVideo = "Ask to start video".localized
    static let stopVideo = "Stop video".localized
    static let unmuteMessage = "Unmute message".localized
    static let muteMessage = "Mute message".localized
    static let makeHost = "Make host".localized
    static let undoAdministrator = "Undo administrator".localized
    static let setAsAdministrator = "Set as administrator".localized
    static let remove = "Remove".localized
}
