//
//  LoginHeaderView.swift
//  login
//

import UIKit
import TUICore

class LoginHeaderView: UIView {
    
    lazy var bgView: UIImageView = {
        let imageView = UIImageView(image: UIImage.loginImage(named: "login_bg"))
        return imageView
    }()
    
    lazy var logoView: UIImageView = {
        let imageView = UIImageView(image: UIImage.loginImage(named: getMainLogoStr()))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }
    
    func constructViewHierarchy() {
        addSubview(bgView)
        bgView.addSubview(logoView)
    }
    
    func activateConstraints() {
        bgView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(200)
        }
        logoView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(48)
            make.width.equalTo(213)
        }
    }
    
    func bindInteraction() {
        
    }
    
    func refreshLogo() {
        logoView.image = UIImage.loginImage(named: getMainLogoStr())
    }
    
    private func getMainLogoStr() -> String {
        guard let language = TUIGlobalization.getPreferredLanguage() else {
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
}
