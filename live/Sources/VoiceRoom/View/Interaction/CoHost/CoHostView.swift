//
//  CoHostView.swift
//  Pods
//
//  Created by ssc on 2025/9/23.
//

import Foundation
import RTCCommon
import Combine
import RTCRoomEngine
import AtomicXCore
import AtomicX

class CoHostView: UIView {
    var didTap: (() -> Void)?
    private let routerManager: VRRouterManager
    private var isViewReady: Bool = false
    private var seatInfo: SeatInfo
    private var cancellableSet = Set<AnyCancellable>()

    private lazy var backgroundImage: UIImageView = {
        let view = UIImageView()
        view.kf.setImage(with: URL(string: seatInfo.userInfo.avatarURL), placeholder: UIImage.avatarPlaceholderImage)
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.backgroundColor = .black.withAlphaComponent(0.72)
        view.addSubview(blurView)

        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return view
    }()

    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url(seatInfo.userInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        return avatar
    }()

    private lazy var userInfoView = UserStatusView(userInfo: seatInfo.userInfo)

    private lazy var soundWaveView = CoHostSoundWaveView()

    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: LiveListStore.shared.state.value.currentLive.liveID)
    }

    init(seatInfo: SeatInfo, routerManager: VRRouterManager) {
        self.seatInfo = seatInfo
        self.routerManager = routerManager
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        subscribeState()
        bindInteraction()
    }

    private func constructViewHierarchy() {
        self.backgroundColor = .clear
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        addSubview(backgroundImage)
        addSubview(userInfoView)
        addSubview(avatarView)
        insertSubview(soundWaveView, belowSubview: avatarView)
    }

    private func activateConstraints() {
        backgroundImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        userInfoView.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.bottom.equalToSuperview().offset(-5)
            make.leading.equalToSuperview().offset(5)
            make.width.lessThanOrEqualTo(self).multipliedBy(0.9)
        }

        avatarView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        soundWaveView.snp.makeConstraints { make in
            make.center.equalTo(avatarView)
            make.width.equalTo(avatarView).multipliedBy(1.5)
            make.height.equalTo(avatarView).multipliedBy(1.5)
        }
    }

    private func subscribeState() {
        seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.speakingUsers))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] speakingUsers in
                guard let self = self else { return }
                let userId = seatInfo.userInfo.userID
                if !userId.isEmpty {
                    if let volume = speakingUsers[userId], volume > 25 {
                        soundWaveView.startRippleAnimation()
                    } else {
                        soundWaveView.stopRippleAnimation()
                    }
                }
            }
            .store(in: &cancellableSet)
    }

    private func bindInteraction() {
        self.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        didTap?()
    }
}

fileprivate extension String {
    static let inviteText = internalLocalized("Invite")
    static let repeatRequest = internalLocalized("Signal request repetition")
    static let takeSeatApplicationTimeout = internalLocalized("Take seat application timeout")
    static let takeSeatApplicationRejected = internalLocalized("Take seat application has been rejected")
    static let unLockSeat = internalLocalized("Unlock Seat")
    static let takeSeat = internalLocalized("Take Seat")
    static let cancelText = internalLocalized("Cancel")
    static let lockSeat = internalLocalized("Lock Seat")
}
