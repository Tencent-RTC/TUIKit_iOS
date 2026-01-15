//
//  AudienceUserInfoPanelView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/2/24.
//

import Foundation
import Combine
import RTCCommon
import ImSDK_Plus
import AtomicXCore
import AtomicX

enum AudienceUserManagePanelType {
    case mediaAndSeat
    case userInfo
}

class AudienceUserInfoPanelView: RTCBaseView {
    private let manager: AudienceStore
    
    private var user: SeatInfo
    @Published private var isFollow = false
    @Published private var fansNumber = 0
    
    private var cancellableSet = Set<AnyCancellable>()
    
    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .l,
            shape: .round
        )
        return avatar
    }()
    
    private let backgroundView : UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12.scale375()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 16)
        label.text = user.userInfo.userName
        label.textColor = .g7
        label.textAlignment = .center
        return label
    }()
    
    private lazy var userIdLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        if isRTLLanguage() {
            label.text = user.userInfo.userID +  " :UserId"
        } else {
            label.text = .userIDText.replacingOccurrences(of: "xxx", with: user.userInfo.userID)
        }
        label.textColor = .greyColor
        label.textAlignment = .center
        return label
    }()
    
    private lazy var fansLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.textColor = .greyColor
        label.textAlignment = .center
        return label
    }()
    
    private lazy var followButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .large,
            content: .textOnly(text: .followText)
        )
        return button
    }()
    
    init(user: SeatInfo, manager: AudienceStore) {
        self.user = user
        self.manager = manager
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("deinit \(type(of: self))")
    }
    
    override func constructViewHierarchy() {
        addSubview(backgroundView)
        addSubview(userNameLabel)
        addSubview(userIdLabel)
        addSubview(fansLabel)
        addSubview(followButton)
        addSubview(avatarView)
    }
    
    override func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(29.scale375Height())
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(212.scale375Height())
        }
        userNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(65.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(24.scale375Height())
        }
        userIdLabel.snp.makeConstraints { make in
            make.top.equalTo(userNameLabel.snp.bottom).offset(10.scale375Height())
            make.centerX.equalToSuperview()
            make.height.equalTo(17.scale375Height())
        }
        fansLabel.snp.makeConstraints { make in
            make.top.equalTo(userIdLabel.snp.bottom).offset(10.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(17.scale375Height())
        }
        followButton.snp.makeConstraints { make in
            make.top.equalTo(fansLabel.snp.bottom).offset(24.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalTo(275.scale375())
            make.height.equalTo(40.scale375Height())
        }
    }
    
    override func bindInteraction() {
        followButton.setClickAction { [weak self] _ in
            self?.followButtonClick()
        }
        subscribeRoomInfoPanelState()
    }
    
    override func setupViewStyle() {
        avatarView.setContent(.url(user.userInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        initFansView()
        checkFollowType()
    }
    
    private func initFansView() {
        V2TIMManager.sharedInstance().getUserFollowInfo(userIDList: [user.userInfo.userID]) { [weak self] followInfoList in
            guard let self = self, let followInfo = followInfoList?.first else { return }
            fansNumber = Int(followInfo.followersCount)
        } fail: { code, message in
            debugPrint("getFansNumber failed, error:\(code), message:\(String(describing: message))")
        }
    }
    
    private func checkFollowType() {
        V2TIMManager.sharedInstance().checkFollowType(userIDList: [user.userInfo.userID]) { [weak self] checkResultList in
            guard let self = self, let result = checkResultList?.first else { return }
            if result.followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST || result.followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST {
                self.isFollow = true
            } else {
                self.isFollow = false
            }
        } fail: { code, message in
            debugPrint("checkFollowType failed, error:\(code), message:\(String(describing: message))")
        }
    }
    
    private func subscribeRoomInfoPanelState() {
        $fansNumber
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                self.fansLabel.text = .localizedReplace(.fansCountText, replace: "\(count)")
            }
            .store(in: &cancellableSet)
        
        $isFollow.receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isFollow in
                guard let self = self else { return }
                if isFollow {
                    followButton.setButtonContent(.textOnly(text: .unfollowText))
                    followButton.setVariant(.filled)
                    followButton.setColorType(.secondary)
                } else {
                    followButton.setButtonContent(.textOnly(text: .followText))
                    followButton.setVariant(.filled)
                    followButton.setColorType(.primary)
                }
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Action
extension AudienceUserInfoPanelView {
    private func followButtonClick() {
        if isFollow {
            V2TIMManager.sharedInstance().unfollowUser(userIDList: [user.userInfo.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = false
                    fansNumber -= 1
                } else {
                    manager.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))",.error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                manager.toastSubject.send(("code: \(code), message: \(String(describing: message))",.error))
            }
        } else {
            V2TIMManager.sharedInstance().followUser(userIDList: [user.userInfo.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = true
                    fansNumber += 1
                } else {
                    manager.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))",.error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                manager.toastSubject.send(("code: \(code), message: \(String(describing: message))",.error))
            }
        }
    }
}

fileprivate extension String {
    static let fansCountText = internalLocalized("xxx Fans")
    static let followText = internalLocalized("common_follow_anchor")
    static let unfollowText = internalLocalized("common_unfollow_anchor")
    static let userIDText = internalLocalized("common_user_id")
}
