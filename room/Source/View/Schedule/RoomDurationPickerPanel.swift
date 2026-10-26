//
//  RoomDurationPickerPanel.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicX

/// Bottom-sliding panel used to pick a room duration in hours + minutes.
class RoomDurationPickerPanel: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - Public API
    var onConfirm: ((Int) -> Void)?
    
    // MARK: - BasePanel
    weak var parentView: UIView?
    weak var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    var panelHeight: CGFloat {
        return 300 + WindowUtils.bottomSafeHeight
    }
    
    // MARK: - Constants
    private enum Column: Int {
        case hour = 0
        case minute = 1
    }
    private let hourValues: [Int] = Array(0...23)
    private let minuteValues: [Int] = stride(from: 0, through: 55, by: 5).map { $0 }
    
    // MARK: - Config
    private let initialMinutes: Int
    
    // MARK: - UI
    private lazy var headerContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "roomkit_scheduled_duration".localized
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
    
    private lazy var pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        return picker
    }()
    
    // MARK: - Init
    init(initialMinutes: Int) {
        self.initialMinutes = max(0, initialMinutes)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setupConstraints()
        setupBindings()
        applyInitialSelection()
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
        addSubview(pickerView)
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
        pickerView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(230)
        }
    }
    
    private func setupBindings() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
    }
    
    private func applyInitialSelection() {
        let clampedHours = min(max(0, initialMinutes / 60), hourValues.count - 1)
        let rawMinutes = max(0, initialMinutes % 60)
        let minuteIndex = min(rawMinutes / 5, minuteValues.count - 1)
        pickerView.selectRow(clampedHours, inComponent: Column.hour.rawValue, animated: false)
        pickerView.selectRow(minuteIndex, inComponent: Column.minute.rawValue, animated: false)
    }
    
    // MARK: - Actions
    @objc private func handleCancel() {
        dismiss(animated: true)
    }
    
    @objc private func handleConfirm() {
        let hourIndex = pickerView.selectedRow(inComponent: Column.hour.rawValue)
        let minuteIndex = pickerView.selectedRow(inComponent: Column.minute.rawValue)
        let hours = hourValues[hourIndex]
        let minutes = minuteValues[minuteIndex]
        let total = hours * 60 + minutes
        dismiss(animated: true) { [weak self] in
            self?.onConfirm?(total)
        }
    }
}

// MARK: - UIPickerView Data Source / Delegate
extension RoomDurationPickerPanel: UIPickerViewDataSource, UIPickerViewDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Column(rawValue: component) {
        case .hour: return hourValues.count
        case .minute: return minuteValues.count
        default: return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    viewForRow row: Int,
                    forComponent component: Int,
                    reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        label.font = RoomFonts.pingFangSCFont(size: 18, weight: .regular)
        label.textColor = RoomColors.g2
        
        switch Column(rawValue: component) {
        case .hour:
            label.text = "roomkit_hour_text".localizedReplace("\(hourValues[row])")
        case .minute:
            label.text = "roomkit_minute_text".localizedReplace("\(minuteValues[row])")
        default:
            label.text = ""
        }
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 36
    }
}
