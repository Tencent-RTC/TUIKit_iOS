//
//  MineViewController.swift
//  mine
//

import UIKit
import AtomicX
import TUICore
import Login

class MineViewController: UIViewController {
    
    var onLogout: (() -> Void)?
    
    var onLanguageChanged: ((String) -> Void)?
    
    var onExperienceRoomClicked: (() -> Void)?
    
    var isNeedUpdateProfile = false
    
    private lazy var rootView: MineRootView = {
        let viewModel = MineViewModel()
        let view = MineRootView(viewModel: viewModel)
        view.delegate = self
        return view
    }()
    
    override func loadView() {
        super.loadView()
        view = rootView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        
        if isNeedUpdateProfile {
            rootView.updateProfile()
            isNeedUpdateProfile = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        } else {
            return .default
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
}

// MARK: - MineRootViewDelegate

extension MineViewController: MineRootViewDelegate {
    func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    func jumpProfileController() {
        isNeedUpdateProfile = true
        let profileController = ProfileController()
        navigationController?.pushViewController(profileController, animated: true)
    }
    
    func jumpExperienceRoom() {
        onExperienceRoomClicked?()
    }
    
    func logout() {
        let alertVC = UIAlertController(
            title: MineLocalize("Demo.TRTC.Portal.Mine.areYouSureLogOut"),
            message: nil,
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(
            title: MineLocalize("Demo.TRTC.Portal.Mine.cancel"),
            style: .cancel, handler: nil
        )
        let sureAction = UIAlertAction(
            title: MineLocalize("Demo.TRTC.Portal.Mine.determine"),
            style: .default
        ) { [weak self] _ in
            self?.onLogout?()
        }
        alertVC.addAction(cancelAction)
        alertVC.addAction(sureAction)
        navigationController?.present(alertVC, animated: true, completion: nil)
    }
}
