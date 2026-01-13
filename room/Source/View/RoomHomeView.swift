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
import Combine
import Kingfisher

public class RoomHomeView: UIView, BaseView {
    
    // MARK: - Properties
    weak var routerContext: RouterContext?
    private let roomStore: RoomStore = RoomStore.shared
    private var cancellableSet = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackButtonTapped))
        view.addGestureRecognizer(tapGesture)
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
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleUserAvatarTapped))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var userAvatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = RoomCornerRadius.circle(size: 40)
        imageView.backgroundColor = RoomColors.g3
        return imageView
    }()
    
    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var joinRoomButton: UIButton = {
        let button = createActionButton(
            title: .joinRoom,
            iconName: "join_room"
        )
        button.addTarget(self, action: #selector(handleJoinRoomButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var createRoomButton: UIButton = {
        let button = createActionButton(
            title: .createRoom,
            iconName: "create_room"
        )
        button.addTarget(self, action: #selector(handleCreateRoomButtonTapped), for: .touchUpInside)
        return button
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

    func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(userAvatarContainerView)
        userAvatarContainerView.addSubview(userAvatarImageView)
        userAvatarContainerView.addSubview(userNameLabel)
        addSubview(joinRoomButton)
        addSubview(createRoomButton)
    }
    
    func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.right.equalTo(-56)
            make.height.equalTo(62)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(22)
            make.width.height.equalTo(16)
        }
        
        userAvatarContainerView.snp.makeConstraints { make in
            make.left.equalTo(backButton.snp.right).offset(22)
            make.right.equalToSuperview()
            make.centerY.equalTo(backButton)
            make.height.equalTo(40)
        }
        
        userAvatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        userNameLabel.snp.makeConstraints { make in
            make.left.equalTo(userAvatarImageView.snp.right).offset(RoomSpacing.medium)
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        joinRoomButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(56)
            make.right.equalToSuperview().offset(-56)
            make.height.equalTo(54)
            make.bottom.equalTo(createRoomButton.snp.top).offset(-RoomSpacing.extraLarge)
        }
        
        createRoomButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(56)
            make.right.equalToSuperview().offset(-56)
            make.height.equalTo(54)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-120)
        }
    }
    
    func setupStyles() {
        backgroundColor = RoomColors.themeBackground
    }
    
    // MARK: - Helper Methods
    
    private func createActionButton(title: String, iconName: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = RoomCornerRadius.medium
        button.clipsToBounds = true
        button.backgroundColor = RoomColors.brandBlue
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = RoomSpacing.small
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        
        let iconImageView = UIImageView()
        iconImageView.image = ResourceLoader.loadImage(iconName)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .semibold)
        titleLabel.textColor = .white
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        
        button.addSubview(stackView)
        
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
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

extension RoomHomeView {
    // MARK: - Actions
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
    
    @objc private func handleUserAvatarTapped() {
        // TODO: 点击用户头像事件响应
    }
}

fileprivate extension String {
    static let joinRoom = "Join room".localized
    static let createRoom = "Create room".localized
}
