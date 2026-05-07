//
//  UserAgreementView.swift
//  login
//

import UIKit
import WebKit
import SnapKit
import AtomicX

class UserAgreementViewController: UIViewController {
    static let UserAgreeKey = "UserAgreeKey"
    
    typealias Completion = () -> Void
    var completion: Completion? = nil
    
    var topPadding: CGFloat = {
        if #available(iOS 11.0, *) {
            return UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0
        }
        return 0
    }()
    
    var bottomPadding: CGFloat = {
        if #available(iOS 11.0, *) {
            return UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        }
        return 0
    }()
    
    static func isAgree() -> Bool {
        if let isAgree = UserDefaults.standard.object(forKey: UserAgreeKey) as? Bool {
            return isAgree
        }
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    deinit {
        debugPrint("deinit \(self)")
    }
}

// MARK: - UI Setup
extension UserAgreementViewController {
    func setupUI() {
        title = LoginLocalize("V2.Live.LinkMicNew.termsandconditions")
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        let htmlPath = Bundle.loginResources.path(forResource: "UserProtocol", ofType: "html")
        var htmlContent = ""
        do {
            htmlContent = try String(contentsOfFile: htmlPath ?? "")
        } catch {
        }
        
        let lineView1 = UIView()
        lineView1.backgroundColor = UIColor.gray
        view.addSubview(lineView1)
        lineView1.snp.remakeConstraints { (make) in
            make.width.equalTo(view)
            make.height.equalTo(0.5)
            make.leading.equalTo(0)
            make.bottom.equalTo(view).offset(-50 - bottomPadding)
        }
        
        let lineView2 = UIView()
        lineView2.backgroundColor = UIColor.gray
        view.addSubview(lineView2)
        lineView2.snp.remakeConstraints { (make) in
            make.width.equalTo(0.5)
            make.height.equalTo(49)
            make.leading.equalTo(view.snp.trailing).dividedBy(2)
            make.top.equalTo(lineView1.snp.bottom)
        }
        
        let agreeBtn = UIButton()
        agreeBtn.setTitle(LoginLocalize("V2.Live.LinkMicNew.agree"), for: .normal)
        agreeBtn.setTitleColor(ThemeStore.shared.colorTokens.textColorLink, for: .normal)
        view.addSubview(agreeBtn)
        agreeBtn.snp.remakeConstraints { (make) in
            make.width.equalTo(view).dividedBy(2)
            make.height.equalTo(49)
            make.leading.equalTo(view.snp.trailing).dividedBy(2)
            make.top.equalTo(lineView1.snp.bottom)
        }
        agreeBtn.addTarget(self, action: #selector(agreeBtnTouchEvent(sender:)), for: .touchUpInside)
        
        let unAgreeBtn = UIButton()
        unAgreeBtn.setTitle(LoginLocalize("V2.Live.LinkMicNew.disagree"), for: .normal)
        unAgreeBtn.setTitleColor(ThemeStore.shared.colorTokens.textColorLink, for: .normal)
        view.addSubview(unAgreeBtn)
        unAgreeBtn.snp.remakeConstraints { (make) in
            make.width.equalTo(view).dividedBy(2)
            make.height.equalTo(49)
            make.leading.equalTo(0)
            make.top.equalTo(lineView1.snp.bottom)
        }
        unAgreeBtn.addTarget(self, action: #selector(unAgreeBtnTouchEvent(sender:)), for: .touchUpInside)
        
        let webView = WKWebView()
        webView.loadHTMLString(htmlContent, baseURL: Bundle.main.bundleURL)
        view.addSubview(webView)
        webView.snp.remakeConstraints { (make) in
            make.top.equalTo(topPadding)
            make.bottom.equalTo(lineView1.snp.top)
            make.leading.equalTo(0)
            make.width.equalTo(view)
        }
    }
    
    func agree() {
        UserDefaults.standard.set(true, forKey: UserAgreementViewController.UserAgreeKey)
        UserDefaults.standard.synchronize()
        self.dismiss(animated: true, completion: completion)
    }
    
    func unAgree() {
        UserDefaults.standard.set(false, forKey: UserAgreementViewController.UserAgreeKey)
        UserDefaults.standard.synchronize()
        self.dismiss(animated: true, completion: completion)
    }
}

// MARK: - UIButton TouchEvent
extension UserAgreementViewController {
    @objc private func unAgreeBtnTouchEvent(sender: UIButton) {
        unAgree()
    }
    
    @objc private func agreeBtnTouchEvent(sender: UIButton) {
        agree()
    }
}
