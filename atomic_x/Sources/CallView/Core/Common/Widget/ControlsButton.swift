//
//  ControlsButton.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/8.
//

import Foundation
import UIKit
import SnapKit

typealias ControlsButtonActionCallback = (_ sender: UIButton) -> Void

class ControlsButton: UIView {
    // MARK: Init
    private init(frame: CGRect, imageSize: CGSize) {
        self.imageSize = imageSize
        super.init(frame: frame)
        backgroundColor = UIColor.clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    private var buttonActionCallback: ControlsButtonActionCallback?
    private var imageSize: CGSize
    
    let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: CGRect.zero)
        titleLabel.font = UIFont.systemFont(ofSize: 12.0)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        return titleLabel
    }()
    
    let button: UIButton = {
        let button = UIButton(type: .system)
        return button
    }()
        
    // MARK: UI Specification Processing
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
}

// MARK: Layout
extension ControlsButton {
    private func constructViewHierarchy() {
        addSubview(button)
        addSubview(titleLabel)
    }
    
    private func activateConstraints() {
        button.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(imageSize.width)
            make.height.equalTo(imageSize.height)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(button.snp.bottom).offset(10)
            make.width.equalTo(100.scale375Width())
        }
    }
    
    static func create(title: String?, titleColor: UIColor?, image: UIImage?, imageSize: CGSize, buttonAction: @escaping ControlsButtonActionCallback) -> ControlsButton {
        let controlButton = ControlsButton(frame: CGRect.zero, imageSize: imageSize)
        controlButton.titleLabel.text = title
        controlButton.titleLabel.textColor = titleColor
        controlButton.button.setBackgroundImage(image, for: .normal)
        controlButton.buttonActionCallback = buttonAction
        return controlButton
    }

    func updateImage(image: UIImage) {
        button.setBackgroundImage(image, for: .normal)
    }
    
    func updateImageSize(size: CGSize) {
        imageSize = size
        button.snp.updateConstraints { make in
            make.width.equalTo(size.width)
            make.height.equalTo(size.height)
        }
    }
    
    func updateTitle(title: String?) {
        titleLabel.text = title
    }
    
    func updateTitleColor(titleColor: UIColor) {
        titleLabel.textColor = titleColor
    }
}

// MARK: Action
extension ControlsButton {
    private func bindInteraction() {
        button.addTarget(self, action: #selector(buttonActionEvent(sender: )), for: .touchUpInside)
    }

    @objc func buttonActionEvent(sender: UIButton) {
        guard let buttonActionCallback = buttonActionCallback else { return }
        buttonActionCallback(sender)
    }
    
}
