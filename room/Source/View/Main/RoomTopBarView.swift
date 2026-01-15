//
//  RoomTopBarView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import AtomicXCore
import Combine

// MARK: - RoomTopBarView Component
public protocol RoomTopBarViewDelegate: AnyObject {
    func onEndButtonTapped()
    func onRoomInfoButtonTapped()
}

public class RoomTopBarView: UIView, BaseView {
    // MARK: - BaseView Properties
    weak var routerContext: RouterContext?
    
    // MARK: - Properties
    weak var delegate: RoomTopBarViewDelegate?
    
    private let deviceStore: DeviceStore = DeviceStore.shared
    private let roomStore: RoomStore = RoomStore.shared
   
    private var timer: Timer?
    private var elapsedSeconds: Int = 0
    private var cancellableSet = Set<AnyCancellable>()
    private var owner: RoomUser?
    
    // MARK: - UI Components
    private lazy var audioSourceButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("room_audio_source_speaker"), for: .normal)
        return button
    }()
    
    private lazy var flipCameraButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("room_flip_camera"), for: .normal)
        return button
    }()
    
    private lazy var roomInfoContainerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var roomInfoLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g7
        label.textAlignment = .center
        return label
    }()
    
    private lazy var downArrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_down_arrow")
        return imageView
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .medium)
        label.textColor = RoomColors.g7
        label.textAlignment = .center
        label.text = "00:00"
        return label
    }()
    
    private lazy var endButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("room_end"))
        button.setTitle(.end)
        button.setIconPosition(.left, spacing: 3)
        button.setTitleColor(RoomColors.endTitleColor)
        button.setTitleFont(RoomFonts.pingFangSCFont(size: 14, weight: .semibold))
        return button
    }()
    
    // MARK: - Initialization
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        startTimer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - BaseView Implementation
    func setupViews() {
        addSubview(audioSourceButton)
        addSubview(flipCameraButton)
        addSubview(roomInfoContainerView)
        roomInfoContainerView.addSubview(roomInfoLabel)
        roomInfoContainerView.addSubview(downArrowImageView)
        addSubview(timeLabel)
        addSubview(endButton)
    }
    
    func setupConstraints() {
        audioSourceButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.centerY.equalToSuperview()
        }
        
        flipCameraButton.snp.makeConstraints { make in
            make.left.equalTo(audioSourceButton.snp.right).offset(RoomSpacing.extraLarge)
            make.centerY.equalToSuperview()
        }
        
        endButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
            make.centerY.equalToSuperview()
        }
        
        roomInfoContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(RoomSpacing.small)
            make.left.greaterThanOrEqualTo(flipCameraButton.snp.right).offset(RoomSpacing.medium)
            make.right.lessThanOrEqualTo(endButton.snp.left).offset(-RoomSpacing.medium)
        }
        
        downArrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.width.height.equalTo(12)
            make.centerY.equalToSuperview()
        }
        
        roomInfoLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.right.equalTo(downArrowImageView.snp.left).offset(-2)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(roomInfoContainerView.snp.bottom).offset(RoomSpacing.extraSmall)
        }
    }
    
    func setupBindings() {
        audioSourceButton.addTarget(self, action: #selector(audioSourceButtonTapped), for: .touchUpInside)
        flipCameraButton.addTarget(self, action: #selector(flipCameraButtonTapped), for: .touchUpInside)
        endButton.addTarget(self, action: #selector(endButtonTapped(sender:)), for: .touchUpInside)
        
        let tap = UITapGestureRecognizer()
        tap.addTarget(self, action:#selector(roomInfoTapped))
        roomInfoContainerView.addGestureRecognizer(tap)
        
        deviceStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentAudioRoute))
            .receive(on: RunLoop.main)
            .sink { [weak self] audioRoute in
                guard let self = self else { return }
                switch audioRoute {
                case .earpiece:
                    audioSourceButton.setImage(ResourceLoader.loadImage("room_audio_source_earpiece"), for: .normal)
                case .speakerphone:
                    audioSourceButton.setImage(ResourceLoader.loadImage("room_audio_source_speaker"), for: .normal)
                }
            }
            .store(in: &cancellableSet)
        
        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] currentRoom in
                guard let self = self, let currentRoom = currentRoom else { return }
                owner = currentRoom.roomOwner
                roomInfoLabel.text = currentRoom.roomName
            }
            .store(in: &cancellableSet)
    }
    
    func setupStyles() {
        // Set content compression resistance to ensure downArrowImageView is always visible
        roomInfoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        downArrowImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

// MARK: - Actions
extension RoomTopBarView {
    @objc private func audioSourceButtonTapped() {
        if deviceStore.state.value.currentAudioRoute == .earpiece {
            deviceStore.setAudioRoute(.speakerphone)
        } else {
            deviceStore.setAudioRoute(.earpiece)
        }
    }
    
    @objc private func flipCameraButtonTapped() {
        deviceStore.switchCamera(isFront: !deviceStore.state.value.isFrontCamera)
    }
    
    @objc private func endButtonTapped(sender: UIButton) {
        delegate?.onEndButtonTapped()
    }
    
    @objc private func roomInfoTapped() {
        delegate?.onRoomInfoButtonTapped()
    }
}

// MARK: - Timer Management
extension RoomTopBarView {
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            self.updateTimeLabel()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeLabel() {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        
        if hours > 0 {
            timeLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            timeLabel.text = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Public Methods
    func resetTimer() {
        elapsedSeconds = 0
        updateTimeLabel()
    }
    
    func resumeTimer() {
        if timer == nil {
            startTimer()
        }
    }
    
    func pauseTimer() {
        stopTimer()
    }
}

fileprivate extension String {
    static let end = "roomkit_end".localized
}
