//
//  RoomSelectedAttendeesPanel.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/29.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import SnapKit
import Kingfisher
import AtomicX
import AtomicXCore

/// Bottom-sliding panel that lists the currently-selected attendees.
class RoomSelectedAttendeesPanel: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - Public API
    
    var onRemove: ((String) -> Void)?
    
    // MARK: - BasePanel
    weak var parentView: UIView?
    weak var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    var panelHeight: CGFloat {
        return UIScreen.main.bounds.height * 0.6 + WindowUtils.bottomSafeHeight
    }
    
    // MARK: - Layout Constants
    private enum PanelLayout {
        static let cornerRadius: CGFloat = 16
        static let headerHeight: CGFloat = 54
        static let rowHeight: CGFloat = 52
    }
    
    // MARK: - Data
    private var members: [ContactInfo]
    private let allowsRemoval: Bool
    
    // MARK: - UI Components
    
    private lazy var headerContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var dragHandleView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_drop_arrow")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RoomColors.g3
        label.font = RoomFonts.pingFangSCFont(size: 18, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var separator: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = PanelLayout.rowHeight
        tv.dataSource = self
        tv.delegate = self
        tv.register(RoomSelectedAttendeeRow.self,
                    forCellReuseIdentifier: RoomSelectedAttendeeRow.reuseID)
        return tv
    }()
    
    // MARK: - Init
    
    init(members: [ContactInfo], allowsRemoval: Bool = true) {
        self.members = members
        self.allowsRemoval = allowsRemoval
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setupConstraints()
        refreshTitle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = PanelLayout.cornerRadius
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true
        
        addSubview(headerContainer)
        headerContainer.addSubview(dragHandleView)
        headerContainer.addSubview(titleLabel)
        addSubview(separator)
        addSubview(tableView)

        let dragTap = UITapGestureRecognizer(target: self, action: #selector(handleDragHandleTapped))
        dragHandleView.addGestureRecognizer(dragTap)
    }
    
    private func setupConstraints() {
        headerContainer.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(PanelLayout.headerHeight)
        }
        dragHandleView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview().offset(4)
        }
        separator.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(headerContainer.snp.bottom)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(-WindowUtils.bottomSafeHeight)
        }
    }

    @objc private func handleDragHandleTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Public
    
    func updateMembers(_ newMembers: [ContactInfo]) {
        members = newMembers
        refreshTitle()
        tableView.reloadData()
    }
    
    // MARK: - Private
    
    private func refreshTitle() {
        titleLabel.text = "roomkit_selected_participant_format".localizedReplace("\(members.count)")
    }
}

// MARK: - Table data / delegate

extension RoomSelectedAttendeesPanel: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RoomSelectedAttendeeRow.reuseID,
            for: indexPath) as! RoomSelectedAttendeeRow
        let contact = members[indexPath.row]
        cell.configure(with: contact, allowsRemoval: allowsRemoval) { [weak self] userID in
            self?.onRemove?(userID)
        }
        return cell
    }
}

// MARK: - Row cell

private class RoomSelectedAttendeeRow: UITableViewCell {
    static let reuseID = "RoomSelectedAttendeeRow"
    
    private enum RowLayout {
        static let avatarSize: CGFloat = 32
        static let horizontalPadding: CGFloat = 20
        static let iconSpacing: CGFloat = 6
    }
    
    private var currentUserID: String?
    private var onRemove: ((String) -> Void)?
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = RowLayout.avatarSize / 2
        imageView.clipsToBounds = true
        imageView.backgroundColor = RoomColors.g8
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g2
        return label
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("room_attendees_delete"), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return button
    }()
    
    private let dividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .white
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(closeButton)
        contentView.addSubview(dividerLine)
        
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RowLayout.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(RowLayout.avatarSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RowLayout.iconSpacing)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualTo(closeButton.snp.left).offset(-8)
        }
        closeButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-RowLayout.horizontalPadding + 8)
            make.centerY.equalToSuperview()
        }
        dividerLine.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView)
            make.right.equalToSuperview().offset(-RowLayout.horizontalPadding)
            make.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        
        closeButton.addTarget(self,
                              action: #selector(handleCloseTapped),
                              for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with contact: ContactInfo,
                   allowsRemoval: Bool = true,
                   onRemove: @escaping (String) -> Void) {
        currentUserID = contact.userID
        self.onRemove = onRemove
        closeButton.isHidden = !allowsRemoval
        nameLabel.text = Self.displayName(for: contact)
        if let urlString = contact.avatarURL,
           let url = URL(string: urlString) {
            avatarImageView.kf.setImage(
                with: url,
                placeholder: ResourceLoader.loadImage("avatar_placeholder")
            )
        } else {
            avatarImageView.image = ResourceLoader.loadImage("avatar_placeholder")
        }
    }
    
    @objc private func handleCloseTapped() {
        guard let userID = currentUserID else { return }
        onRemove?(userID)
    }
    
    private static func displayName(for contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return contact.userID
    }
}
