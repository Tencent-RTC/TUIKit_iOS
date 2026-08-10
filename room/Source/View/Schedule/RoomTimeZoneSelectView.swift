//
//  RoomTimeZoneSelectView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/29.
//  Copyright © 2026 Tencent. All rights reserved.
//
//

import UIKit
import SnapKit

public class RoomTimeZoneSelectView: UIView, BaseView {
    
    // MARK: - Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 50
        static let backButtonSize: CGFloat = 16
    }
    
    // MARK: - Public API
    public weak var routerContext: RouterContext?
    
    public var onSelected: ((String, TimeZone) -> Void)?
    
    // MARK: - Data
    private let allTimeZones: [TimeZone]
    private let selectedIdentifier: String?
    private var hasScrolledToInitialSelection: Bool = false
    
    // MARK: - UI Components
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "roomkit_scheduled_time_zone".localized
        label.textColor = RoomColors.g2
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .singleLine
        tv.separatorColor = RoomColors.g8
        tv.separatorInset = UIEdgeInsets(top: 0,
                                         left: Layout.horizontalPadding,
                                         bottom: 0,
                                         right: Layout.horizontalPadding)
        tv.tableFooterView = UIView()
        tv.rowHeight = Layout.rowHeight
        tv.dataSource = self
        tv.delegate = self
        tv.register(TimeZoneCell.self, forCellReuseIdentifier: TimeZoneCell.reuseID)
        return tv
    }()
    
    // MARK: - Initialization
    
    public init(selectedTimeZoneIdentifier: String?,
                allTimeZones: [TimeZone]) {
        self.selectedIdentifier = selectedTimeZoneIdentifier
        self.allTimeZones = allTimeZones
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
    
    public func setupViews() {
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(tableView)
    }
    
    public func setupConstraints() {
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.horizontalPadding)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(14)
            make.size.equalTo(Layout.backButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    public func setupStyles() {
        backgroundColor = .white
    }
    
    public func setupBindings() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // Scroll after the table has a valid frame; only run once.
        if !hasScrolledToInitialSelection && tableView.bounds.height > 0 {
            hasScrolledToInitialSelection = true
            scrollToSelectedIfNeeded()
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleBack() {
        routerContext?.pop(animated: true)
    }
    
    private func scrollToSelectedIfNeeded() {
        guard let id = selectedIdentifier,
              let index = allTimeZones.firstIndex(where: { $0.identifier == id }) else { return }
        tableView.scrollToRow(at: IndexPath(row: index, section: 0),
                              at: .top,
                              animated: false)
    }
}

// MARK: - Table Data / Delegate

extension RoomTimeZoneSelectView: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allTimeZones.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TimeZoneCell.reuseID,
                                                 for: indexPath) as! TimeZoneCell
        let tz = allTimeZones[indexPath.row]
        let text = RoomTimeZoneSelectViewController.displayString(for: tz)
        cell.configure(title: text, isSelected: tz.identifier == selectedIdentifier)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let tz = allTimeZones[indexPath.row]
        let display = RoomTimeZoneSelectViewController.displayString(for: tz)
        onSelected?(display, tz)
        routerContext?.pop(animated: true)
    }
}

// MARK: - Cell

private class TimeZoneCell: UITableViewCell {
    static let reuseID = "TimeZoneCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 15, weight: .regular)
        label.textColor = RoomColors.g2
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualToSuperview().offset(-16)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.textColor = isSelected ? RoomColors.b1 : RoomColors.g2
    }
}
