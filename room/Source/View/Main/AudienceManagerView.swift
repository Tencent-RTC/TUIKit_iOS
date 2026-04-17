//
//  AudienceManagerView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/1/29.
//

import UIKit
import SnapKit
import AtomicXCore
import Kingfisher
import Combine
import AtomicX


public protocol AudienceManagerViewDelegate: AnyObject {
    func handleKickOut(view: AudienceManagerView, audience: RoomUser)
    func handleSetAsAdmin(view: AudienceManagerView, audience: RoomUser, isAdmin: Bool)
}

// MARK: - AudienceManagerView
public class AudienceManagerView: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    weak public var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    public var panelHeight: CGFloat {
        let headerHeight: CGFloat = 100
        let itemHeight: CGFloat = 56
        let totalItemsHeight = CGFloat(actionItems.count) * itemHeight
        let bottomSafeArea = WindowUtils.bottomSafeHeight
        return headerHeight + totalItemsHeight + bottomSafeArea + 20
    }
    
    public weak var delegate: AudienceManagerViewDelegate?
    
    // MARK: - Properties
    private var audience: RoomUser
    private var markIsAdmin: Bool?
    private var adminList: [RoomUser] = []
    private let roomID: String
    private var actionItems: [ActionItem] = []
    private var cancellableSet = Set<AnyCancellable>()
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
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
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g7
        label.textAlignment = .left
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.isScrollEnabled = false
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.cellReuseIdentifier)
        return tableView
    }()
    
    // MARK: - Initialization
    public init(audience: RoomUser, roomID: String) {
        self.audience = audience
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        setupActionItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(dropButton)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(tableView)
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.top.equalTo(dropButton.snp.bottom).offset(RoomSpacing.large)
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.width.height.equalTo(40)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(RoomSpacing.small)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    private func setupStyles() {
        backgroundColor = .clear
        avatarImageView.kf.setImage(with: URL(string: audience.avatarURL), placeholder: ResourceLoader.loadImage("avatar_placeholder"))
        nameLabel.text = audience.name
    }
    
    private func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.audienceList))
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceList in
                guard let self = self else { return }
                let oldAudience = audience
                if let newAudience = audienceList.first(where: { $0.userID == oldAudience.userID }) {
                    audience = newAudience
                    nameLabel.text = newAudience.name
                    setupActionItems()
                } else {
                    dismiss()
                }
            }
            .store(in: &cancellableSet)
        participantStore.state
            .subscribe(StatePublisherSelector(keyPath: \.adminList))
            .receive(on: RunLoop.main)
            .sink { [weak self] adminList in
                guard let self = self else { return }
                self.adminList = adminList
                let isAdmin = isAdmin(user: audience)
                if markIsAdmin == nil || markIsAdmin != isAdmin {
                    setupActionItems()
                    markIsAdmin = isAdmin
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func setupActionItems() {
        actionItems.removeAll()
        setupRemoteActionItems()
        tableView.reloadData()
    }
    
    private func setupRemoteActionItems() {
        let role = participantStore.state.value.localParticipant?.role
        if role == .admin {
            actionItems.append(contentsOf: [
                ActionItem(
                    icon: ResourceLoader.loadImage("room_members"),
                    title: .setParticipant,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        setParticipant()
                    },
                ActionItem(
                    icon: ResourceLoader.loadImage("room_kickout"),
                    title: .remove,
                    textColor: RoomColors.endTitleColor) { [weak self] in
                        guard let self = self else { return }
                        handleKickOut()
                    }
            ])
        } else if role == .owner {
            actionItems.append(contentsOf: [
                ActionItem(
                    icon: ResourceLoader.loadImage("room_members"),
                    title: .setParticipant,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        setParticipant()
                    },
                ActionItem(
                    icon: isAdmin(user: audience) ? ResourceLoader.loadImage("room_undo_administrator") :
                        ResourceLoader.loadImage("room_set_admin"),
                    title: isAdmin(user: audience) ?
                        .undoAdministrator :
                        .setAsAdministrator,
                    textColor: RoomColors.g7) { [weak self] in
                        guard let self = self else { return }
                        handleSetAsAdmin()
                    },
                ActionItem(
                    icon: ResourceLoader.loadImage("room_kickout"),
                    title: .remove,
                    textColor: RoomColors.endTitleColor) { [weak self] in
                        guard let self = self else { return }
                        handleKickOut()
                    }
            ])
        }
    }
    
    private func isAdmin(user: RoomUser) -> Bool {
        let result = adminList.filter { $0.userID == user.userID }
        return !result.isEmpty
    }
}

// MARK: - Action Handlers
extension AudienceManagerView {
    @objc private func dropButtonTapped() {
        dismiss()
    }
    
    private func setParticipant() {
        participantStore.promoteAudienceToParticipant(userID: audience.userID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success: break
            case .failure(let err):
                showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
            }
            dismiss(animated: true)
        }
    }
    
    private func handleKickOut() {
        delegate?.handleKickOut(view: self, audience: audience)
    }
    
    private func handleSetAsAdmin() {
        delegate?.handleSetAsAdmin(view: self, audience: audience, isAdmin: isAdmin(user: audience))
    }
}

// MARK: - UITableViewDataSource
extension AudienceManagerView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actionItems.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ActionCell.cellReuseIdentifier, for: indexPath) as? ActionCell else {
            return UITableViewCell()
        }
        
        let item = actionItems[indexPath.row]
        cell.configure(with: item)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AudienceManagerView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = actionItems[indexPath.row]
        item.action()
    }
}

fileprivate extension String {
    static let setParticipant = "roomkit_set_participant".localized
    static let remove = "roomkit_remove_member".localized
    static let undoAdministrator = "roomkit_revoke_admin".localized
    static let setAsAdministrator = "roomkit_set_admin".localized
}

