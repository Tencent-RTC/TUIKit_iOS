//
//  HandsUpListView.swift
//  AFNetworking
//
//  Created by adamsfliu on 2026/4/1.
//

import UIKit
import SnapKit
import Combine
import AtomicXCore
import Kingfisher

public class HandsUpListView: UIView, BasePanel, PanelHeightProvider {

    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    weak public var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    public var panelHeight: CGFloat {
        return UIScreen.main.bounds.height * 0.8
    }
    
    public weak var delegate: ParticipantListViewDelegate?
    
    // MARK: - Properties
    
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    private let roomStore: RoomStore = RoomStore.shared
    private let roomID: String
    
    private var applicationList: [DeviceRequestInfo] = []
    
    private var cancellableSet = Set<AnyCancellable>()
    
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = RoomCornerRadius.extraLarge
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var dropButton: UIButton = {
        let dropButton = UIButton()
        dropButton.setImage(ResourceLoader.loadImage("room_drop_arrow"), for: .normal)
        dropButton.imageView?.contentMode = .center
        return dropButton
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g7
        label.textAlignment = .left
        label.text = .hansUpTitle
        return label
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = .handsUpEmpty
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g6
        return label
    }()
    
    private lazy var handsUpTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.tag = 1
        tableView.register(HandsUpListViewCell.self, forCellReuseIdentifier: HandsUpListViewCell.cellReuseIdentifier)
        return tableView
    }()
    
    // MARK: - Initialization
    public init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - BaseView Implementation
    func setupViews() {
        addSubview(containerView)
        containerView.addSubview(dropButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(handsUpTableView)
        handsUpTableView.addSubview(emptyLabel)
    }
    
    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
        }
        
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        handsUpTableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(RoomSpacing.medium)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    func setupStyles() {
        backgroundColor = .clear
    }
    
    func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.pendingDeviceApplications))
            .receive(on: RunLoop.main)
            .sink { [weak self] applications in
                guard let self = self else { return }
                let micApplications = applications.filter { $0.device == .microphone }
                emptyLabel.isHidden = !micApplications.isEmpty
                applicationList = micApplications
                handsUpTableView.reloadData()
            }
            .store(in: &cancellableSet)
    }
    
    private func handleAgree(application: DeviceRequestInfo) {
        RoomKitLog.info("Promoted audience to participant: \(application.senderUserID)")
        participantStore.promoteAudienceToParticipant(userID: application.senderUserID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                approveDeviceRequest(application: application)
            case .failure(let err):
                RoomKitLog.error("Failed to promote audience to participant: code=\(err.code), message=\(err.message)")
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
        }
    }
    
    private func approveDeviceRequest(application: DeviceRequestInfo) {
        RoomKitLog.info("Approved hands up request from \(application.senderUserID)")
        participantStore.approveOpenDeviceRequest(device: application.device, userID: application.senderUserID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                RoomKitLog.error("Failed to approve hands up request: code=\(err.code), message=\(err.message)")
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
        }
    }
    
    private func rejectDeviceRequest(application: DeviceRequestInfo) {
        RoomKitLog.info("Rejecting hands up request from \(application.senderUserID)")
        participantStore.rejectOpenDeviceRequest(device: application.device, userID: application.senderUserID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(): break
            case .failure(let err):
                RoomKitLog.error("Failed to reject hands up request: code=\(err.code), message=\(err.message)")
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
        }
    }
    
}

// MARK: - Actions
extension HandsUpListView {
    @objc private func dropButtonTapped() {
        dismiss()
    }
}

extension HandsUpListView: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return applicationList.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: HandsUpListViewCell.cellReuseIdentifier, for: indexPath) as? HandsUpListViewCell else {
            return UITableViewCell()
        }
        
        let application = applicationList[indexPath.row]
        cell.configureApplication(application)
        cell.onAgreeEvent = { [weak self] application in
            guard let self = self else { return }
            handleAgree(application: application)
        }
        cell.onRejectEvent = { [weak self] application in
            guard let self = self else { return }
            rejectDeviceRequest(application: application)
        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - BaseParticipantCell
private class HandsUpListViewCell: UITableViewCell {
    
    // MARK: - Properties
    private var application: DeviceRequestInfo?
    
    // MARK: - UI Components
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 24
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g7
        return label
    }()
    
    lazy var agreeButton: UIButton = {
        let button = UIButton()
        button.setTitle(.agree, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        button.backgroundColor = RoomColors.b1
        button.layer.cornerRadius = 16
        return button
    }()
    
    lazy var rejectButton: UIButton = {
        let button = UIButton()
        button.setTitle(.reject, for: .normal)
        button.setTitleColor(RoomColors.b1, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        button.backgroundColor = .clear
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = RoomColors.b1.cgColor
        return button
    }()
    
    lazy var dividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        return view
    }()
    
    var onAgreeEvent: ((DeviceRequestInfo) -> Void)?
    var onRejectEvent: ((DeviceRequestInfo) -> Void)?
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(agreeButton)
        contentView.addSubview(rejectButton)
        contentView.addSubview(dividerLine)
    }
    
    func setupConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView
                .snp.right).offset(RoomSpacing.medium)
            make.centerY.equalToSuperview()
            make.right.equalTo(agreeButton
                .snp.left).offset(RoomSpacing.small)
        }
        
        agreeButton.snp.makeConstraints { make in
            make.right.equalTo(rejectButton.snp.left).offset(-RoomSpacing.small)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 60, height: 32))
        }
        
        rejectButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-RoomSpacing.large)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 60, height: 32))
        }
        
        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(rejectButton.snp.right)
            make.height.equalTo(1)
        }
    }
    
    func setupStyles() {
        contentView.backgroundColor = RoomColors.g2
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    func setupBindings() {
        agreeButton.addTarget(self, action: #selector(agreeButtonTapped), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(rejectButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Common Methods
    func configureApplication(_ application: DeviceRequestInfo) {
        self.application = application
        avatarImageView.kf.setImage(
            with: URL(string: application.senderAvatarURL),
            placeholder: ResourceLoader.loadImage("avatar_placeholder")
        )
        
        nameLabel.text = application.getSenderDisplayName()
    }
    
    @objc private func agreeButtonTapped() {
        if let application = application {
            onAgreeEvent?(application)
        }
    }
    
    @objc private func rejectButtonTapped() {
        if let application = application {
            onRejectEvent?(application)
        }
    }
}

extension DeviceRequestInfo {
    func getSenderDisplayName() -> String {
        if !senderNameCard.isEmpty {
            return senderNameCard
        }
        if !senderUserName.isEmpty  {
            return senderUserName
        }
        return senderUserID
    }
}

fileprivate extension String {
    static let hansUpTitle = "roomkit_hands_up_list".localized
    static let agree = "roomkit_agree".localized
    static let reject = "roomkit_reject".localized
    static let handsUpEmpty = "roomkit_hands_up_empty".localized
}
