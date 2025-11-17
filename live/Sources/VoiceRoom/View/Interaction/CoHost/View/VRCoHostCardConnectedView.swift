//
//  VRCoHostCardConnectedView.swift
//  Pods
//
//  Created by ssc on 2025/10/14.
//

import Foundation
import RTCCommon
import Combine
import TUICore
import MJRefresh
import AtomicXCore
import RTCRoomEngine
import SnapKit

class VRCoHostCardConnectedView: UIView {
    private var isInvite: Bool = false
    private var liveID: String
    private var battleID = ""
    private let topCard = VRCoHostCardView()
    private let bottomCard = VRCoHostCardView()
    private var cancellableSet: Set<AnyCancellable> = []
    private let toastService: VRToastService
    private let pkButton: UIButton = {
        let btn = UIButton()
        btn.layer.cornerRadius = 20.scale375()
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitle(.requestBattleText, for: .normal)
        btn.backgroundColor = .b1
        return btn
    }()

    private lazy var selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .g3.withAlphaComponent(0.3)
        return view
    }()

    private lazy var secondSelectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .g3.withAlphaComponent(0.3)
        view.isHidden = true
        return view
    }()

    init(liveID: String,toastService: VRToastService) {
        self.liveID = liveID
        self.toastService = toastService
        super.init(frame: .zero)
        backgroundColor = .bgOperateColor
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        subscribeBattleState()
        setPKButtonIsEnable(isEnable: !isInvite)
        isViewReady = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private func constructViewHierarchy() {
        addSubview(topCard)
        addSubview(bottomCard)
        addSubview(pkButton)
        addSubview(selectionIndicator)
        addSubview(secondSelectionIndicator)
    }

    private func activateConstraints() {
        topCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2.scale375())
            make.leading.equalToSuperview()
            make.height.equalTo(60.scale375Height())
        }

        bottomCard.snp.makeConstraints { make in
            make.top.equalTo(topCard.snp.bottom).offset(4.scale375())
            make.leading.trailing.equalTo(topCard)
            make.height.equalTo(topCard)
        }

        pkButton.snp.makeConstraints { make in
            make.top.equalTo(bottomCard.snp.bottom).offset(12.scale375())
            make.centerX.equalToSuperview()
            make.width.equalTo(200.scale375())
            make.height.equalTo(40.scale375Height())
            make.bottom.lessThanOrEqualToSuperview().offset(-20.scale375())
        }

        selectionIndicator.snp.makeConstraints { make in
            make.bottom.equalTo(topCard.snp.bottom)
            make.height.equalTo(1.scale375())
            make.left.equalTo(topCard.snp.left).offset(76.scale375())
            make.right.equalToSuperview().offset(-16.scale375())
        }

        secondSelectionIndicator.snp.makeConstraints { make in
            make.bottom.equalTo(bottomCard.snp.bottom)
            make.height.equalTo(1.scale375())
            make.left.equalTo(bottomCard.snp.left).offset(76.scale375())
            make.right.equalToSuperview().offset(-16.scale375())
        }
    }

    private func bindInteraction() {
        pkButton.addTarget(self, action: #selector(requestBattle), for: .touchUpInside)
    }

    private func subscribeBattleState() {
        battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                let selfId = TUIRoomEngine.getSelfInfo().userId
                switch event {
                    case .onBattleRequestReject(battleID: _, let inviter, _):
                        if inviter.userID == selfId {
                            setPKButtonIsEnable(isEnable: true)
                        }
                    case .onBattleRequestTimeout(_, let inviter, _):
                        if inviter.userID == selfId {
                            setPKButtonIsEnable(isEnable: true)
                        }
                    case .onBattleRequestCancelled(_, _, let invitee):
                        if invitee.userID == selfId {
                            setPKButtonIsEnable(isEnable: true)
                        }
                    case .onBattleEnded(_, _):
                        setPKButtonIsEnable(isEnable: true)
                    default:
                        break
                }
            }
            .store(in: &cancellableSet)
    }

    @objc private func requestBattle() {
        let selfLiveID = liveListStore.state.value.currentLive.liveID
        let config = BattleConfig(duration: 30, needResponse: true, extensionInfo: "")
        let requestUserIds = coHostState.connected.filter { $0.liveID != selfLiveID}.map(\.userID)
        battleStore.requestBattle(config: config, userIDList: requestUserIds, timeout: 10) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let (battleInfo,_)):
                    self.battleID = battleInfo.battleID
                    setPKButtonIsEnable(isEnable: false)
                case .failure(_):
                    break
            }
        }

        pkButton.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pkButton.isUserInteractionEnabled = true
        }
    }

    @objc private func cancelBattleRequest() {
        let selfUserId = TUIRoomEngine.getSelfInfo().userId
        let userIdList = coHostState.connected.map { $0.userID }.filter({ $0 != selfUserId })
        battleStore.cancelBattleRequest(battleId: battleID, userIdList: userIdList, completion: {[weak self] result in
            guard let self else { return }
            switch result {
                case .success():
                    setPKButtonIsEnable(isEnable: true)
                case .failure(_):
                    break
            }
        })
    }

    private func setPKButtonIsEnable(isEnable: Bool) {
        if isEnable {
            pkButton.removeTarget(self, action: #selector(cancelBattleRequest), for: .touchUpInside)
            pkButton.addTarget(self, action: #selector(requestBattle), for: .touchUpInside)
            isInvite = false
        } else {
            pkButton.removeTarget(self, action: #selector(requestBattle), for: .touchUpInside)
            pkButton.addTarget(self, action: #selector(cancelBattleRequest), for: .touchUpInside)
            isInvite = true
        }
        pkButton.setTitle(isEnable ? .requestBattleText : .invitingCancelText, for: .normal)
        pkButton.backgroundColor = isEnable ? .b1 : .clear
        pkButton.layer.borderColor = UIColor.g3.withAlphaComponent(0.3).cgColor
        pkButton.layer.borderWidth = isEnable ? 0 : 1
    }

    func render(connectedList: [SeatUserInfo],isBattle: Bool) {
        guard connectedList.count >= 2 else { return }
        topCard.render(user: connectedList[0], isBattle: isBattle)
        bottomCard.render(user: connectedList[1], isBattle: isBattle)

    }

    func switchMode(isBattled: Bool) {
        pkButton.isHidden = isBattled
        if isBattled {
            pkButton.snp.remakeConstraints { make in
                make.top.equalTo(bottomCard.snp.bottom).offset(12.scale375())
                make.centerX.equalToSuperview()
                make.width.equalTo(200.scale375())
                make.height.equalTo(0.scale375Height())
                make.bottom.lessThanOrEqualToSuperview().offset(-20.scale375())
            }
            secondSelectionIndicator.isHidden = false
        } else {
            setPKButtonIsEnable(isEnable: !isInvite)
            pkButton.snp.remakeConstraints { make in
                make.top.equalTo(bottomCard.snp.bottom).offset(12.scale375())
                make.centerX.equalToSuperview()
                make.width.equalTo(200.scale375())
                make.height.equalTo(40.scale375Height())
                make.bottom.lessThanOrEqualToSuperview().offset(-20.scale375())
            }
            secondSelectionIndicator.isHidden = true
        }
    }
}

extension VRCoHostCardConnectedView {
    var liveListStore: LiveListStore {
        return LiveListStore.shared
    }

    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: liveID)
    }

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }

    var coHostState: CoHostState {
        return coHostStore.state.value
    }

    var battleStore: BattleStore {
        return BattleStore.create(liveID: liveID)
    }
}

class VRCoHostCardView: UIView {
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.customFont(ofSize: 16)
        label.textColor = .grayColor
        return label
    }()

    private let battleLable: UILabel = {
        let label = UILabel()
        label.font = UIFont.customFont(ofSize: 12, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.5)
        label.text = .inBattleText
        label.isHidden = true
        return label
    }()

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }

    func constructViewHierarchy() {
        addSubview(avatarImageView)
        addSubview(userNameLabel)
        addSubview(battleLable)
    }

    func activateConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24.scale375())
            make.width.height.equalTo(40.scale375())
        }

        userNameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12.scale375())
            make.width.lessThanOrEqualTo(120.scale375())
        }

        battleLable.snp.makeConstraints { make in
            make.right.equalTo(avatarImageView.snp.right).offset(296.scale375())
            make.centerY.equalToSuperview()
        }
    }

    func render(user: SeatUserInfo,isBattle: Bool) {
        avatarImageView.roundedRect(.allCorners, withCornerRatio: 20.scale375())
        avatarImageView.kf.setImage(with: URL(string: user.avatarURL),
                                    placeholder: UIImage.avatarPlaceholderImage)
        userNameLabel.text = user.userName.isEmpty ? user.userID : user.userName

        battleLable.isHidden = !isBattle
    }
}


fileprivate extension String {
    static let inBattleText = internalLocalized("In Battle")
    static let invitingCancelText = internalLocalized("Cancel invite")
    static let requestBattleText = internalLocalized("Request Battle")
}

