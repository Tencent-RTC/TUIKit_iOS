//
//  VRUserTableHeaderView.swift
//  TUILiveKit
//
//  Created by jack on 2024/8/8.
//

import Foundation
import AtomicX

class CoHostUserTableHeaderView: UITableViewHeaderFooterView {
    static let identifier = "CoHostUserTableHeaderView"
    lazy var titleLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular14)
        }
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
