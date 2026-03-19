//
//  JoinChorusButton.swift
//  Pods
//
//  Created by joeyxyliu on 2026/1/12.
//

import UIKit
import SnapKit

class JoinChorusButton: UIControl {

    override var isSelected: Bool {
        didSet {
            titleLabel.text = isSelected ? .exitChorusText : .joinChorusText
        }
    }

    private let gradient : CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor("8157FF").cgColor,
            UIColor("00ABD6").cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.cornerRadius = 12
        return gradient
    }()
    
    private let titleLabel : UILabel = {
        let titleLabel = UILabel()
        titleLabel.text = .joinChorusText
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: 10)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byClipping
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        return titleLabel
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isHidden = true
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }

    private func constructViewHierarchy() {
        layer.cornerRadius = 12
        clipsToBounds = true
        layer.insertSublayer(gradient, at: 0)
        addSubview(titleLabel)
    }

    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(6)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().inset(6)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

fileprivate extension String {
    static var joinChorusText: String = ("karaoke_join_chorus").atomicLocalized
    static var exitChorusText: String = ("karaoke_exit_chorus").atomicLocalized
}
