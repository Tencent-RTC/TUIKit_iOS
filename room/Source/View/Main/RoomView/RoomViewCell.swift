//
//  RoomViewCell.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/12/2.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Kingfisher
import Combine

// MARK: - RoomViewVideoStreamCell
class RoomViewVideoStreamCell: UICollectionViewCell {
    // MARK: - Properties
    static let reuseIdentifier = "RoomViewVideoStreamCell"
    var participant: RoomParticipant?
    var cancellableSet = Set<AnyCancellable>()
    
    // MARK: - UI Components
    let participantView: RoomParticipantView = {
        let participantView = RoomParticipantView()
        return participantView
    }()
    
    private(set) lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private(set) lazy var participantInfoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2.withAlphaComponent(0.8)
        return view
    }()
    
    private(set) lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private(set) lazy var roleIconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        return imageView
    }()
    
    private(set) lazy var micStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 48
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var speakingIndicatorView: UIView = {
        let view = UIView()
        view.layer.borderWidth = 3
        view.layer.borderColor = RoomColors.b2d.cgColor
        view.layer.cornerRadius = RoomCornerRadius.large
        view.isHidden = true
        return view
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    func setupViews() {
        contentView.addSubview(speakingIndicatorView)
        contentView.addSubview(containerView)
        contentView.addSubview(participantInfoContainerView)
        
        containerView.addSubview(participantView)
        participantInfoContainerView.addSubview(roleIconImageView)
        participantInfoContainerView.addSubview(micStatusImageView)
        participantInfoContainerView.addSubview(nameLabel)
        containerView.addSubview(avatarImageView)
    }
    
    func setupConstraints() {
        speakingIndicatorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        
        participantView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        participantInfoContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.right.lessThanOrEqualToSuperview().offset(-4)
            make.height.equalTo(24)
        }
        
        roleIconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(24)
            make.width.equalTo(24)
        }
        
        micStatusImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(roleIconImageView.snp.right).offset(6)
            make.width.equalTo(14)
            make.height.equalTo(14)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(micStatusImageView.snp.right).offset(2)
            make.right.equalToSuperview().offset(-8)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.centerY.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 96, height: 96))
        }
    }
    
    func setupStyles() {
        backgroundColor = .clear
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        
        participantInfoContainerView.layer.cornerRadius = 12
        
        roleIconImageView.layer.cornerRadius = 12
        roleIconImageView.layer.masksToBounds = true
        containerView.backgroundColor = RoomColors.g2.withAlphaComponent(0.5)
    }
    
    func reset() {
        participant = nil
        speakingIndicatorView.isHidden = true
        cancellableSet.removeAll()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
    }
    
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        debugPrint("deinit \(self)")
    }
}

extension RoomViewVideoStreamCell {
    // MARK: - Public Methods
    public func updateUI(with participant: RoomParticipant) {
        self.participant = participant
        updateNameLabel(with: participant)
        updateRoleIcon(with: participant)
        updateMicStatus(with: participant)
        updateAvatar(with: participant)
    }
    
    public func updateSpeakingStatus(with participant: RoomParticipant, isSpeaking: Bool) {
        if self.participant?.userID == participant.userID {
            speakingIndicatorView.isHidden = !isSpeaking
        }
    }
    
    // MARK: - Private Methods
    private func updateNameLabel(with participant: RoomParticipant) {
        nameLabel.text = participant.name
    }
    
    private func updateRoleIcon(with participant: RoomParticipant) {
        let roleImageName: String?
        
        switch participant.role {
        case .admin:
            roleImageName = "room_administrator"
        case .owner:
            roleImageName = "room_homeowner"
        default:
            roleImageName = nil
        }
        
        if let imageName = roleImageName {
            roleIconImageView.isHidden = false
            roleIconImageView.image = ResourceLoader.loadImage(imageName)
            micStatusImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalTo(roleIconImageView.snp.right).offset(6)
                make.width.equalTo(14)
                make.height.equalTo(14)
            }
        } else {
            roleIconImageView.isHidden = true
            micStatusImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(6)
                make.width.equalTo(14)
                make.height.equalTo(14)
            }
        }
    }
    
    private func updateMicStatus(with participant: RoomParticipant) {
        let imageName = participant.microphoneStatus == .off ? "room_mic_off_red" : "room_mic_on_big"
        micStatusImageView.image = ResourceLoader.loadImage(imageName)
    }
    
    private func updateAvatar(with participant: RoomParticipant) {
        avatarImageView.kf.setImage(
            with: URL(string: participant.avatarURL),
            placeholder: ResourceLoader.loadImage("avatar_placeholder")
        )
        avatarImageView.isHidden = participant.cameraStatus == .on
    }
}

// MARK: - RoomViewScreenStreamCell
class RoomViewScreenStreamCell: UICollectionViewCell {
    // MARK: - Properties
    static let reuseIdentifier = "RoomViewScreenStreamCell"
    var participant: RoomParticipant?
    var cancellableSet = Set<AnyCancellable>()

    // MARK: - UI Components
    let participantView: RoomParticipantView = {
        let participantView = RoomParticipantView()
        return participantView
    }()
    
    private(set) lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private(set) lazy var participantInfoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2.withAlphaComponent(0.8)
        return view
    }()
    
    private(set) lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private(set) lazy var roleIconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        return imageView
    }()
    
    private(set) lazy var micStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    func setupViews() {
        contentView.addSubview(containerView)
        contentView.addSubview(participantInfoContainerView)
        
        containerView.addSubview(participantView)
        participantInfoContainerView.addSubview(roleIconImageView)
        participantInfoContainerView.addSubview(micStatusImageView)
        participantInfoContainerView.addSubview(nameLabel)
    }
    
    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        
        participantView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        participantInfoContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.right.lessThanOrEqualToSuperview().offset(-4)
            make.height.equalTo(24)
        }
        
        roleIconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(24)
            make.width.equalTo(24)
        }
        
        micStatusImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(roleIconImageView.snp.right).offset(6)
            make.width.equalTo(14)
            make.height.equalTo(14)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(micStatusImageView.snp.right).offset(2)
            make.right.equalToSuperview().offset(-8)
        }
    }
    
    func setupStyles() {
        backgroundColor = .clear
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        
        participantInfoContainerView.layer.cornerRadius = 12
        
        roleIconImageView.layer.cornerRadius = 12
        roleIconImageView.layer.masksToBounds = true
        containerView.backgroundColor = RoomColors.g2.withAlphaComponent(0.5)
    }
    
    func reset() {
        participant = nil
        cancellableSet.removeAll()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
    }
    
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        debugPrint("deinit \(self)")
    }
}

extension RoomViewScreenStreamCell {
    // MARK: - Public Methods
    public func updateUI(with participant: RoomParticipant) {
        self.participant = participant
        updateNameLabel(with: participant)
        updateRoleIcon(with: participant)
        updateMicStatus(with: participant)
    }
    
    // MARK: - Private Methods
    private func updateNameLabel(with participant: RoomParticipant) {
        nameLabel.text = participant.name
    }
    
    private func updateRoleIcon(with participant: RoomParticipant) {
        let roleImageName: String?
        
        switch participant.role {
        case .admin:
            roleImageName = "room_administrator"
        case .owner:
            roleImageName = "room_homeowner"
        default:
            roleImageName = nil
        }
        
        if let imageName = roleImageName {
            roleIconImageView.isHidden = false
            roleIconImageView.image = ResourceLoader.loadImage(imageName)
            micStatusImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalTo(roleIconImageView.snp.right).offset(6)
                make.width.equalTo(14)
                make.height.equalTo(14)
            }
        } else {
            roleIconImageView.isHidden = true
            micStatusImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(6)
                make.width.equalTo(14)
                make.height.equalTo(14)
            }
        }
    }
    
    private func updateMicStatus(with participant: RoomParticipant) {
        let imageName = participant.microphoneStatus == .off ? "room_mic_off_red" : "room_mic_on_big"
        micStatusImageView.image = ResourceLoader.loadImage(imageName)
    }
}
