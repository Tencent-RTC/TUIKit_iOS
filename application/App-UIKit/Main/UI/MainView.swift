//
//  MainView.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import UIKit
import Kingfisher
import TUICore

protocol MainViewDelegate: NSObjectProtocol {
    func jumpProfileController()
}

class MainView: UIView {
    weak var delegate: MainViewDelegate?
    
    private lazy var iconView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.isUserInteractionEnabled = true
        imageView.image = UIImage(named: getMainLogoStr())
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private lazy var mineCenterBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        return button
    }()
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        backgroundColor = UIColor("EBEDF5")
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    private func constructViewHierarchy() {
        addSubview(iconView)
        addSubview(mineCenterBtn)
    }
    
    private func activateConstraints() {
        iconView.snp.makeConstraints { (make) in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(142.scale375Width())
            make.height.equalTo(32.scale375Height())
        }
        mineCenterBtn.snp.makeConstraints { (make) in
            make.right.centerY.equalToSuperview()
            make.width.height.equalTo(32.scale375Width())
        }
    }
    
    private func bindInteraction() {
        mineCenterBtn.addTarget(self, action: #selector(goMine(sender:)), for: .touchUpInside)
    }
    
    func updateIconImage(with image: UIImage) {
        mineCenterBtn.setBackgroundImage(image, for: .normal)
    }
    
    @objc private func goMine(sender: UIButton) {
        delegate?.jumpProfileController()
    }
}

fileprivate func getMainLogoStr() -> String {
    guard let language = TUIGlobalization.tk_localizableLanguageKey() else {
        return "main_english_logo"
    }
    if language.contains("zh-Hans") {
        return "main_simplified_chinese_logo"
    } else if language.contains("zh-Hant") {
        return "main_traditional_chinese_logo"
    } else {
        return "main_english_logo"
    }
}
