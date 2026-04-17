//
//  RoomCreateView.swift
//  TUIRoomKit
//
//  Created on 2025/11/12.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Combine

public class RoomCreateView: UIView, BaseView {
    
    // MARK: - Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 12
        static let cardInnerPadding: CGFloat = 16
        static let rowHeight: CGFloat = 56
        static let cardCornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 52
        static let buttonHorizontalInset: CGFloat = 88
        static let navBarHeight: CGFloat = 60
        static let backButtonSize: CGFloat = 16
        static let navBarTopInset: CGFloat = 22
        static let topSpacingAfterNav: CGFloat = 42
        static let buttonTopSpacing: CGFloat = 48
    }
    
    // MARK: - Properties
    public weak var routerContext: RouterContext?
    private var cancellableSet = Set<AnyCancellable>()
    private var connectConfig: ConnectConfig = ConnectConfig()
    private var selectedRoomType: RoomType = .standard
    
    // MARK: - UI Components
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        makeLabel(.createRoom, color: RoomColors.g2, weight: .medium)
    }()
    
    private lazy var roomTypeCardStackView: UIStackView = {
        makeCardStackView()
    }()
    
    private lazy var roomTypeLabel: UILabel = {
        makeLabel(.roomType)
    }()
    
    private lazy var selectRoomTypeLabel: UILabel = {
        let label = makeLabel(selectedRoomType == .webinar ? .webinarRoom : .meetingRoom, color: RoomColors.g2)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var downArrowImageView: UIImageView = {
        let imageView = UIImageView(image: ResourceLoader.loadImage("room_chevron_down_arrow"))
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()
    
    private lazy var yourNameLabel: UILabel = {
        makeLabel(.yourName)
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = makeLabel("", color: RoomColors.g2)
        return label
    }()
    
    private lazy var formCardStackView: UIStackView = {
        makeCardStackView()
    }()
    
    private lazy var microphoneSwitch = makeSwitch()
    private lazy var speakerSwitch = makeSwitch()
    private lazy var cameraSwitch = makeSwitch()
    
    private lazy var roomTypeRow: UIStackView = {
        let row = makeFormRow(roomTypeLabel, selectRoomTypeLabel, downArrowImageView)
        row.isUserInteractionEnabled = true
        return row
    }()
    
    private lazy var createRoomButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.backgroundColor = RoomColors.brandBlue
        button.setTitle(.createRoom, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .semibold)
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
    
    public func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        
        addSubview(roomTypeCardStackView)
        roomTypeCardStackView.addArrangedSubviews(
            roomTypeRow,
            makeDivider(),
            makeFormRow(yourNameLabel, nameLabel)
        )
        
        addSubview(formCardStackView)
        formCardStackView.addArrangedSubviews(
            makeSwitchRow(.enableAudio, microphoneSwitch),
            makeDivider(),
            makeSwitchRow(.enableSpeaker, speakerSwitch),
            makeDivider(),
            makeSwitchRow(.enableVideo, cameraSwitch)
        )
        
        addSubview(createRoomButton)
    }
    
    public func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.right.equalTo(titleLabel.snp.right).offset(20)
            make.height.equalTo(Layout.navBarHeight)
        }
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalPadding)
            make.top.equalToSuperview().offset(Layout.navBarTopInset)
            make.size.equalTo(Layout.backButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(backButton.snp.right).offset(Layout.horizontalPadding)
            make.centerY.equalTo(backButton)
        }
        roomTypeCardStackView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.topSpacingAfterNav)
        }
        formCardStackView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalTo(roomTypeCardStackView.snp.bottom).offset(RoomSpacing.standard)
        }
        createRoomButton.snp.makeConstraints { make in
            make.top.equalTo(formCardStackView.snp.bottom).offset(Layout.buttonTopSpacing)
            make.height.equalTo(Layout.buttonHeight)
            make.leading.trailing.equalToSuperview().inset(Layout.buttonHorizontalInset)
        }
    }
    
    public func setupStyles() {
        backgroundColor = RoomColors.g8
        microphoneSwitch.isOn = connectConfig.autoEnableMicrophone
        speakerSwitch.isOn = connectConfig.autoEnableSpeaker
        cameraSwitch.isOn = connectConfig.autoEnableCamera
    }
    
    public func setupBindings() {
        backButtonContainerView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleBackButtonTapped))
        )
        roomTypeRow.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleRoomTypeTapped))
        )
        createRoomButton.addTarget(self, action: #selector(handleCreateRoomButtonTapped), for: .touchUpInside)
        microphoneSwitch.addTarget(self, action: #selector(handleMicrophoneSwitchChanged(sender:)), for: .valueChanged)
        speakerSwitch.addTarget(self, action: #selector(handleSpeakerSwitchChanged(sender:)), for: .valueChanged)
        cameraSwitch.addTarget(self, action: #selector(handleCameraSwitchChanged(sender:)), for: .valueChanged)
    }
    
    // MARK: - Store Observers
    
    private func setupStoreObservers() {
        LoginStore.shared.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
            .receive(on: RunLoop.main)
            .sink { [weak self] loginUser in
                guard let self = self, let loginUser = loginUser else { return }
                nameLabel.text = loginUser.nickname ?? loginUser.userID
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Factory Helpers
extension RoomCreateView {
    
    private func makeLabel(_ text: String, color: UIColor = RoomColors.g3, weight: UIFont.Weight = .regular) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: weight)
        label.textColor = color
        return label
    }
    
    private func makeSwitch() -> UISwitch {
        let toggle = UISwitch()
        toggle.onTintColor = RoomColors.b1
        return toggle
    }
    
    private func makeCardStackView() -> UIStackView {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.backgroundColor = .white
        sv.layer.cornerRadius = Layout.cardCornerRadius
        sv.clipsToBounds = true
        sv.layoutMargins = UIEdgeInsets(top: 0, left: Layout.cardInnerPadding, bottom: 0, right: Layout.cardInnerPadding)
        sv.isLayoutMarginsRelativeArrangement = true
        return sv
    }
    
    /// Form row: [title] — [content] — [optional accessory], height = rowHeight
    private func makeFormRow(_ title: UIView, _ content: UIView, _ accessory: UIView? = nil) -> UIStackView {
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [title, content] + (accessory.map { [$0] } ?? []))
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 20
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }
        return row
    }
    
    /// Switch row: [label — spacer — switch]
    private func makeSwitchRow(_ title: String, _ switchView: UISwitch) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [makeLabel(title), switchView])
        row.axis = .horizontal
        row.alignment = .center
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }
        return row
    }
    
    /// 1px divider
    private func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = RoomColors.g8
        line.snp.makeConstraints { $0.height.equalTo(1) }
        return line
    }
}

// MARK: - Actions
extension RoomCreateView {
    
    @objc private func handleBackButtonTapped() {
        routerContext?.pop(animated: true)
    }
    
    @objc private func handleRoomTypeTapped() {
        // TODO:
        var appearance = RoomActionSheet.Appearance()
        appearance.backgroundColor = .white
        appearance.separatorColor = RoomColors.g8
        let actionSheet = RoomActionSheet(actions: [
                                            RoomActionSheet.Action(title: .meetingRoom,
                                                                   titleColor: .black,
                                                                   titleFont: RoomFonts.pingFangSCFont(size: 18, weight: .regular),
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       selectedRoomType = .standard
                                                                       selectRoomTypeLabel.text = .meetingRoom
                                                                   }),
                                            RoomActionSheet.Action(title: .webinarRoom,
                                                                   titleColor: .black,
                                                                   titleFont: RoomFonts.pingFangSCFont(size: 18, weight: .regular),
                                                                   handler: { [weak self] action in
                                                                       guard let self = self else { return }
                                                                       selectedRoomType = .webinar
                                                                       selectRoomTypeLabel.text = .webinarRoom
                                                                   }),
                                         ], appearance: appearance)
        actionSheet.show(in: self, animated: true)
    }
    
    @objc private func handleMicrophoneSwitchChanged(sender: UISwitch) {
        connectConfig.autoEnableMicrophone = sender.isOn
    }
    
    @objc private func handleSpeakerSwitchChanged(sender: UISwitch) {
        connectConfig.autoEnableSpeaker = sender.isOn
    }
    
    @objc private func handleCameraSwitchChanged(sender: UISwitch) {
        connectConfig.autoEnableCamera = sender.isOn
    }
    
    @objc private func handleCreateRoomButtonTapped() {
        guard let name = nameLabel.text else { return }
        let roomID = generateRoomId(numberOfDigits: 6)
        var options = CreateRoomOptions()
        options.roomName = .roomName.localizedReplace(name)
        let mainViewController = RoomMainViewController(roomID: roomID,
                                                        behavior: .create(options: options),
                                                        config: connectConfig)
        routerContext?.push(mainViewController, animated: true)
    }
    
    private func generateRoomId(numberOfDigits: Int) -> String {
        var numberOfDigit = numberOfDigits > 0 ? numberOfDigits : 1
        numberOfDigit = numberOfDigit < 10 ? numberOfDigit : 9
        let minNumber = Int(truncating: NSDecimalNumber(decimal: pow(10, numberOfDigit - 1)))
        let maxNumber = Int(truncating: NSDecimalNumber(decimal: pow(10, numberOfDigit))) - 1
        let randomNumber = arc4random_uniform(UInt32(maxNumber - minNumber)) + UInt32(minNumber)
        
        switch selectedRoomType {
        case .standard:
            return String(randomNumber)
        case .webinar:
            return "webinar_" + String(randomNumber)
        }
    }
}

// MARK: - UIStackView Convenience
private extension UIStackView {
    func addArrangedSubviews(_ views: UIView...) {
        views.forEach { addArrangedSubview($0) }
    }
}

fileprivate extension String {
    static let createRoom = "roomkit_create_room".localized
    static let yourName = "roomkit_your_name".localized
    static let enableAudio = "roomkit_enable_audio".localized
    static let enableSpeaker = "roomkit_enable_speaker".localized
    static let enableVideo = "roomkit_enable_video".localized
    static let roomName = "roomkit_user_room"
    static let webinarRoom = "roomkit_room_type_webinar".localized
    static let meetingRoom = "roomkit_room_type_meeting".localized
    static let roomType = "roomkit_room_type".localized
}
