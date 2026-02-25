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
    private let autoLoginKey = "AutoLoginKey"
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
                            self?.view.showAtomicToast(text: "Login failed, user is null")
                            if let self = self {
                                cancelableSet.forEach { $0.cancel() }
                                cancelableSet.removeAll()
                            }
                            return
                        }
                        nickName = user.nickname ?? ""
                        loginTUICore(userID: userId)
                        cancelableSet.forEach { $0.cancel() }
                        cancelableSet.removeAll()
                    }
                    .store(in: &cancelableSet)
            case .failure(let err):
                    self.view.showAtomicToast(text: "Login failed, code: \(err.code), error: \(err.message)", style: .error)
            }
        }
    }
    
    private func loginTUICore(userID: String) {
        // FIXME: 临时方案 修复RoomKit 1.0版本 在应用内会议相关功能不可用问题， 后续升级到RoomKit 2.0版本 这部分逻辑将删除。
        TUILogin.login(Int32(SDKAPPID), userID: userID, userSig: GenerateTestUserSig.genTestUserSig(identifier: userID)) { [weak self] in
            guard let self = self else { return }
            loginSuccess()
        } fail: { [weak self] code, message in
            guard let self = self else {return}
            view.showAtomicToast(text: "Login failed, code: \(code), error: \(message ?? "")")
        }
    }
    
    private func autoLogin() {
        if let userId = UserDefaults.standard.string(forKey: userIdKey), !userId.isEmpty {
            rootView.userIdTextField.text = userId
            // 只有在自动登录开关打开时才自动登录
            let isAutoLoginEnabled = UserDefaults.standard.bool(forKey: autoLoginKey)
            if isAutoLoginEnabled {
                login(userId: userId)
            }
        } else {
            rootView.userIdTextField.text = UserDefaults.standard.string(forKey: userIdKey)
        }
    }
}

extension LoginViewController: LoginViewDelegate {
    
    func autoLoginSwitchChanged(isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: "AutoLoginKey")
    }
    
    func loginDelegate(userId: String) {
        login(userId: userId)
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

extension LoginViewController {
    private func loginSuccess() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        if nickName.count == 0 {
            let vc = RegisterViewController()
            navigationController?.pushViewController(vc, animated: true)
        } else {
            self.view.showAtomicToast(text: "Logged In".localized)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appDelegate?.showMainViewController()
            }
        }
    }
}
