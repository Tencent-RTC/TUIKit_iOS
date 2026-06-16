//
//  LoginHeaderView.swift
//  login
//
//  登录页公共头部（背景图 + Logo + 语言切换按钮）
//  从旧版 TRTCLoginRootView 提取，保持原有尺寸和位置
//

import TUICore
import UIKit

class LoginHeaderView: UIView {
    var onHiddenEntryTriggered: (() -> Void)?

    lazy var bgView: UIImageView = {
        let imageView = UIImageView(image: UIImage.loginImage(named: "login_bg"))
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    lazy var logoView: UIImageView = {
        let imageView = UIImageView(image: UIImage.loginImage(named: getMainLogoStr()))
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    @available(*, unavailable)
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
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hiddenEntryTapped))
        tapGesture.numberOfTapsRequired = 5
        tapGesture.numberOfTouchesRequired = 1
        logoView.addGestureRecognizer(tapGesture)
    }

    @objc private func hiddenEntryTapped() {
        onHiddenEntryTriggered?()
    }
    
    /// 刷新 logo（语言切换后调用）
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
