//
//  RoomSelectAttendeesView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/29.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import SnapKit
import Kingfisher
import Combine
import AtomicX
import AtomicXCore

// MARK: - Helpers

private func contactDisplayName(_ contact: ContactInfo) -> String {
    if let remark = contact.friendRemark, !remark.isEmpty { return remark }
    if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
    return contact.userID
}

// MARK: - View

public class RoomSelectAttendeesView: UIView, BaseView {
    
    // MARK: - Layout Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        
        static let searchBarHeight: CGFloat = 42
        static let searchBarCornerRadius: CGFloat = 21
        static let searchIconSize: CGFloat = 16
        
        static let rowHeight: CGFloat = 52
        static let checkboxSize: CGFloat = 16
        static let avatarSize: CGFloat = 32
        static let rowIconSpacing: CGFloat = 6
        
        static let footerHeight: CGFloat = 64
        static let footerAvatarSize: CGFloat = 32
        static let footerAvatarSpacing: CGFloat = 8
        static let footerAvatarMaxCount: Int = 10
        static let confirmButtonHeight: CGFloat = 32
        static let confirmButtonMinWidth: CGFloat = 76
        static let confirmButtonCornerRadius: CGFloat = 16
    }
    
    // MARK: - Public API
        public weak var routerContext: RouterContext?
    
    public var onConfirm: (([ContactInfo]) -> Void)?
    
    // MARK: - Data
    
    private var allMembers: [ContactInfo] = []
    private var visibleMembers: [ContactInfo] = []
    private var selectedUserIDs: Set<String>
    private var cancellableSet = Set<AnyCancellable>()
    private var footerBottomConstraint: Constraint?
    private var footerHeightConstraint: Constraint?
    
    // MARK: - UI Components
    
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.backgroundColor = .white
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "roomkit_select_attendee_title".localized
        label.textColor = RoomColors.g2
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        return label
    }()
    
    private lazy var searchContainer: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        view.layer.cornerRadius = Layout.searchBarCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var searchIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_schedule_search")
        return imageView
    }()
    
    private lazy var searchTextField: UITextField = {
        let field = UITextField()
        field.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        field.textColor = RoomColors.g2
        field.borderStyle = .none
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .search
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        let placeholder = "roomkit_search_attendee_hint".localized
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: RoomColors.g5,
                .font: RoomFonts.pingFangSCFont(size: 14, weight: .regular),
            ]
        )
        field.inputAccessoryView = makeKeyboardDoneToolbar()
        return field
    }()
    
    private lazy var sectionLabel: UILabel = {
        let label = UILabel()
        label.textColor = RoomColors.g2
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .white
        tv.separatorStyle = .none
        tv.rowHeight = Layout.rowHeight
        tv.dataSource = self
        tv.delegate = self
        tv.keyboardDismissMode = .onDrag
        tv.register(RoomSelectAttendeeCell.self,
                    forCellReuseIdentifier: RoomSelectAttendeeCell.reuseID)
        return tv
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "roomkit_no_friends".localized
        label.textColor = RoomColors.g5
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    private lazy var footerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 6
        view.layer.shadowOpacity = 1
        return view
    }()
    
    private var footerAvatarsData: [ContactInfo] = []
    
    private lazy var footerAvatarCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: Layout.footerAvatarSize,
                                 height: Layout.footerAvatarSize)
        layout.minimumLineSpacing = Layout.footerAvatarSpacing
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.alwaysBounceHorizontal = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(RoomFooterAvatarCell.self,
                    forCellWithReuseIdentifier: RoomFooterAvatarCell.reuseID)
        return cv
    }()
    
    private lazy var footerSelectedSummaryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(RoomColors.g2, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        button.contentHorizontalAlignment = .left
        button.isHidden = true
        button.setImage(ResourceLoader.loadImage("room_up_arrow"), for: .normal)
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 1, left: 6, bottom: 0, right: 0)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("roomkit_confirm".localized, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .medium)
        button.backgroundColor = RoomColors.b1
        button.layer.cornerRadius = Layout.confirmButtonCornerRadius
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        return button
    }()
    
    // MARK: - Initialization
    
    public init(initialSelectedUserIDs: [String]) {
        self.selectedUserIDs = Set(initialSelectedUserIDs)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        subscribeContactFriends()
        refreshAfterSelectionOrDataChanged()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - BaseView Implementation
    
    public func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        addSubview(searchContainer)
        searchContainer.addSubview(searchIconView)
        searchContainer.addSubview(searchTextField)
        addSubview(sectionLabel)
        addSubview(tableView)
        addSubview(emptyStateLabel)
        addSubview(footerContainer)
        footerContainer.addSubview(footerAvatarCollectionView)
        footerContainer.addSubview(footerSelectedSummaryButton)
        footerContainer.addSubview(confirmButton)
    }
    
    public func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
                .offset(RoomScheduleLayout.navBarHeight)
        }
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomScheduleLayout.horizontalPadding)
            make.centerY.equalTo(safeAreaLayoutGuide.snp.top)
                .offset(RoomScheduleLayout.navBarHeight / 2 + 2)
            make.size.equalTo(RoomScheduleLayout.backButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        searchContainer.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalTo(backButtonContainerView.snp.bottom).offset(16)
            make.height.equalTo(Layout.searchBarHeight)
        }
        searchIconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.size.equalTo(Layout.searchIconSize)
        }
        searchTextField.snp.makeConstraints { make in
            make.left.equalTo(searchIconView.snp.right).offset(8)
            make.right.equalToSuperview().offset(-12)
            make.top.bottom.equalToSuperview()
        }
        sectionLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalPadding + 3)
            make.top.equalTo(searchContainer.snp.bottom).offset(16)
        }
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(sectionLabel.snp.bottom).offset(8)
            make.bottom.equalTo(footerContainer.snp.top)
        }
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.left.right.equalToSuperview().inset(24)
        }
        footerContainer.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            self.footerBottomConstraint = make.bottom.equalToSuperview().constraint
            self.footerHeightConstraint = make.height
                .equalTo(Layout.footerHeight + WindowUtils.bottomSafeHeight).constraint
        }
        footerAvatarCollectionView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalPadding)
            make.right.equalTo(confirmButton.snp.left).offset(-8)
            make.centerY.equalTo(confirmButton)
            make.height.equalTo(Layout.footerAvatarSize)
        }
        footerSelectedSummaryButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalPadding)
            make.centerY.equalTo(confirmButton)
            make.right.lessThanOrEqualTo(confirmButton.snp.left).offset(-8)
        }
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-Layout.horizontalPadding)
            make.top.equalToSuperview().offset(16)
            make.height.equalTo(Layout.confirmButtonHeight)
            make.width.greaterThanOrEqualTo(Layout.confirmButtonMinWidth)
        }
    }
    
    public func setupStyles() {
        backgroundColor = .white
    }
    
    public func setupBindings() {
        backButton.addTarget(self,
                             action: #selector(handleBack),
                             for: .touchUpInside)
        confirmButton.addTarget(self,
                                action: #selector(handleConfirm),
                                for: .touchUpInside)
        searchTextField.addTarget(self,
                                  action: #selector(handleSearchTextChanged),
                                  for: .editingChanged)
        footerSelectedSummaryButton.addTarget(self,
                                              action: #selector(handleSelectedSummaryTapped),
                                              for: .touchUpInside)
        setupKeyboardObserver()
    }

    // MARK: - Keyboard
    private func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardFrameChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        else { return }
        let endFrameInView = convert(endFrame, from: nil)
        let overlap = max(0, bounds.height - endFrameInView.origin.y)
        let isKeyboardVisible = overlap > 0
        footerBottomConstraint?.update(offset: -overlap)
        footerHeightConstraint?.update(
            offset: isKeyboardVisible
                ? Layout.footerHeight
                : Layout.footerHeight + WindowUtils.bottomSafeHeight
        )
        UIView.animate(withDuration: duration) {
            self.layoutIfNeeded()
        }
    }
    
    // MARK: - Contact source
    private func subscribeContactFriends() {
        ContactStore.shared.loadFriends(completion: nil)
        ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: RunLoop.main)
            .sink { [weak self] friendList in
                guard let self = self else { return }
                self.allMembers = friendList
                self.handleSearchTextChanged()
                self.refreshAfterSelectionOrDataChanged()
            }
            .store(in: &cancellableSet)
    }
    
    // MARK: - State refresh
    
    private func refreshAfterSelectionOrDataChanged() {
        let allCountText = "roomkit_all_participant_format".localizedReplace("\(allMembers.count)")
        sectionLabel.text = allCountText
        emptyStateLabel.isHidden = !allMembers.isEmpty
        tableView.reloadData()
        rebuildFooter()
    }
    
    private func selectedMembersInOrder() -> [ContactInfo] {
        return allMembers.filter { selectedUserIDs.contains($0.userID) }
    }
    
    private func rebuildFooter() {
        rebuildFooterAvatarsOrSummary()
        updateConfirmButtonTitle()
    }
    
    private func rebuildFooterAvatarsOrSummary() {
        let selected = selectedMembersInOrder()
        let count = selected.count
        
        if count > Layout.footerAvatarMaxCount {
            footerAvatarsData = []
            footerAvatarCollectionView.isHidden = true
            footerAvatarCollectionView.reloadData()
            let summary = "roomkit_selected_participant_format".localizedReplace("\(count)")
            footerSelectedSummaryButton.setTitle(summary, for: .normal)
            footerSelectedSummaryButton.isHidden = false
            return
        }
        
        footerSelectedSummaryButton.isHidden = true
        footerAvatarCollectionView.isHidden = false
        footerAvatarsData = selected
        footerAvatarCollectionView.reloadData()
        footerAvatarCollectionView.setContentOffset(.zero, animated: false)
    }
    
    private func updateConfirmButtonTitle() {
        let count = selectedUserIDs.count
        let base = "roomkit_confirm".localized
        let title = "\(base)(\(count))"
        confirmButton.setTitle(title, for: .normal)
        confirmButton.setTitle(title, for: .disabled)
        confirmButton.isEnabled = count > 0
        confirmButton.alpha = 1.0
        confirmButton.backgroundColor = RoomColors.b1
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.setTitleColor(.white, for: .disabled)
    }
    
    // MARK: - Actions
    
    @objc private func handleBack() {
        routerContext?.pop(animated: true)
    }
    
    @objc private func handleConfirm() {
        let selected = selectedMembersInOrder()
        onConfirm?(selected)
        routerContext?.pop(animated: true)
    }
    
    @objc private func handleSearchTextChanged() {
        let raw = searchTextField.text ?? ""
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            visibleMembers = allMembers
        } else {
            visibleMembers = allMembers.filter { contact in
                if contact.userID.lowercased().contains(query) { return true }
                if let remark = contact.friendRemark,
                   remark.lowercased().contains(query) { return true }
                if let nickname = contact.nickname,
                   nickname.lowercased().contains(query) { return true }
                return false
            }
        }
        tableView.reloadData()
    }
    
    // MARK: - Keyboard accessory
    private func makeKeyboardDoneToolbar() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0,
                                              width: UIScreen.main.bounds.width,
                                              height: 44))
        toolbar.autoresizingMask = [.flexibleWidth]
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                       target: nil,
                                       action: nil)
        let done = UIBarButtonItem(title: "roomkit_confirm".localized,
                                   style: .done,
                                   target: self,
                                   action: #selector(handleKeyboardDoneTapped))
        done.tintColor = RoomColors.b1
        toolbar.items = [flexible, done]
        toolbar.sizeToFit()
        return toolbar
    }

    @objc private func handleKeyboardDoneTapped() {
        endEditing(true)
    }

    @objc private func handleSelectedSummaryTapped() {
        let selected = selectedMembersInOrder()
        guard !selected.isEmpty else { return }
        let panel = RoomSelectedAttendeesPanel(members: selected)
        panel.onRemove = { [weak self, weak panel] userID in
            guard let self = self else { return }
            self.removeSelection(userID: userID)
            let updated = self.selectedMembersInOrder()
            panel?.updateMembers(updated)
        }
        panel.show(in: self, animated: true)
    }
    
    fileprivate func removeSelection(userID: String) {
        guard selectedUserIDs.contains(userID) else { return }
        selectedUserIDs.remove(userID)
        rebuildFooter()
        tableView.reloadData()
    }
    
    fileprivate func toggleSelection(for contact: ContactInfo) {
        if selectedUserIDs.contains(contact.userID) {
            selectedUserIDs.remove(contact.userID)
        } else {
            selectedUserIDs.insert(contact.userID)
        }
        rebuildFooter()
        tableView.reloadData()
    }
}

// MARK: - Table Data / Delegate

extension RoomSelectAttendeesView: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleMembers.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RoomSelectAttendeeCell.reuseID,
            for: indexPath) as! RoomSelectAttendeeCell
        let contact = visibleMembers[indexPath.row]
        cell.configure(with: contact,
                       isSelected: selectedUserIDs.contains(contact.userID))
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let contact = visibleMembers[indexPath.row]
        toggleSelection(for: contact)
    }
}

// MARK: - Footer avatar collection data / delegate

extension RoomSelectAttendeesView: UICollectionViewDataSource, UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView,
                               numberOfItemsInSection section: Int) -> Int {
        return footerAvatarsData.count
    }
    
    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RoomFooterAvatarCell.reuseID,
            for: indexPath) as! RoomFooterAvatarCell
        cell.configure(with: footerAvatarsData[indexPath.item])
        return cell
    }
}

// MARK: - Row cell

private class RoomSelectAttendeeCell: UITableViewCell {
    static let reuseID = "RoomSelectAttendeeCell"
    
    /// Cell layout constants (kept local to keep sizes in sync with the
    /// view-level `Layout` enum without exposing it).
    private enum CellLayout {
        static let checkboxSize: CGFloat = 16
        static let avatarSize: CGFloat = 32
        static let horizontalPadding: CGFloat = 20
        static let iconSpacing: CGFloat = 6
    }
    
    private let checkboxView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        // Circular checkbox.
        imageView.layer.cornerRadius = CellLayout.checkboxSize / 2
        imageView.layer.borderWidth = 1
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        // Circular avatar.
        imageView.layer.cornerRadius = CellLayout.avatarSize / 2
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
        
        contentView.addSubview(checkboxView)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(dividerLine)
        
        checkboxView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(CellLayout.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(CellLayout.checkboxSize)
        }
        avatarImageView.snp.makeConstraints { make in
            make.left.equalTo(checkboxView.snp.right).offset(CellLayout.iconSpacing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(CellLayout.avatarSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(CellLayout.iconSpacing)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualToSuperview().offset(-CellLayout.horizontalPadding)
        }
        dividerLine.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView)
            make.right.equalToSuperview().offset(-CellLayout.horizontalPadding)
            make.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with contact: ContactInfo, isSelected: Bool) {
        nameLabel.text = contactDisplayName(contact)
        
        // Avatar (Kingfisher will keep a shared placeholder while loading).
        if let urlString = contact.avatarURL,
           let url = URL(string: urlString) {
            avatarImageView.kf.setImage(
                with: url,
                placeholder: ResourceLoader.loadImage("avatar_placeholder")
            )
        } else {
            avatarImageView.image = ResourceLoader.loadImage("avatar_placeholder")
        }
        
        applyCheckboxState(isSelected: isSelected)
    }
    
    private func applyCheckboxState(isSelected: Bool) {
        if isSelected {
            checkboxView.backgroundColor = RoomColors.b1
            checkboxView.layer.borderColor = RoomColors.b1.cgColor
            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(
                    pointSize: 10,
                    weight: .bold
                )
                checkboxView.image = UIImage(systemName: "checkmark",
                                             withConfiguration: config)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
            } else {
                checkboxView.image = nil
            }
        } else {
            checkboxView.backgroundColor = .white
            checkboxView.layer.borderColor = RoomColors.g7.cgColor
            checkboxView.image = nil
        }
    }
}

// MARK: - Footer avatar cell

private class RoomFooterAvatarCell: UICollectionViewCell {
    static let reuseID = "RoomFooterAvatarCell"
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = RoomColors.g8
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 1.0
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = nil
    }
    
    func configure(with contact: ContactInfo) {
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
}
