//
//  VRUserTableHeaderView.swift
//  TUILiveKit
//
//  Created by jack on 2024/8/8.
//

import Foundation

class VRCoHostUserTableHeaderView: UITableViewHeaderFooterView {
    static let identifier = "VRCoHostUserTableHeaderView"
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .cancelTextColor
        label.font = .customFont(ofSize: 14, weight: .regular)
        return label
    }()
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
    
    func constructViewHierarchy() {
        contentView.addSubview(titleLabel)
    }
    
    func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16.scale375())
            make.trailing.lessThanOrEqualToSuperview().offset(-16.scale375())
        }
    }
}
