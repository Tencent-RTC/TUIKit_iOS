//
//  RoomScheduleListView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/30.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import SnapKit
import AtomicXCore
import Combine

public class RoomScheduleListView: UIView {

    // MARK: - Public API

    public var onScheduleRowTapped: ((RoomInfo) -> Void)?

    public var onEnterScheduleRoomTapped: ((RoomInfo) -> Void)?

    // MARK: - Properties

    private let roomStore: RoomStore = RoomStore.shared
    private var cancellableSet = Set<AnyCancellable>()
    private var scheduledSections: [ScheduledRoomInfoSection] = []
    private var isFetchingScheduledList = false

    // MARK: - UI Components

    private lazy var scheduleListTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.sectionHeaderHeight = UITableView.automaticDimension
        tv.estimatedSectionHeaderHeight = 40
        tv.sectionFooterHeight = 0
        tv.rowHeight = 65
        tv.estimatedRowHeight = 65
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 0
        }
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        tv.isHidden = true
        tv.dataSource = self
        tv.delegate = self
        tv.register(RoomScheduleListCell.self,
                    forCellReuseIdentifier: RoomScheduleListCell.reuseID)
        tv.register(RoomScheduleListSectionHeader.self,
                    forHeaderFooterViewReuseIdentifier: RoomScheduleListSectionHeader.reuseID)
        return tv
    }()

    private lazy var emptyScheduleContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var emptyScheduleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_no_schedule")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var emptyScheduleLabel: UILabel = {
        let label = UILabel()
        label.text = .noScheduleRoom
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g5
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStoreObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        addSubview(scheduleListTableView)
        addSubview(emptyScheduleContainerView)
        emptyScheduleContainerView.addSubview(emptyScheduleImageView)
        emptyScheduleContainerView.addSubview(emptyScheduleLabel)
    }

    private func setupConstraints() {
        scheduleListTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyScheduleContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyScheduleImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-RoomSpacing.large)
            make.width.equalTo(120)
            make.height.equalTo(79)
        }
        emptyScheduleLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyScheduleImageView.snp.bottom).offset(RoomSpacing.large)
            make.centerX.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview().offset(RoomSpacing.standard)
            make.right.lessThanOrEqualToSuperview().offset(-RoomSpacing.standard)
        }
    }

    // MARK: - Store Observers

    private func setupStoreObservers() {
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \RoomState.scheduledRoomList))
            .receive(on: RunLoop.main)
            .sink { [weak self] rooms in
                self?.updateScheduledRooms(rooms)
            }
            .store(in: &cancellableSet)

        fetchScheduledRoomList()
    }

    private func fetchScheduledRoomList() {
        guard !isFetchingScheduledList else { return }
        isFetchingScheduledList = true
        fetchScheduledRoomListPage(cursor: nil)
    }

    private func fetchScheduledRoomListPage(cursor: String?) {
        roomStore.getScheduledRoomList(cursor: cursor) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (_, nextCursor)):
                if !nextCursor.isEmpty {
                    self.fetchScheduledRoomListPage(cursor: nextCursor)
                } else {
                    self.isFetchingScheduledList = false
                }
            case .failure:
                self.isFetchingScheduledList = false
            }
        }
    }

    // MARK: - Public

    public func updateScheduledRooms(_ items: [RoomInfo]) {
        scheduledSections = Self.groupByDate(items)
        scheduleListTableView.reloadData()
        refreshScheduleVisibility()
    }

    // MARK: - Private

    private static func groupByDate(_ items: [RoomInfo]) -> [ScheduledRoomInfoSection] {
        let calendar = Calendar.current
        var buckets: [DateComponents: [RoomInfo]] = [:]
        for item in items {
            let date = Date.date(fromSeconds: item.scheduledStartTime)
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            buckets[comps, default: []].append(item)
        }
        let sortedKeys = buckets.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? Date.distantPast
            let r = calendar.date(from: rhs) ?? Date.distantPast
            return l < r
        }
        return sortedKeys.map { key in
            let dayItems = (buckets[key] ?? []).sorted { $0.scheduledStartTime < $1.scheduledStartTime }
            let date = calendar.date(from: key) ?? Date()
            return ScheduledRoomInfoSection(date: date, items: dayItems)
        }
    }

    /// Show either the table (when we have data) or the placeholder.
    private func refreshScheduleVisibility() {
        let hasItems = !scheduledSections.isEmpty
        scheduleListTableView.isHidden = !hasItems
        emptyScheduleContainerView.isHidden = hasItems
    }
}

// MARK: - Table Data / Delegate

extension RoomScheduleListView: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return scheduledSections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scheduledSections[section].items.count
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: RoomScheduleListSectionHeader.reuseID) as! RoomScheduleListSectionHeader
        header.configure(with: scheduledSections[section].date)
        return header
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RoomScheduleListCell.reuseID,
            for: indexPath) as! RoomScheduleListCell
        let item = scheduledSections[indexPath.section].items[indexPath.row]
        cell.configure(with: item) { [weak self] tapped in
            self?.onEnterScheduleRoomTapped?(tapped)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = scheduledSections[indexPath.section].items[indexPath.row]
        onScheduleRowTapped?(item)
    }
}

// MARK: - Section model

private struct ScheduledRoomInfoSection {
    let date: Date
    let items: [RoomInfo]
}

// MARK: - Section header

private class RoomScheduleListSectionHeader: UITableViewHeaderFooterView {
    static let reuseID = "RoomScheduleListSectionHeader"

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_schedule_time")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.textColor = RoomColors.g5
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        return label
    }()

    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "yyyy年MM月dd日"
        return df
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let container = UIView()
        container.backgroundColor = .clear
        contentView.addSubview(container)
        container.addSubview(iconView)
        container.addSubview(dateLabel)

        container.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.lessThanOrEqualToSuperview().offset(-RoomSpacing.standard)
            make.centerY.equalToSuperview().offset(5)
        }
        iconView.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        dateLabel.snp.makeConstraints { make in
            make.left.equalTo(iconView.snp.right).offset(4)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with date: Date) {
        dateLabel.text = Self.formatter.string(from: date)
    }
}

// MARK: - Row cell

private class RoomScheduleListCell: UITableViewCell {
    static let reuseID = "RoomScheduleListCell"

    // MARK: - UI

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g3
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let chevronView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_right_arrow2")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let timeRangeLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()

    private let separator1: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g5.withAlphaComponent(0.5)
        return view
    }()

    private let roomIDLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()

    private let separator2: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g5.withAlphaComponent(0.5)
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        return label
    }()

    private lazy var enterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(.enterRoom, for: .normal)
        button.setTitleColor(RoomColors.g3, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .medium)
        button.backgroundColor = RoomColors.g8
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        button.addTarget(self, action: #selector(handleEnterTapped), for: .touchUpInside)
        return button
    }()

    private let containerCard: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }()

    private let textContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "HH:mm"
        return df
    }()

    private var currentItem: RoomInfo?
    private var onEnterTapped: ((RoomInfo) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(containerCard)
        containerCard.addSubview(textContainerView)
        textContainerView.addSubview(nameLabel)
        textContainerView.addSubview(chevronView)
        textContainerView.addSubview(timeRangeLabel)
        textContainerView.addSubview(separator1)
        textContainerView.addSubview(roomIDLabel)
        textContainerView.addSubview(separator2)
        textContainerView.addSubview(statusLabel)
        containerCard.addSubview(enterButton)

        containerCard.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
            make.top.bottom.equalToSuperview()
        }
        textContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalTo(enterButton)
            make.right.greaterThanOrEqualTo(chevronView.snp.right)
            make.right.greaterThanOrEqualTo(statusLabel.snp.right)
            make.right.lessThanOrEqualTo(enterButton.snp.left).offset(-10)
        }
        nameLabel.snp.makeConstraints { make in
            make.left.top.equalToSuperview()
        }
        chevronView.snp.makeConstraints { make in
            make.left.equalTo(nameLabel.snp.right).offset(2)
            make.centerY.equalTo(nameLabel)
            make.width.height.equalTo(16)
        }
        timeRangeLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
            make.bottom.equalToSuperview()
        }
        separator1.snp.makeConstraints { make in
            make.left.equalTo(timeRangeLabel.snp.right).offset(8)
            make.centerY.equalTo(timeRangeLabel)
            make.width.equalTo(1)
            make.height.equalTo(10)
        }
        roomIDLabel.snp.makeConstraints { make in
            make.left.equalTo(separator1.snp.right).offset(8)
            make.centerY.equalTo(timeRangeLabel)
        }
        separator2.snp.makeConstraints { make in
            make.left.equalTo(roomIDLabel.snp.right).offset(8)
            make.centerY.equalTo(timeRangeLabel)
            make.width.equalTo(1)
            make.height.equalTo(10)
        }
        statusLabel.snp.makeConstraints { make in
            make.left.equalTo(separator2.snp.right).offset(8)
            make.centerY.equalTo(timeRangeLabel)
        }
        enterButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
            make.width.greaterThanOrEqualTo(68)
        }

        textContainerView.setContentHuggingPriority(.required, for: .horizontal)
        textContainerView.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        roomIDLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: RoomInfo,
                   onEnter: @escaping (RoomInfo) -> Void) {
        currentItem = item
        onEnterTapped = onEnter
        nameLabel.text = item.roomName
        roomIDLabel.text = Self.formattedRoomID(item.roomID)
        timeRangeLabel.text = Self.formattedTimeRange(startSeconds: item.scheduledStartTime,
                                                     endSeconds: item.scheduledEndTime)
        switch item.roomStatus {
        case .running:
            statusLabel.text = .statusRunning
            statusLabel.textColor = RoomColors.b1
        case .scheduled:
            break
        }
    }

    @objc private func handleEnterTapped() {
        guard let item = currentItem else { return }
        onEnterTapped?(item)
    }

    private static func formattedTimeRange(startSeconds: Int, endSeconds: Int) -> String {
        let start = Date.date(fromSeconds: startSeconds)
        let end = Date.date(fromSeconds: endSeconds)
        return "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }

    private static func formattedRoomID(_ raw: String) -> String {
        guard raw.count == 6, raw.allSatisfy({ $0.isNumber }) else { return raw }
        let first = raw.prefix(3)
        let last = raw.suffix(3)
        return "\(first) \(last)"
    }
}

// MARK: - Localized strings

private extension String {
    static let noScheduleRoom = "roomkit_no_scheduled_room".localized
    static let enterRoom = "roomkit_scheduled_room_btn_enter".localized
    static let statusRunning = "roomkit_scheduled_status_running".localized
}
