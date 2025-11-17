//
//  MineViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/8.
//

import UIKit

import UIKit
import ImSDK_Plus
import RTCCommon
import TUICore
import AtomicXCore

@objc class MineViewController: UIViewController {
    private lazy var rootView: MineView = {
        let viewModel = MineViewModel()
        let view = MineView(viewModel: viewModel)
        view.delegate = self
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor("EBEDF5")
        constructViewHierarchy()
        activateConstraints()
    }
    
    private func constructViewHierarchy() {
        view.addSubview(rootView)
    }
    
    private func activateConstraints() {
        rootView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        rootView.updateProfile()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

extension MineViewController: MineViewDelegate {
    func didTapBackOnMine() {
        self.navigationController?.popViewController(animated: true)
    }
    
    func didTapSettingsOnMine() {
        let mineSettingsViewController = MineSettingsViewController()
        navigationController?.pushViewController(mineSettingsViewController, animated: true)
    }
    
    func didTapLogOnMine() {
        LogUploadManager.sharedInstance.startUpload(withSuccessHandler: nil) {
            debugPrint("Log upload canceled")
        }
    }
    
    func didRequestLogout() {
        let alertVC = UIAlertController(title: ("Are you sure you want to log out?").localized, message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: ("Cancel").localized, style: .cancel, handler: nil)
        let sureAction = UIAlertAction(title: ("Yes").localized, style: .default) { _ in
            UserDefaults.standard.removeObject(forKey: "UserIdKey")
            LoginStore.shared.logout { result in
                switch result {
                case .success(()):
                    DispatchQueue.main.async {
                        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                            appDelegate.showLoginViewController()
                        }
                    }
                case .failure(_):
                    DispatchQueue.main.async {
                        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                            appDelegate.showLoginViewController()
                        }
                    }
                }
            }
        }
        alertVC.addAction(cancelAction)
        alertVC.addAction(sureAction)
        present(alertVC, animated: true, completion: nil)
    }
}


