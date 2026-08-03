//
//  RoomScheduleInfoPanel.swift
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

public struct RoomScheduleInfo {
    public var roomID: String
    public var roomName: String
    public var roomType: RoomType
    public var scheduledStartTime: Int   // seconds since 1970
    public var scheduledEndTime: Int     // seconds since 1970
    public var password: String?

    public init(roomID: String,
                roomName: String,
                roomType: RoomType,
                scheduledStartTime: Int,
                scheduledEndTime: Int,
                password: String? = nil) {
        self.roomID = roomID
        self.roomName = roomName
        self.roomType = roomType
        self.scheduledStartTime = scheduledStartTime
        self.scheduledEndTime = scheduledEndTime
        self.password = password
    }

    public init(from roomInfo: RoomInfo) {
        self.roomID = roomInfo.roomID
        self.roomName = roomInfo.roomName
        self.roomType = roomInfo.roomType
        self.scheduledStartTime = roomInfo.scheduledStartTime
        self.scheduledEndTime = roomInfo.scheduledEndTime
        self.password = roomInfo.password
    }
}

public class RoomScheduleInfoPanel: UIView, BasePanel, PanelHeightProvider {

    // MARK: - Public API

    public var onCopyRoomInfo: ((String) -> Void)?

    // MARK: - BasePanel

    public weak var parentView: UIView?
    public weak var backgroundMaskView: PanelMaskView?

    // MARK: - PanelHeightProvider

    public var panelHeight: CGFloat {
        let passwordRowHeight: CGFloat = (roomInfo.password?.isEmpty == false) ? Layout.rowHeight : 0
        return Layout.panelContentHeight + passwordRowHeight + WindowUtils.bottomSafeHeight
    }

    // MARK: - Layout Constants

    private enum Layout {
        static let cornerRadius: CGFloat = 16
        static let horizontalInset: CGFloat = 16
        static let dragHandleTop: CGFloat = 10
        static let titleTop: CGFloat = 33
        static let titleFont: CGFloat = 18
        static let rowHeight: CGFloat = 36
        static let rowTop: CGFloat = 24
        static let labelColumnWidth: CGFloat = 66
        static let rowFontSize: CGFloat = 14
        static let copyIconSize: CGFloat = 20
        static let buttonHeight: CGFloat = 44
        static let buttonCornerRadius: CGFloat = 10
        static let buttonTop: CGFloat = 24
        static let buttonBottomInset: CGFloat = 16
        static let panelContentHeight: CGFloat = 280
    }

    // MARK: - Data

    public enum PanelMode {
        case scheduleSuccess
        case inviteMembers
    }

    private let roomInfo: RoomScheduleInfo
    private let timeZone: TimeZone
    private let titleText: String

    // MARK: - UI Components

    private lazy var dragHandleView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_drop_arrow")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = titleText
        label.textColor = RoomColors.g3
        label.font = RoomFonts.pingFangSCFont(size: Layout.titleFont, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private lazy var rowsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: makeRows())
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()

    private lazy var copyRoomInfoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(.copyRoomInfo, for: .normal)
        button.setTitleColor(RoomColors.b1, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        button.layer.cornerRadius = Layout.buttonCornerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = RoomColors.b1.cgColor
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(handleCopyRoomInfoTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    public init(roomInfo: RoomScheduleInfo,
                timeZone: TimeZone = .current,
                mode: PanelMode = .scheduleSuccess) {
        self.roomInfo = roomInfo
        self.timeZone = timeZone
        self.titleText = (mode == .inviteMembers) ? .inviteMembersTitle : .scheduleSuccessTitle
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = Layout.cornerRadius
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true

        addSubview(dragHandleView)
        addSubview(titleLabel)
        addSubview(rowsStackView)
        addSubview(copyRoomInfoButton)

        // Tap the drag handle to dismiss the panel.
        let dragTap = UITapGestureRecognizer(target: self, action: #selector(handleDragHandleTapped))
        dragHandleView.addGestureRecognizer(dragTap)
    }

    private func setupConstraints() {
        dragHandleView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.dragHandleTop)
            make.centerX.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.titleTop)
            make.left.equalToSuperview().offset(Layout.horizontalInset)
            make.right.equalToSuperview().offset(-Layout.horizontalInset)
        }
        rowsStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.rowTop)
            make.left.equalToSuperview().offset(Layout.horizontalInset)
            make.right.equalToSuperview().offset(-Layout.horizontalInset)
        }
        copyRoomInfoButton.snp.makeConstraints { make in
            make.top.equalTo(rowsStackView.snp.bottom).offset(Layout.buttonTop)
            make.left.equalToSuperview().offset(Layout.horizontalInset)
            make.right.equalToSuperview().offset(-Layout.horizontalInset)
            make.height.equalTo(Layout.buttonHeight)
            make.bottom.equalToSuperview().offset(-Layout.buttonBottomInset - WindowUtils.bottomSafeHeight)
        }
    }

    // MARK: - Rows
    private func makeRows() -> [UIView] {
        var rows: [UIView] = [
            makeRow(label: .roomName, value: roomInfo.roomName),
            makeRow(label: .roomTime, value: formattedTimeRange(includeGMT: false)),
            makeRow(label: .roomID, value: Self.formattedRoomID(roomInfo.roomID),
                    copyContent: roomInfo.roomID, copyToast: .roomIDCopied)
        ]
        if let password = roomInfo.password, !password.isEmpty {
            rows.append(makeRow(label: .roomPassword, value: password,
                                copyContent: password, copyToast: .roomPasswordCopied))
        }
        return rows
    }

    private func makeRow(label: String, value: String, copyContent: String? = nil, copyToast: String? = nil) -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }

        let labelLabel = UILabel()
        labelLabel.text = label
        labelLabel.font = RoomFonts.pingFangSCFont(size: Layout.rowFontSize, weight: .regular)
        labelLabel.textColor = RoomColors.g5
        labelLabel.setContentHuggingPriority(.required, for: .horizontal)
        labelLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = RoomFonts.pingFangSCFont(size: Layout.rowFontSize, weight: .medium)
        valueLabel.textColor = RoomColors.g3
        valueLabel.numberOfLines = 1
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addSubview(labelLabel)
        row.addSubview(valueLabel)

        labelLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(Layout.labelColumnWidth)
        }

        if let copyContent = copyContent {
            let copyButton = UIButton(type: .custom)
            copyButton.setImage(ResourceLoader.loadImage("room_blue_copy"), for: .normal)
            copyButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
            copyButton.setContentHuggingPriority(.required, for: .horizontal)
            copyButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addSubview(copyButton)
            // Value label hugs its content so the copy button sits right next
            // to it with a 4pt gap, instead of being pushed to the row's
            // trailing edge.
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)
            valueLabel.snp.makeConstraints { make in
                make.left.equalTo(labelLabel.snp.right)
                make.centerY.equalToSuperview()
            }
            copyButton.snp.makeConstraints { make in
                make.left.equalTo(valueLabel.snp.right).offset(4)
                make.centerY.equalToSuperview()
                make.size.equalTo(Layout.copyIconSize + 8)
                make.right.lessThanOrEqualToSuperview()
            }
            copyButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.copyToPasteboard(copyContent)
                if let toast = copyToast {
                    self.showToast(text: toast)
                }
            }, for: .touchUpInside)
        } else {
            valueLabel.snp.makeConstraints { make in
                make.left.equalTo(labelLabel.snp.right)
                make.centerY.equalToSuperview()
                make.right.lessThanOrEqualToSuperview()
            }
        }

        return row
    }

    // MARK: - Actions

    @objc private func handleDragHandleTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleCopyRoomInfoTapped() {
        copyToPasteboard(formattedCopyContent())
        showCopySuccessToast()
    }

    private func copyToPasteboard(_ content: String) {
        UIPasteboard.general.string = content
        onCopyRoomInfo?(content)
    }

    private func showCopySuccessToast() {
        showToast(text: .copyRoomInfoSuccess)
    }

    private func showToast(text: String) {
        let host = parentView ?? self
        host.showAtomicToast(text: text, style: .info, position: .center)
    }

    // MARK: - Formatting helpers
    private func formattedTimeRange(includeGMT: Bool) -> String {
        let start = Date.date(fromSeconds: roomInfo.scheduledStartTime)
        let end = Date.date(fromSeconds: roomInfo.scheduledEndTime)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy年MM月dd日"
        dayFormatter.timeZone = timeZone
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = timeZone
        let base = "\(dayFormatter.string(from: start)) \(timeFormatter.string(from: start))-\(timeFormatter.string(from: end))"
        return includeGMT ? "\(base) (\(gmtOffsetString()))" : base
    }

    private func gmtOffsetString() -> String {
        let seconds = timeZone.secondsFromGMT()
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
    }

    private static func formattedRoomID(_ raw: String) -> String {
        guard !raw.isEmpty, raw.allSatisfy({ $0.isNumber }) else { return raw }
        var chunks: [String] = []
        var index = raw.startIndex
        while index < raw.endIndex {
            let end = raw.index(index, offsetBy: 3, limitedBy: raw.endIndex) ?? raw.endIndex
            chunks.append(String(raw[index..<end]))
            index = end
        }
        return chunks.joined(separator: " ")
    }
    
    private func formattedCopyContent() -> String {
        let inviter = LoginStore.shared.state.value.loginUserInfo?.nickname ?? ""
        let timeLine = formattedTimeRange(includeGMT: false)
        var content = """
\("roomkit_format_invite_to_conference".localizedReplace(inviter))
\(String.roomTopic)：\(roomInfo.roomName)
\(String.roomTime)：\(timeLine)
\(String.roomID)：\(roomInfo.roomID)
"""
        if let password = roomInfo.password, !password.isEmpty {
            content += "\n\(String.roomPassword)：\(password)"
        }
        return content
    }
}

// MARK: - Localized strings

private extension String {
    static let scheduleSuccessTitle = "roomkit_schedule_success_and_invite_text".localized
    static let inviteMembersTitle = "roomkit_scheduled_invite_members".localized
    static let copyRoomInfo = "roomkit_copy_room_info".localized
    static let copyRoomInfoSuccess = "roomkit_toast_room_info_copied".localized
    static let roomName = "roomkit_room_name".localized
    static let roomTopic = "roomkit_scheduled_room_name".localized
    static let roomTime = "roomkit_room_time".localized
    static let roomID = "roomkit_room_id".localized
    static let roomPassword = "roomkit_room_password_title".localized
    static let roomIDCopied = "roomkit_toast_room_id_copied".localized
    static let roomPasswordCopied = "roomkit_toast_room_password_copied".localized
}
