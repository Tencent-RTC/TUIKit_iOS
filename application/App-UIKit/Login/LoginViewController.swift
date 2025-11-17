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
import TUICallKit_Swift
import AtomicXCore
import Combine

class LoginViewController: UIViewController {
    private let userIdKey = "UserIdKey"
    private let loading = UIActivityIndicatorView()
    private let rootView = LoginView()
    private var isTestEnvironment = false
    private var nickName: String = ""
    private var cancelableSet: Set<AnyCancellable> = []

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
        LoginStore.shared.login(sdkAppID: Int32(SDKAPPID), userID: userId, userSig: GenerateTestUserSig.genTestUserSig(identifier: userId)) { [weak self] result in
            guard let self = self else { return }
            loading.stopAnimating()
            switch result {
            case .success():
                UserDefaults.standard.set(userId, forKey: self.userIdKey)
                LoginStore.shared.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
                    .receive(on: RunLoop.main)
                    .dropFirst()
                    .sink { [weak self] user in
                        guard let self = self, let user = user else {
                            TUITool.makeToast("Login failed, user is null")
                            if let self = self {
                                cancelableSet.forEach { $0.cancel() }
                                cancelableSet.removeAll()
                            }
                            return
                        }
                        nickName = user.nickname ?? ""
                        loginSucc()
                        cancelableSet.forEach { $0.cancel() }
                        cancelableSet.removeAll()
                    }
                    .store(in: &cancelableSet)
            case .failure(let err):
                TUITool.makeToast("Login failed, code: \(err.code), error: \(err.message)")
            }
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
