//
//  RegisterViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import Foundation
import SnapKit
import UIKit
import ImSDK_Plus
import TUICore

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
        let userFullInfo = V2TIMUserFullInfo()
        userFullInfo.nickName = userName
        userFullInfo.faceURL = DEFAULT_AVATAR_REGISTER
        V2TIMManager.sharedInstance().setSelfInfo(info: userFullInfo) { [weak self] in
            self?.registerSuccess()
        } fail: { [weak self] code, message in
            guard let self = self else {return}
            view.showAtomicToast(text: "login failed, code:\(code), message: \(String(describing: message))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.navigationController?.popViewController(animated: true)
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
