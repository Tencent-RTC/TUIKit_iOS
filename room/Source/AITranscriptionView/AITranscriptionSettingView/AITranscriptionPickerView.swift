//
//  AITranscriptionPickerView.swift
//  AITranscriptionView
//
//  Created by adamsfliu on 2026/3/12.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit

// MARK: - Data Model

/// Single picker option item.
public class AITranscriptionPickerItem {
    public let title: String
    public var isSelected: Bool
    
    public init(title: String, isSelected: Bool = false) {
        self.title = title
        self.isSelected = isSelected
    }
}

// MARK: - AITranscriptionPickerView

/// Bottom sheet single-selection picker with mask overlay and slide animation.
public class AITranscriptionPickerView: UIView {
    
    // MARK: - Constants
    
    private static let titleHeight: CGFloat = 56
    private static let itemHeight: CGFloat = 56
    private static let cellReuseId = "AITranscriptionPickerCell"
    private static let maxHeightRatio: CGFloat = 0.7
    
    // MARK: - Properties
    
    private let titleText: String
    private var items: [AITranscriptionPickerItem]
    private var onSelect: ((Int, AITranscriptionPickerItem) -> Void)?
    
    // MARK: - UI Elements
    
    private let maskLayer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.alpha = 0
        return view
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.cardBackground
        view.layer.cornerRadius = RoomCornerRadius.large
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 13, weight: .regular)
        label.textColor = RoomColors.secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private let titleSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.separator
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = RoomColors.cardBackground
        tv.separatorStyle = .none
        tv.rowHeight = Self.itemHeight
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseId)
        tv.showsVerticalScrollIndicator = false
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 0
        }
        return tv
    }()
    
    // MARK: - Computed
    
    private var panelHeight: CGFloat {
        let totalItemsHeight = CGFloat(items.count) * Self.itemHeight
        let safeAreaBottom = Self.bottomSafeHeight
        let naturalHeight = Self.titleHeight + totalItemsHeight + safeAreaBottom
        let maxHeight = UIScreen.main.bounds.height * Self.maxHeightRatio
        return min(naturalHeight, maxHeight)
    }
    
    private var tableViewHeight: CGFloat {
        return panelHeight - Self.titleHeight - Self.bottomSafeHeight
    }
    
    private static var bottomSafeHeight: CGFloat {
        if #available(iOS 13.0, *) {
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
        } else {
            return UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        }
    }
    
    // MARK: - Initialization
    
    public init(title: String,
                items: [AITranscriptionPickerItem],
                onSelect: ((Int, AITranscriptionPickerItem) -> Void)? = nil) {
        self.titleText = title
        self.items = items
        self.onSelect = onSelect
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(maskLayer)
        addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(titleSeparator)
        contentView.addSubview(tableView)
        
        titleLabel.text = titleText
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(maskTapped))
        maskLayer.addGestureRecognizer(tapGesture)
        
        maskLayer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(panelHeight)
            make.top.equalTo(snp.bottom)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.titleHeight)
        }
        
        titleSeparator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleSeparator.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-Self.bottomSafeHeight)
        }
    }
    
    // MARK: - Show / Dismiss
    
    public func show(in parent: UIView, animated: Bool) {
        frame = parent.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addSubview(self)
        
        layoutIfNeeded()
        
        contentView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(panelHeight)
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.maskLayer.alpha = 1
                self.layoutIfNeeded()
            }
        } else {
            maskLayer.alpha = 1
            layoutIfNeeded()
        }
        
        scrollToSelectedItem()
    }
    
    public func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        contentView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(panelHeight)
            make.top.equalTo(snp.bottom)
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                self.maskLayer.alpha = 0
                self.layoutIfNeeded()
            }, completion: { _ in
                self.removeFromSuperview()
                completion?()
            })
        } else {
            removeFromSuperview()
            completion?()
        }
    }
    
    // MARK: - Actions
    
    @objc private func maskTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Helpers
    
    private func scrollToSelectedItem() {
        guard let selectedIndex = items.firstIndex(where: { $0.isSelected }) else { return }
        let indexPath = IndexPath(row: selectedIndex, section: 0)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
    }
}

// MARK: - UITableViewDataSource

extension AITranscriptionPickerView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseId, for: indexPath)
        let item = items[indexPath.row]
        
        cell.textLabel?.text = item.title
        cell.textLabel?.font = RoomFonts.pingFangSCFont(size: 17, weight: .regular)
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.textColor = item.isSelected ? RoomColors.tintBlue : .black
        cell.backgroundColor = RoomColors.cardBackground
        cell.selectionStyle = .none
        
        let separatorTag = 9999
        cell.contentView.viewWithTag(separatorTag)?.removeFromSuperview()
        if indexPath.row < items.count - 1 {
            let separator = UIView()
            separator.tag = separatorTag
            separator.backgroundColor = RoomColors.separator
            cell.contentView.addSubview(separator)
            separator.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview()
                make.bottom.equalToSuperview()
                make.height.equalTo(0.5)
            }
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AITranscriptionPickerView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItem = items[indexPath.row]
        
        for item in items {
            item.isSelected = false
        }
        selectedItem.isSelected = true
        
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(indexPath.row, selectedItem)
        }
    }
}
