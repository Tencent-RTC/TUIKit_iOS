//
//  CoGuestSeatListView.swift
//  TUILiveKit
//
//  Created on 2026/3/24.
//

import UIKit
import SnapKit
import Combine
import Kingfisher
import AtomicXCore
import AtomicX

class CoGuestSeatListView: UIView {

    typealias SeatTapHandler = (SeatInfo) -> Void

    private let liveID: String
    private let seatCount: Int = 4
    private var onTapSeat: SeatTapHandler?
    private var cancellableSet = Set<AnyCancellable>()

    private lazy var seatStore: LiveSeatStore = {
        LiveSeatStore.create(liveID: liveID)
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 8
        return stack
    }()

    private var seatViews: [CoGuestSeatItemView] = []

    init(liveID: String, onTapSeat: SeatTapHandler? = nil) {
        self.liveID = liveID
        self.onTapSeat = onTapSeat
        super.init(frame: .zero)
        setupViews()
        subscribeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(100.scale375Height())
        }

        for i in 0..<seatCount {
            var seatInfo = SeatInfo()
            seatInfo.index = i
            let seatView = CoGuestSeatItemView(seatInfo: seatInfo) { [weak self] info in
                self?.onTapSeat?(info)
            }
            seatViews.append(seatView)
            stackView.addArrangedSubview(seatView)
        }
    }

    private func subscribeState() {
        seatStore.state
            .subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self else { return }
                updateSeats(with: seatList)
            }
            .store(in: &cancellableSet)

        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isShow in
                guard let self = self else { return }
                stackView.isHidden = isShow
            }
            .store(in: &cancellableSet)
    }

    private func updateSeats(with seatList: [SeatInfo]) {
        for i in 0..<seatCount {
            let seatInfo = seatList.first(where: { $0.index == i }) ?? {
                var info = SeatInfo()
                info.index = i
                return info
            }()
            seatViews[i].update(seatInfo: seatInfo)
        }
    }
}

// MARK: - CoGuestSeatItemView

class CoGuestSeatItemView: UIView {

    typealias SeatTapHandler = (SeatInfo) -> Void

    private var seatInfo: SeatInfo
    private var onTap: SeatTapHandler?

    private lazy var avatarContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.layer.cornerRadius = 25.scale375()
        view.clipsToBounds = true
        return view
    }()

    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 25.scale375()
        return iv
    }()

    private lazy var placeholderImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = .white
        return iv
    }()

    private lazy var nameContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.layer.cornerRadius = 10.scale375()
        view.clipsToBounds = true
        return view
    }()

    private lazy var muteImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = internalImage("live_audio_mute_icon")
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .customFont(ofSize: 10)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    init(seatInfo: SeatInfo, onTap: SeatTapHandler? = nil) {
        self.seatInfo = seatInfo
        self.onTap = onTap
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        avatarContainerView.addGestureRecognizer(tap)
        avatarContainerView.isUserInteractionEnabled = true

        addSubview(avatarContainerView)
        avatarContainerView.addSubview(avatarImageView)
        avatarContainerView.addSubview(placeholderImageView)
        addSubview(nameContainer)
        nameContainer.addSubview(muteImageView)
        nameContainer.addSubview(nameLabel)

        avatarContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.width.height.equalTo(50.scale375())
        }

        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        placeholderImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18.scale375())
        }

        nameContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarContainerView.snp.bottom).offset(2.scale375())
            make.height.equalTo(20.scale375())
            make.width.lessThanOrEqualTo(60.scale375())
            make.bottom.lessThanOrEqualToSuperview()
        }

        muteImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8.scale375())
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12.scale375())
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(muteImageView.snp.trailing).offset(2.scale375())
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-8.scale375())
        }

        nameContainer.isHidden = true
    }

    func update(seatInfo: SeatInfo) {
        self.seatInfo = seatInfo

        let isEmpty = seatInfo.userInfo.userID.isEmpty
        avatarImageView.isHidden = isEmpty
        placeholderImageView.isHidden = !isEmpty

        if isEmpty {
            placeholderImageView.image = internalImage("add")
            nameContainer.isHidden = true
        } else {
            let url = URL(string: seatInfo.userInfo.avatarURL)
            avatarImageView.kf.setImage(with: url, placeholder: internalImage("live_seat_placeholder_avatar"))

            let isMuted = seatInfo.userInfo.microphoneStatus == .off
            muteImageView.isHidden = !isMuted
            muteImageView.snp.updateConstraints { make in
                make.width.height.equalTo(isMuted ? 12.scale375() : 0)
            }
            nameLabel.snp.updateConstraints { make in
                make.leading.equalTo(muteImageView.snp.trailing).offset(isMuted ? 2.scale375() : 0)
            }

            let name = seatInfo.userInfo.userName.isEmpty ? seatInfo.userInfo.userID : seatInfo.userInfo.userName
            nameLabel.text = name
            nameContainer.isHidden = false
        }
    }

    @objc private func handleTap() {
        onTap?(seatInfo)
    }
}
