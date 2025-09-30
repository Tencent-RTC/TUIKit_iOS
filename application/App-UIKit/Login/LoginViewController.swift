//
//  LoginViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import Foundation
import SnapKit
import TUICore
import RTCRoomEngine
import RTCCommon
import TIMCommon
import TUICallKit_Swift

class LoginViewController: UIViewController {
    private let userIdKey = "UserIdKey"
    private let loading = UIActivityIndicatorView()
    private let rootView = LoginView()
    private var isTestEnvironment = false
    private var nickName: String = ""
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationController?.navigationBar.barTintColor = .white
        constructViewHierarchy()
        activateConstraints()
        rootView.delegate = self
        autoLogin()
    }

    private func constructViewHierarchy() {
        view.addSubview(rootView)
    }
    
    private func activateConstraints() {
        rootView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func login(userId: String) {
        loading.startAnimating()
        TUILogin.login(Int32(SDKAPPID),
                       userID: userId,
                       userSig: GenerateTestUserSig.genTestUserSig(identifier: userId)) { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.set(userId, forKey: self.userIdKey)
            V2TIMManager.sharedInstance()?.getUsersInfo([userId], succ: { [weak self] (infos) in
                guard let self = self else { return }
                if let info = infos?.first {
                    nickName = info.nickName ?? ""
                    let avatar = info.faceURL ?? DEFAULT_AVATAR
                    TUICallKit.createInstance().setSelfInfo(nickname: nickName,avatar: avatar,
                               succ: {},
                               fail: { _, _ in })
                }
                self.loading.stopAnimating()
                self.loginSucc()
            }, fail: { [weak self] (code, error) in
                guard let self = self else { return }
                self.loading.stopAnimating()
                self.loginSucc()
            })
            
        } fail: { [weak self] code, errorDes in
            guard let self = self else { return }
            self.loading.stopAnimating()
            TUITool.makeToast("Login failed, code: \(code), error: \(errorDes ?? "nil")")
        }
    }
    
    private func loginSucc() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        if nickName.count == 0 {
            let vc = RegisterViewController()
            navigationController?.pushViewController(vc, animated: true)
        } else {
            self.view.makeToast("Logged In".localized)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appDelegate?.showMainViewController()
            }
        }
    }
    
    private func autoLogin() {
        if let userId = UserDefaults.standard.string(forKey: userIdKey), !userId.isEmpty {
            rootView.userIdTextField.text = userId
            login(userId: userId)
        } else {
            rootView.userIdTextField.text = UserDefaults.standard.string(forKey: userIdKey)
        }
    }
}

extension LoginViewController: LoginViewDelegate {
    func testModeSwitchChanged(isOn: Bool) {
        isTestEnvironment = isOn
    }
    
    func loginDelegate(userId: String) {
        switchTestEnvironment(enableTest: isTestEnvironment)
        login(userId: userId)
    }
    
    private func switchTestEnvironment(enableTest: Bool) {
        var jsonObject = [String: Any]()
        jsonObject["api"] = "setTestEnvironment"
        var params = [String: Any]()
        params["enableRoomTestEnv"] = enableTest
        jsonObject["params"] = params
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonString) { _ in }
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "setTestEnvironment", 
            param: NSNumber(value: enableTest)
        ) { _ in } fail: { _, _ in }
    }
}

extension LoginViewController: LanguageSelectViewControllerDelegate {
    func onSelectLanguage(cellModel: LanguageSelectCellModel) {
        let languageVC = LanguageSelectViewController()
        languageVC.delegate = self

        if let nav = self.navigationController {
            nav.pushViewController(languageVC, animated: true)
        } else {
            self.present(languageVC, animated: true, completion: nil)
        }
    }
}
