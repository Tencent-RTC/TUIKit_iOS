//
//  RegisterViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import Foundation
import SnapKit
import UIKit
import AtomicXCore
//import TUICore

class RegisterViewController: UIViewController {
    
    private let rootView = RegisterView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Register".localized
        constructViewHierarchy()
        activateConstraints()
        rootView.delegate = self
    }

    private func constructViewHierarchy() {
        view.addSubview(rootView)
    }
    
    private func activateConstraints() {
        rootView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func register(_ userName: String) {
        let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        guard !userID.isEmpty else { return }
        let profile = UserProfile(userID: userID, nickname: userName, avatarURL: DEFAULT_AVATAR_REGISTER)
        LoginStore.shared.setSelfInfo(userProfile: profile) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.viewIfLoaded?.window != nil else { return }
                switch result {
                case .success: self.registerSuccess()
                case .failure(let error): self.view.showAtomicToast(text: error.message)
                }
            }
        }
    }
    
    private func registerSuccess() {
        self.view.showAtomicToast(text: "Registered successfully".localized)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.showMainViewController()
        }
    }
}

extension RegisterViewController: RegisterViewDelegate {
    func registerDelegate(username: String) {
        register(username)
    }
}
