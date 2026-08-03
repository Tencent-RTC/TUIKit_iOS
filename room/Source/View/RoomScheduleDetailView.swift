//
//  RoomScheduleDetailView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/30.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import SnapKit
import AtomicX
import AtomicXCore
import Kingfisher
import Combine

public class RoomScheduleDetailView: UIView, BaseView {

    // MARK: - Public API

    public weak var routerContext: RouterContext?

    public var onModify: ((RoomInfo) -> Void)?
    public var onEnterRoom: ((RoomInfo) -> Void)?
    public var onInviteMember: ((RoomInfo) -> Void)?
    public var onCancelled: ((RoomInfo) -> Void)?

    // MARK: - Layout

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = 6
        static let cardInset: CGFloat = 16
        static let rowHeight: CGFloat = 42
        static let labelColumnWidth: CGFloat = 84
        static let actionRowHeight: CGFloat = 44
        static let actionRowSpacing: CGFloat = 16
        static let actionRowCornerRadius: CGFloat = 8
        static let avatarSize: CGFloat = 24
        static let originatorAvatarSize: CGFloat = 24
        static let avatarSpacing: CGFloat = 8
        static let maxAvatars: Int = 3
    }

    // MARK: - Data

    private let roomID: String
    private let timeZone: TimeZone
    private let roomStore: RoomStore = RoomStore.shared
    private var cancellableSet = Set<AnyCancellable>()
    private var currentRoomInfo: RoomInfo?
    private var cachedAttendees: [RoomUser]?
    private weak var participantsRow: UIView?
    private var hasFetchedAttendees = false
    private var isFetchingAttendees = false
    private var hasShownDestroyedToast = false

    // MARK: - UI Components

    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .roomDetail
        label.textColor = RoomColors.g2
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        return label
    }()

    private lazy var modifyButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(.modify, for: .normal)
        button.setTitleColor(RoomColors.b1, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        button.addTarget(self, action: #selector(handleModifyTapped), for: .touchUpInside)
        return button
    }()

    private lazy var infoCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = Layout.cardCornerRadius
        view.clipsToBounds = true
        return view
    }()

    private lazy var infoRowsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()

    private lazy var actionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.actionRowSpacing
        return stack
    }()

    // MARK: - Init

    public init(roomInfo: RoomInfo, timeZone: TimeZone = .current) {
        self.roomID = roomInfo.roomID
        self.timeZone = timeZone
        self.currentRoomInfo = roomInfo
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - BaseView

    public func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        backButtonContainerView.addSubview(modifyButton)
        addSubview(infoCardView)
        infoCardView.addSubview(infoRowsStackView)
        addSubview(actionsStackView)

        refreshInfoRows()
        buildActionRows()
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
        modifyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-RoomScheduleLayout.horizontalPadding)
            make.centerY.equalTo(backButton)
        }
        infoCardView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalInset)
            make.right.equalToSuperview().offset(-Layout.horizontalInset)
            make.top.equalTo(backButtonContainerView.snp.bottom).offset(RoomScheduleLayout.topSpacingAfterNav)
        }
        infoRowsStackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.cardInset)
            make.right.equalToSuperview().offset(-Layout.cardInset)
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }
        actionsStackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalInset)
            make.right.equalToSuperview().offset(-Layout.horizontalInset)
            make.top.equalTo(infoCardView.snp.bottom).offset(20)
        }
    }

    public func setupStyles() {
        backgroundColor = RoomColors.themeBackground
        backButtonContainerView.backgroundColor = .white
        modifyButton.isHidden = !canManageRoom
    }

    private var canManageRoom: Bool {
        guard let info = currentRoomInfo else { return false }
        let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID
        let ownerID = info.roomOwner.userID
        let isOwner = !ownerID.isEmpty && ownerID == selfUserID
        return isOwner && info.roomStatus != .running
    }

    public func setupBindings() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        subscribeScheduledRoomList()
    }

    // MARK: - Store subscription
    private func subscribeScheduledRoomList() {
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \RoomState.scheduledRoomList))
            .receive(on: RunLoop.main)
            .sink { [weak self] rooms in
                self?.handleScheduledRoomListUpdate(rooms)
            }
            .store(in: &cancellableSet)
    }

    private func handleScheduledRoomListUpdate(_ rooms: [RoomInfo]) {
        guard let info = rooms.first(where: { $0.roomID == roomID }) else {
            showRoomDestroyedToastAndPop()
            return
        }

        let previousStatus = currentRoomInfo?.roomStatus
        currentRoomInfo = info
        if info.roomStatus == .running, previousStatus != .running {
            showRoomDestroyedToast()
        }

        refreshManageButtonsVisibility()
        refreshInfoRows()
    }

    private func showRoomDestroyedToast() {
        guard !hasShownDestroyedToast else { return }
        hasShownDestroyedToast = true
        showAtomicToast(text: .roomClosed, style: .warning, position: .center)
    }

    private func showRoomDestroyedToastAndPop() {
        showRoomDestroyedToast()
        routerContext?.pop(animated: true)
    }

    private func refreshManageButtonsVisibility() {
        modifyButton.isHidden = !canManageRoom
        rebuildActionRows()
    }

    // MARK: - Info rows

    private var currentAttendees: [RoomUser] {
        return cachedAttendees ?? currentRoomInfo?.scheduleAttendees ?? []
    }

    private func refreshInfoRows() {
        for view in infoRowsStackView.arrangedSubviews {
            infoRowsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard let info = currentRoomInfo else { return }
        infoRowsStackView.addArrangedSubview(makeInfoRow(label: .roomName, value: info.roomName))
        infoRowsStackView.addArrangedSubview(makeRoomIDRow())
        infoRowsStackView.addArrangedSubview(makeInfoRow(label: .startTime, value: formattedStartTime()))
        infoRowsStackView.addArrangedSubview(makeInfoRow(label: .roomDuration, value: formattedDuration()))
        infoRowsStackView.addArrangedSubview(makeOriginatorRow())
        let participants = makeParticipantsRow()
        participantsRow = participants
        infoRowsStackView.addArrangedSubview(participants)
    }

    // MARK: - Attendees fetch

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !hasFetchedAttendees else { return }
        hasFetchedAttendees = true
        fetchScheduledAttendees()
    }

    private func fetchScheduledAttendees() {
        guard !isFetchingAttendees else { return }
        isFetchingAttendees = true
        fetchScheduledAttendeesPage(cursor: nil, accumulated: [])
    }

    private func fetchScheduledAttendeesPage(cursor: String?, accumulated: [RoomUser]) {
        RoomStore.shared.getScheduledAttendees(roomID: roomID, cursor: cursor) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let (attendees, nextCursor)):
                    let combined = accumulated + attendees
                    self.cachedAttendees = combined
                    self.rebuildParticipantsRow()
                    if !nextCursor.isEmpty {
                        self.fetchScheduledAttendeesPage(cursor: nextCursor, accumulated: combined)
                    } else {
                        self.isFetchingAttendees = false
                    }
                case .failure:
                    self.isFetchingAttendees = false
                    break
                }
            }
        }
    }

    public func refreshAttendees() {
        fetchScheduledAttendees()
    }

    private func rebuildParticipantsRow() {
        let newRow = makeParticipantsRow()
        if let old = participantsRow, let index = infoRowsStackView.arrangedSubviews.firstIndex(of: old) {
            infoRowsStackView.removeArrangedSubview(old)
            old.removeFromSuperview()
            infoRowsStackView.insertArrangedSubview(newRow, at: index)
        } else {
            infoRowsStackView.addArrangedSubview(newRow)
        }
        participantsRow = newRow
    }

    private func makeRowLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g2
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }

        let labelLabel = makeRowLabel(label)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        valueLabel.textColor = RoomColors.valueText
        valueLabel.numberOfLines = 1
        valueLabel.textAlignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail

        row.addSubview(labelLabel)
        row.addSubview(valueLabel)
        labelLabel.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(Layout.labelColumnWidth)
        }
        valueLabel.snp.makeConstraints { make in
            make.left.equalTo(labelLabel.snp.right).offset(8)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
        return row
    }

    private func makeRoomIDRow() -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }

        let labelLabel = makeRowLabel(.roomID)

        let valueLabel = UILabel()
        valueLabel.text = Self.formattedRoomID(roomID)
        valueLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        valueLabel.textColor = RoomColors.valueText
        valueLabel.numberOfLines = 1
        valueLabel.textAlignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail

        let copyButton = UIButton(type: .custom)
        copyButton.setImage(ResourceLoader.loadImage("room_blue_copy"), for: .normal)
        copyButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        copyButton.setContentHuggingPriority(.required, for: .horizontal)
        copyButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        copyButton.addTarget(self, action: #selector(handleCopyRoomIDTapped), for: .touchUpInside)

        row.addSubview(labelLabel)
        row.addSubview(copyButton)
        row.addSubview(valueLabel)
        labelLabel.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(Layout.labelColumnWidth)
        }
        copyButton.snp.makeConstraints { make in
            make.right.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        valueLabel.snp.makeConstraints { make in
            make.left.equalTo(labelLabel.snp.right).offset(8)
            make.centerY.equalToSuperview()
            make.right.equalTo(copyButton.snp.left).offset(-4)
        }
        return row
    }

    private func makeOriginatorRow() -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }

        let labelLabel = makeRowLabel(.originator)

        let avatarView = UIImageView()
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = Layout.originatorAvatarSize / 2
        avatarView.backgroundColor = RoomColors.g8
        setAvatar(avatarView, urlString: currentRoomInfo?.roomOwner.avatarURL ?? "")

        let nameLabel = UILabel()
        nameLabel.text = Self.displayName(for: currentRoomInfo?.roomOwner ?? RoomUser())
        nameLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        nameLabel.textColor = RoomColors.valueText
        nameLabel.numberOfLines = 1
        nameLabel.textAlignment = .right
        nameLabel.lineBreakMode = .byTruncatingTail

        row.addSubview(labelLabel)
        row.addSubview(avatarView)
        row.addSubview(nameLabel)
        labelLabel.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(Layout.labelColumnWidth)
        }
        avatarView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.originatorAvatarSize)
            make.left.greaterThanOrEqualTo(labelLabel.snp.right).offset(8)
        }
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(6)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
        return row
    }

    private func makeParticipantsRow() -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }

        let labelLabel = makeRowLabel(.participants)
        row.addSubview(labelLabel)
        labelLabel.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(Layout.labelColumnWidth)
        }

        let attendees = currentAttendees
        guard !attendees.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = .noMembers
            emptyLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
            emptyLabel.textColor = RoomColors.valueText
            emptyLabel.textAlignment = .right
            row.addSubview(emptyLabel)
            emptyLabel.snp.makeConstraints { make in
                make.left.equalTo(labelLabel.snp.right).offset(8)
                make.centerY.equalToSuperview()
                make.right.equalToSuperview()
            }
            return row
        }

        row.isUserInteractionEnabled = true

        let chevronView = UIImageView(image: ResourceLoader.loadImage("room_right_arrow2"))
        chevronView.contentMode = .scaleAspectFit

        let countLabel = UILabel()
        countLabel.text = "roomkit_format_add_attendee".localizedReplace("\(attendees.count)")
        countLabel.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        countLabel.textColor = RoomColors.valueText

        let avatarStack = makeAvatarStack(for: attendees)

        row.addSubview(chevronView)
        row.addSubview(countLabel)
        row.addSubview(avatarStack)

        chevronView.snp.makeConstraints { make in
            make.right.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        countLabel.snp.makeConstraints { make in
            make.right.equalTo(chevronView.snp.left).offset(-4)
            make.centerY.equalToSuperview()
        }
        avatarStack.snp.makeConstraints { make in
            make.right.equalTo(countLabel.snp.left).offset(-8)
            make.centerY.equalToSuperview()
            make.left.greaterThanOrEqualTo(labelLabel.snp.right).offset(8)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleParticipantsTapped))
        row.addGestureRecognizer(tap)
        return row
    }

    private func makeAvatarStack(for users: [RoomUser]) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.avatarSpacing
        stack.alignment = .center
        for user in users.prefix(Layout.maxAvatars) {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = Layout.avatarSize / 2
            iv.snp.makeConstraints { $0.width.height.equalTo(Layout.avatarSize) }
            setAvatar(iv, urlString: user.avatarURL)
            stack.addArrangedSubview(iv)
        }
        return stack
    }

    private func setAvatar(_ imageView: UIImageView, urlString: String) {
        if !urlString.isEmpty, let url = URL(string: urlString) {
            imageView.kf.setImage(with: url, placeholder: ResourceLoader.loadImage("avatar_placeholder"))
        } else {
            imageView.image = ResourceLoader.loadImage("avatar_placeholder")
        }
    }

    // MARK: - Action rows

    private func buildActionRows() {
        actionsStackView.addArrangedSubview(
            makeActionRow(title: .enterRoomAction,
                          titleColor: RoomColors.b1,
                          background: RoomColors.g8,
                          action: #selector(handleEnterRoomTapped)))
        actionsStackView.addArrangedSubview(
            makeActionRow(title: .inviteMember,
                          titleColor: RoomColors.b1,
                          background: RoomColors.g8,
                          action: #selector(handleInviteMemberTapped)))
        if canManageRoom {
            addCancelRoomRow()
        }
    }

    private func rebuildActionRows() {
        for view in actionsStackView.arrangedSubviews {
            actionsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buildActionRows()
    }

    private func addCancelRoomRow() {
        let destructiveRed = UIColor(red: 0xED / 255.0,
                                     green: 0x41 / 255.0,
                                     blue: 0x4D / 255.0,
                                     alpha: 1.0)
        actionsStackView.addArrangedSubview(
            makeActionRow(title: .cancelRoom,
                          titleColor: destructiveRed,
                          background: destructiveRed.withAlphaComponent(0.1),
                          action: #selector(handleCancelRoomTapped)))
    }

    private func makeActionRow(title: String,
                               titleColor: UIColor,
                               background: UIColor,
                               action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        button.backgroundColor = background
        button.layer.cornerRadius = Layout.actionRowCornerRadius
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { $0.height.equalTo(Layout.actionRowHeight) }
        return button
    }

    // MARK: - Actions

    @objc private func handleBack() {
        routerContext?.pop(animated: true)
    }

    @objc private func handleModifyTapped() {
        guard let info = currentRoomInfo else { return }
        onModify?(info)
    }

    @objc private func handleEnterRoomTapped() {
        guard let info = currentRoomInfo else { return }
        onEnterRoom?(info)
    }

    @objc private func handleInviteMemberTapped() {
        guard let info = currentRoomInfo else { return }
        let panel = RoomScheduleInfoPanel(roomInfo: RoomScheduleInfo(from: info),
                                          timeZone: timeZone,
                                          mode: .inviteMembers)
        panel.show(in: self, animated: true)
    }

    @objc private func handleCopyRoomIDTapped() {
        UIPasteboard.general.string = roomID
        showAtomicToast(text: .roomIDCopied, style: .info, position: .center)
    }

    @objc private func handleParticipantsTapped() {
        let contacts = currentAttendees.map { user -> ContactInfo in
            var info = ContactInfo(userID: user.userID)
            info.nickname = user.userName
            info.avatarURL = user.avatarURL
            return info
        }
        let panel = RoomSelectedAttendeesPanel(members: contacts, allowsRemoval: false)
        panel.show(in: self, animated: true)
    }

    @objc private func handleCancelRoomTapped() {
        let cancelButton = AlertButtonConfig(text: .doNotCancel, type: .grey) { view in
            view.dismiss()
        }
        let confirmButton = AlertButtonConfig(text: .cancelRoom, type: .red, isBold: true) { [weak self] view in
            view.dismiss()
            self?.performCancelRoom()
        }
        let config = AlertViewConfig(title: .cancelScheduledRoomTitle,
                                     content: .cancelScheduledRoomMessage,
                                     cancelButton: cancelButton,
                                     confirmButton: confirmButton)
        AtomicAlertView(config: config).show()
    }

    private func performCancelRoom() {
        RoomStore.shared.cancelScheduledRoom(roomID: roomID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    if let info = self.currentRoomInfo {
                        self.onCancelled?(info)
                    }
                    self.routerContext?.pop(animated: true)
                case .failure:
                    self.showAtomicToast(text: .cancelRoomFailed, style: .warning, position: .center)
                }
            }
        }
    }

    // MARK: - Formatting
    private func formattedStartTime() -> String {
        let startSeconds = currentRoomInfo?.scheduledStartTime ?? 0
        let start = Date.date(fromSeconds: startSeconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: start)
    }

    private func formattedDuration() -> String {
        let info = currentRoomInfo
        let totalMinutes = max(0, ((info?.scheduledEndTime ?? 0) - (info?.scheduledStartTime ?? 0)) / 60)
        return String.roomDurationDisplayString(hours: totalMinutes / 60,
                                                minutes: totalMinutes % 60)
    }

    private static func formattedRoomID(_ raw: String) -> String {
        guard raw.count == 9, raw.allSatisfy({ $0.isNumber }) else { return raw }
        let first = raw.prefix(3)
        let mid = raw.dropFirst(3).prefix(3)
        let last = raw.suffix(3)
        return "\(first) \(mid) \(last)"
    }

    private static func displayName(for user: RoomUser) -> String {
        return user.userName.isEmpty ? user.userID : user.userName
    }
}

// MARK: - Localized strings

private extension String {
    static let roomDetail = "roomkit_scheduled_room_detail".localized
    static let modify = "roomkit_scheduled_modify".localized
    static let roomName = "roomkit_room_name".localized
    static let roomID = "roomkit_room_id".localized
    static let startTime = "roomkit_scheduled_start_time".localized
    static let roomDuration = "roomkit_scheduled_duration".localized
    static let originator = "roomkit_scheduled_room_host".localized
    static let participants = "roomkit_scheduled_attendees".localized
    static let enterRoomAction = "roomkit_scheduled_enter_room".localized
    static let inviteMember = "roomkit_scheduled_invite_members".localized
    static let cancelRoom = "roomkit_scheduled_cancel_room".localized
    static let cancelRoomFailed = "roomkit_scheduled_cancel_failed".localized
    static let cancelScheduledRoomTitle = "roomkit_scheduled_cancel_title".localized
    static let cancelScheduledRoomMessage = "roomkit_scheduled_cancel_message".localized
    static let doNotCancel = "roomkit_scheduled_cancel_not".localized
    static let noMembers = "roomkit_no_participants_yet".localized
    static let roomIDCopied = "roomkit_toast_room_id_copied".localized
    static let roomClosed = "roomkit_toast_room_closed".localized
}
