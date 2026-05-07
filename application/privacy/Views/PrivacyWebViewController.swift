//
//  PrivacyWebViewController.swift
//  privacy
//

import UIKit
import AtomicX
import WebKit

class PrivacyWebViewController: UIViewController {
    
    lazy var webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        webview.isOpaque = false
        webview.backgroundColor = .clear
        webview.scrollView.backgroundColor = .clear
        webview.navigationDelegate = self
        if #available(iOS 11.0, *) {
            webview.scrollView.contentInsetAdjustmentBehavior = .never
        }
        return webview
    }()
    
    let url: URL
    let titleString: String
    
    init(url: URL, title: String) {
        self.url = url
        self.titleString = title
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        configNav()
        
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        let req = URLRequest(url: url)
        webView.load(req)
    }
    
    func configNav() {
        self.title = titleString;
        navigationController?.navigationBar.titleTextAttributes =
        [NSAttributedString.Key.foregroundColor : UIColor.black,
         NSAttributedString.Key.font : ThemeStore.shared.typographyTokens.Bold18
        ]
        navigationController?.navigationBar.barTintColor = .white
        navigationController?.navigationBar.isTranslucent = false
        
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "privacy_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = .black
        navigationItem.leftBarButtonItem = item
    }
    
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            if #available(iOS 13.0, *) {
                return .darkContent
            } else {
                return .default
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        get {
            return false
        }
    }
}

extension PrivacyWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }
}
