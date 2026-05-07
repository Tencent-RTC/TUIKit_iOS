//
//  CaptchaService.swift
//  login
//
//    - CaptchaManager (BusinessService)
//

import TUICore
import UIKit
import WebKit

private enum CaptchaError: Error {
    case message(String)
}

public struct CaptchaResult {
    public let appId: String
    public let ticket: String
    public let randstr: String
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    
    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

public final class CaptchaService: NSObject {
    // MARK: - Constants
    
    private static let networkDisabledTicket = "terror_1001_"
    private static let tCaptchaURL = "https://turing.captcha.qcloud.com/TCaptcha.js"
    
    // MARK: - Properties
    
    private var captchaWebAppid: NSInteger = 0
    private var verifySuccessBlock: ((_ ticket: String, _ randstr: String) -> Void)?
    private var verifyFailedBlock: ((_ message: String) -> Void)?
    private var verifyCancelBlock: (() -> Void)?
    
    private var _webView: WKWebView?
    
    deinit {
        guard let webView = _webView else { return }
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "verifySuccess")
        controller.removeScriptMessageHandler(forName: "verifyError")
        controller.removeScriptMessageHandler(forName: "verifyCancel")
    }
    
    private var webView: WKWebView {
        if let existing = _webView {
            return existing
        }
        let config = WKWebViewConfiguration()
        
        let preference = WKPreferences()
        preference.javaScriptEnabled = true
        preference.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preference
        
        let wkUserController = WKUserContentController()
        let handler = WeakScriptMessageHandler(self)
        wkUserController.add(handler, name: "verifySuccess")
        wkUserController.add(handler, name: "verifyError")
        wkUserController.add(handler, name: "verifyCancel")
        config.userContentController = wkUserController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = self
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        _webView = webView
        return webView
    }
    
    // MARK: - Public API
    
    public func verify(
        success: @escaping (CaptchaResult) -> Void,
        failed: @escaping (String) -> Void,
        cancelled: (() -> Void)? = nil
    ) {
        fetchCaptchaAppId { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let appId):
                self.captchaWebAppid = appId
                self.showVerifyWebView(
                    success: { ticket, randstr in
                        let captchaResult = CaptchaResult(
                            appId: String(appId),
                            ticket: ticket,
                            randstr: randstr
                        )
                        success(captchaResult)
                    },
                    failed: failed,
                    cancelled: cancelled
                )
            case .failure(let error):
                if case .message(let msg) = error {
                    failed(msg)
                }
            }
        }
    }
    
    private func fetchCaptchaAppId(completion: @escaping (Result<NSInteger, CaptchaError>) -> Void) {
        LoginManager.shared.getGlobalData(param: [:]) { code, errorMessage, result in
            if code == kAppLoginServiceSuccessCode {
                guard let model = result["jsonModel"] as? HttpJsonModel,
                      let captchaWebAppid = model.captchaWebAppid
                else {
                    completion(.failure(.message(LoginLocalize("LoginNetwork.ProfileManager.sendfailed"))))
                    return
                }
                completion(.success(captchaWebAppid))
            } else {
                completion(.failure(.message(errorMessage)))
            }
        }
    }
    
    private func showVerifyWebView(
        success: @escaping (_ ticket: String, _ randstr: String) -> Void,
        failed: @escaping (_ message: String) -> Void,
        cancelled: (() -> Void)? = nil
    ) {
        checkCaptchaStatus { [weak self] isAccessible in
            guard let self = self else { return }
            if isAccessible {
                self.loadVerifyWebView(success: success, failed: failed, cancelled: cancelled)
            } else {
                let ticket = "\(CaptchaService.networkDisabledTicket)\(self.captchaWebAppid)_\(Int(Date().timeIntervalSince1970))"
                let randomStr = UUID().uuidString.lowercased().prefix(11)
                success(ticket, "@\(randomStr)")
            }
        }
    }
    
    private func loadVerifyWebView(
        success: @escaping (_ ticket: String, _ randstr: String) -> Void,
        failed: @escaping (_ message: String) -> Void,
        cancelled: (() -> Void)? = nil
    ) {
        guard let parentView = findPresentingView() else {
            failed(LoginLocalize("LoginNetwork.ProfileManager.sendfailed"))
            return
        }
        
        parentView.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        guard let path = Bundle.loginResources.path(forResource: "VerifyPicture", ofType: "html") else {
            failed(LoginLocalize("LoginNetwork.ProfileManager.sendfailed"))
            return
        }
        
        verifySuccessBlock = { [weak self] ticket, randstr in
            self?.cleanupCallbacks()
            self?.webView.removeFromSuperview()
            success(ticket, randstr)
        }
        verifyFailedBlock = { [weak self] message in
            self?.cleanupCallbacks()
            self?.webView.removeFromSuperview()
            failed(message)
        }
        verifyCancelBlock = { [weak self] in
            self?.cleanupCallbacks()
            self?.webView.removeFromSuperview()
            cancelled?()
        }
        
        let req = URLRequest(url: URL(fileURLWithPath: path))
        webView.configuration.preferences.javaScriptEnabled = true
        webView.load(req)
    }
    
    private func checkCaptchaStatus(completion: @escaping (Bool) -> Void) {
        guard let captchaUrl = URL(string: CaptchaService.tCaptchaURL) else {
            completion(false)
            return
        }
        var captchaRequest = URLRequest(url: captchaUrl)
        captchaRequest.timeoutInterval = 3
        captchaRequest.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: captchaRequest) { _, _, error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
        task.resume()
    }
    
    // MARK: - Helpers
    
    private func findPresentingView() -> UIView? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let topVC = window.rootViewController?.presentedViewController ?? window.rootViewController
        {
            return topVC.view
        }
        return nil
    }
    
    private func cleanupCallbacks() {
        verifySuccessBlock = nil
        verifyFailedBlock = nil
        verifyCancelBlock = nil
    }
}

// MARK: - WKNavigationDelegate

extension CaptchaService: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js = "document.getElementsByClassName('navbar')[0].style.display='none'"
        webView.evaluateJavaScript(js)
        webView.evaluateJavaScript("callVerify('\(captchaWebAppid)');")
    }
}

// MARK: - WKScriptMessageHandler

extension CaptchaService: WKScriptMessageHandler {
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "verifySuccess":
            if let body = message.body as? String,
               let data = body.data(using: .utf8),
               let parameter = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? [String: String],
               let ticket = parameter["ticket"],
               let randstr = parameter["randstr"],
               !ticket.isEmpty, !randstr.isEmpty
            {
                verifySuccessBlock?(ticket, randstr)
            }
            webView.removeFromSuperview()
            
        case "verifyError":
            if let err = message.body as? String {
                verifyFailedBlock?(err)
            }
            webView.removeFromSuperview()
            
        case "verifyCancel":
            verifyCancelBlock?()
            webView.removeFromSuperview()
            
        default:
            break
        }
    }
}
