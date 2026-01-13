//
//  RoomInfoView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/26.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Combine

// MARK: - RoomInfoView
public class RoomInfoView: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    public var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    public var panelHeight: CGFloat {
        return 242 + safeAreaInsets.bottom
    }
    
    // MARK: - Properties
    private lazy var roomStore: RoomStore = RoomStore.shared
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private var cancellableSet = Set<AnyCancellable>()
    private let roomID: String
    private var owner: RoomUser?
    
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
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 18, weight: .medium)
        label.textColor = RoomColors.g7
        label.textAlignment = .left
        return label
    }()
    
    private lazy var infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }()
    
    private lazy var ownerInfoRow: RoomInfoRowView = {
        let row = RoomInfoRowView()
        row.copyButton.isHidden = true
        return row
    }()
    
    private lazy var roomIDInfoRow: RoomInfoRowView = {
        let row = RoomInfoRowView()
        return row
    }()
    
    private lazy var copyAllButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(.copyRoomInfo, for: .normal)
        button.setTitleColor(RoomColors.g6, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        button.backgroundColor = RoomColors.copyButtonBackground.withAlphaComponent(0.3)
        button.layer.cornerRadius = 8
        return button
    }()
    
    // MARK: - Initialization
    public init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        addSubview(containerView)
        
        containerView.addSubview(dropButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(infoStackView)
        containerView.addSubview(copyAllButton)
        
        infoStackView.addArrangedSubview(ownerInfoRow)
        infoStackView.addArrangedSubview(roomIDInfoRow)
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.right.equalToSuperview().offset(-RoomSpacing.large)
        }
        
        infoStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.right.equalToSuperview().offset(-RoomSpacing.large)
        }
        
        copyAllButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.right.equalToSuperview().offset(-RoomSpacing.large)
            make.top.equalTo(infoStackView.snp.bottom).offset(24)
            make.height.equalTo(48)
        }
    }
    
    private func setupStyles() {
        backgroundColor = .clear
    }
    
    private func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        copyAllButton.addTarget(self, action: #selector(copyAllButtonTapped), for: .touchUpInside)
        
        roomIDInfoRow.onCopyTapped = { [weak self] in
            guard let self = self else { return }
            if let roomID = roomStore.state.value.currentRoom?.roomID {
                copyToClipboard(roomID)
                showToast(.roomIDCopied)
            }
        }
        
        roomStore.state
            .subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] roomInfo in
                guard let self = self, let roomInfo = roomInfo else { return }
                owner = roomInfo.roomOwner
                updateRoomInfo(roomInfo)
            }
            .store(in: &cancellableSet)
        
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                if let ownerParticipant = participantList.first(where: { [weak self] participant in
                    guard let self = self else { return false }
                    return participant.userID == owner?.userID
                }) {
                    ownerInfoRow.configure(
                        title: .owner,
                        value: ownerParticipant.name
                    )
                }
            }
            .store(in: &cancellableSet)
    }
    
    // MARK: - Private Methods
    private func updateRoomInfo(_ roomInfo: RoomInfo) {
        titleLabel.text = roomInfo.roomName
        
        ownerInfoRow.configure(
            title: .owner,
            value: roomInfo.roomOwner.name
        )
        
        roomIDInfoRow.configure(
            title: .roomID,
            value: roomInfo.roomID
        )
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    // MARK: - Actions
    @objc private func dropButtonTapped() {
        dismiss()
    }
    
    @objc private func copyAllButtonTapped() {
        guard let roomInfo = roomStore.state.value.currentRoom else { return }
        let allInfo = """
        \(String.roomName): \(roomInfo.roomName)
        \(String.roomID): \(roomInfo.roomID)
        """
        copyToClipboard(allInfo)
        showToast(.roomInfoCopiedSuccess)
    }
}

// MARK: - RoomInfoRowView
private class RoomInfoRowView: UIView {
    
    // MARK: - Properties
    var onCopyTapped: (() -> Void)?
    
    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g6
        label.textAlignment = .left
        return label
    }()
    
    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g7
        label.textAlignment = .left
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    lazy var copyButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setTitle(.copy)
        button.setTitleColor(RoomColors.g6)
        button.setIcon(ResourceLoader.loadImage("room_copy"))
        button.setTitleFont(RoomFonts.pingFangSCFont(size: 12, weight: .regular))
        button.setIconPosition(.left, spacing: 4)
        button.backgroundColor = RoomColors.copyButtonBackground.withAlphaComponent(0.3 )
        button.layer.cornerRadius = 6
        return button
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(copyButton)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(70)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(8)
            make.centerY.equalToSuperview()
            make.right.equalTo(copyButton.snp.left).offset(-8)
        }
        
        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(26)
            make.width.equalTo(64)
        }
        
        snp.makeConstraints { make in
            make.height.equalTo(28)
        }
    }
    
    private func setupBindings() {
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Public Methods
    func configure(title: String, value: String) {
        titleLabel.text = "\(title)"
        valueLabel.text = value
    }
    
    // MARK: - Actions
    @objc private func copyButtonTapped() {
        onCopyTapped?()
    }
}

fileprivate extension String {
    static let copyRoomInfo = "Copy room info".localized
    static let roomIDCopied = "Room ID copied".localized
    static let roomName = "Room name".localized
    static let owner = "Owner".localized
    static let roomID = "Room ID".localized
    static let roomInfoCopiedSuccess = "Room information copied successfully".localized
    static let copy = "Copy".localized
}
