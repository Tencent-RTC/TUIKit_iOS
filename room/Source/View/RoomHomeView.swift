//
//  RoomHomeView.swift
//  TUIRoomKit
//
//  Created on 2025/11/12.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import AtomicX
import Combine
import Kingfisher

public class RoomHomeView: UIView, BaseView {
    
    // MARK: - Properties
    public weak var routerContext: RouterContext?
    private var cancellableSet = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var userAvatarContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var userAvatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = RoomCornerRadius.circle(size: 30)
        imageView.backgroundColor = RoomColors.g3
        return imageView
    }()
    
    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var functionCardsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = RoomSpacing.large
        return stackView
    }()
    
    private lazy var joinRoomButton: UIButton = {
        let button = createActionButton(
            title: .joinRoom,
            iconName: "join_room",
            iconPosition: .top,
            spacing: 10,
            iconSize: CGSize(width: 24, height: 24)
        )
        return button
    }()
    
    private lazy var createRoomButton: UIButton = {
        let button = createActionButton(
            title: .createRoom,
            iconName: "create_room",
            iconPosition: .top,
            spacing: 10,
            iconSize: CGSize(width: 24, height: 24)
        )
        return button
    }()
    
    private lazy var scheduleRoomButton: UIButton = {
        let button = createActionButton(
            title: .scheduleRoom,
            iconName: "room_schedule",
            iconPosition: .top,
            spacing: 10,
            iconSize: CGSize(width: 24, height: 24)
        )
        return button
    }()
 
    private lazy var historyRoomSeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g7
        return view
    }()
    
    private lazy var scheduleListView: RoomScheduleListView = {
        let view = RoomScheduleListView()
        view.onScheduleRowTapped = { [weak self] item in
            self?.showScheduleDetail(for: item)
        }
        view.onEnterScheduleRoomTapped = { [weak self] item in
            self?.enterScheduledRoom(item)
        }
        return view
    }()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        setupStoreObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - BaseView Implementation

    public func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(userAvatarContainerView)
        userAvatarContainerView.addSubview(userAvatarImageView)
        userAvatarContainerView.addSubview(userNameLabel)
        
        addSubview(functionCardsStackView)
        functionCardsStackView.addArrangedSubview(joinRoomButton)
        functionCardsStackView.addArrangedSubview(createRoomButton)
        functionCardsStackView.addArrangedSubview(scheduleRoomButton)
        addSubview(historyRoomSeparatorView)
        
        addSubview(scheduleListView)
    }
    
    public func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.right.equalToSuperview()
            make.height.equalTo(62)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalTo(userAvatarContainerView)
            make.width.height.equalTo(16)
        }
        
        userAvatarContainerView.snp.makeConstraints { make in
            make.left.equalTo(backButton.snp.right).offset(RoomSpacing.standard)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
            make.centerY.equalToSuperview()
            make.height.equalTo(30)
        }
        
        userAvatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        userNameLabel.snp.makeConstraints { make in
            make.left.equalTo(userAvatarImageView.snp.right).offset(RoomSpacing.small)
            make.right.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
        
        functionCardsStackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.huge)
            make.right.equalToSuperview().offset(-RoomSpacing.huge)
            make.top.equalTo(backButtonContainerView.snp.bottom).offset(RoomSpacing.small)
            make.height.equalTo(80)
        }
        
        historyRoomSeparatorView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
            make.top.equalTo(functionCardsStackView.snp.bottom).offset(20)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        
        scheduleListView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(historyRoomSeparatorView.snp.bottom)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    public func setupStyles() {
        backgroundColor = RoomColors.themeBackground
    }
    
    public func setupBindings() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackButtonTapped))
        backButton.addGestureRecognizer(tapGesture)
        backButton.isUserInteractionEnabled = true
        
        createRoomButton.addTarget(self, action: #selector(handleCreateRoomButtonTapped), for: .touchUpInside)
        joinRoomButton.addTarget(self, action: #selector(handleJoinRoomButtonTapped), for: .touchUpInside)
        scheduleRoomButton.addTarget(self, action: #selector(handleScheduleRoomButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Helper Methods
    
    enum ActionButtonIconPosition {
        case leading
        case trailing
        case top
        case bottom
    }
    
    private func createActionButton(
        title: String,
        iconName: String,
        iconPosition: ActionButtonIconPosition = .leading,
        spacing: CGFloat = RoomSpacing.small,
        iconSize: CGSize = CGSize(width: 20, height: 20)
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = RoomCornerRadius.medium
        button.clipsToBounds = true
        button.backgroundColor = RoomColors.brandBlue
        
        let iconImageView = UIImageView()
        iconImageView.image = ResourceLoader.loadImage(iconName)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .semibold)
        titleLabel.textColor = .white
        
        let stackView = UIStackView()
        stackView.spacing = spacing
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        
        switch iconPosition {
        case .leading:
            stackView.axis = .horizontal
            stackView.addArrangedSubview(iconImageView)
            stackView.addArrangedSubview(titleLabel)
        case .trailing:
            stackView.axis = .horizontal
            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(iconImageView)
        case .top:
            stackView.axis = .vertical
            stackView.addArrangedSubview(iconImageView)
            stackView.addArrangedSubview(titleLabel)
        case .bottom:
            stackView.axis = .vertical
            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(iconImageView)
        }
        
        button.addSubview(stackView)
        
        iconImageView.snp.makeConstraints { make in
            make.width.equalTo(iconSize.width)
            make.height.equalTo(iconSize.height)
        }
        
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        return button
    }
    
    // MARK: - Store Observers
    
    private func setupStoreObservers() {
        LoginStore.shared.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
            .receive(on: RunLoop.main)
            .sink { [weak self] loginUser in
                guard let self = self, let loginUser = loginUser else { return }
                updateUserInfo(name: loginUser.nickname ?? loginUser.userID, avatarURL: loginUser.avatarURL)
            }
            .store(in: &cancellableSet)
            
        RoomStore.shared.roomEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onRemovedFromScheduledRoom(_, _):
                    self.showAtomicToast(text: .removedFromScheduledRoom, style: .info, position: .center)
                case .onScheduledRoomCancelled(_, _):
                    self.showAtomicToast(text: .scheduledRoomCancelled, style: .info, position: .center)
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
    
    // MARK: - Private Methods
    
    private func updateUserInfo(name: String, avatarURL: String?) {
        userNameLabel.text = name
        if let avatarURL = avatarURL {
            userAvatarImageView.kf.setImage(with: URL(string: avatarURL),
                                            placeholder: ResourceLoader.loadImage("avatar_placeholder"))
        } else {
            userAvatarImageView.image = ResourceLoader.loadImage("avatar_placeholder")
        }
    }
}

// MARK: - Actions

extension RoomHomeView {
    @objc private func handleBackButtonTapped() {
        routerContext?.pop(animated: true)
    }
    
    @objc private func handleJoinRoomButtonTapped() {
        let joinViewController = RoomJoinViewController()
        routerContext?.push(joinViewController, animated: true)

    }
    
    @objc private func handleCreateRoomButtonTapped() {
        let createViewController = RoomCreateViewController()
        routerContext?.push(createViewController, animated: true)
    }
    
    @objc private func handleScheduleRoomButtonTapped() {
        let scheduleViewController = RoomScheduleViewController()
        scheduleViewController.onScheduled = { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.showScheduleInfoPanel(for: info)
            }
        }
        routerContext?.push(scheduleViewController, animated: true)
    }
    
    private func showScheduleInfoPanel(for roomInfo: RoomScheduleInfo) {
        let panel = RoomScheduleInfoPanel(roomInfo: roomInfo)
        panel.show(in: self, animated: true)
    }
    
    private func showScheduleDetail(for roomInfo: RoomInfo) {
        let detailViewController = RoomScheduleDetailViewController(roomInfo: roomInfo)
        routerContext?.push(detailViewController, animated: true)
    }

    private func enterScheduledRoom(_ roomInfo: RoomInfo) {
        // Entering via a scheduled room keeps the camera off by default;
        // the user can turn it on from the in-room bottom bar.
        let config = ConnectConfig(autoEnableCamera: false)
        let mainViewController = RoomMainViewController(roomID: roomInfo.roomID,
                                                        behavior: .join,
                                                        config: config)
        routerContext?.push(mainViewController, animated: true)
    }
}

fileprivate extension String {
    static let joinRoom = "roomkit_join_room".localized
    static let createRoom = "roomkit_create_room".localized
    static let scheduleRoom = "roomkit_schedule_room".localized
    static let removedFromScheduledRoom = "roomkit_scheduled_room_removed_toast".localized
    static let scheduledRoomCancelled = "roomkit_scheduled_room_cancelled_toast".localized
}
