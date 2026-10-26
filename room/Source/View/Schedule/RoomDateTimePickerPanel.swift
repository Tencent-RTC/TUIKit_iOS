//
//  RoomDateTimePickerPanel.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicX

class RoomDateTimePickerPanel: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - Public API
    var onConfirm: ((Date) -> Void)?
    
    // MARK: - BasePanel
    weak var parentView: UIView?
    weak var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    var panelHeight: CGFloat {
        return 300 + WindowUtils.bottomSafeHeight
    }
    
    // MARK: - Config
    private let initialDate: Date
    private let timeZone: TimeZone
    
    // MARK: - UI
    private lazy var headerContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "roomkit_scheduled_start_time".localized
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g2
        label.textAlignment = .center
        return label
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_schedule_wrong"), for: .normal)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_schedule_right"), for: .normal)
        return button
    }()
    
    private lazy var separator: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        return view
    }()
    
    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.minuteInterval = 5
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.timeZone = timeZone
        picker.minimumDate = Self.earliestAllowedDate()
        picker.date = initialDate
        return picker
    }()
    
    // MARK: - Init
    init(initialDate: Date, timeZone: TimeZone) {
        self.initialDate = initialDate
        self.timeZone = timeZone
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setupConstraints()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true
        
        addSubview(headerContainer)
        headerContainer.addSubview(cancelButton)
        headerContainer.addSubview(titleLabel)
        headerContainer.addSubview(confirmButton)
        addSubview(separator)
        addSubview(datePicker)
    }
    
    private func setupConstraints() {
        headerContainer.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(48)
        }
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        separator.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(headerContainer.snp.bottom)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        datePicker.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(230)
        }
    }
    
    private func setupBindings() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func handleCancel() {
        dismiss(animated: true)
    }
    
    @objc private func handleConfirm() {
        let earliest = Self.earliestAllowedDate()
        let picked = datePicker.date < earliest ? earliest : datePicker.date
        dismiss(animated: true) { [weak self] in
            self?.onConfirm?(picked)
        }
    }
    
    // MARK: - Helpers
    private static func earliestAllowedDate() -> Date {
        return Date.roundedUpToNextFiveMinutes(from: Date())
    }
}
