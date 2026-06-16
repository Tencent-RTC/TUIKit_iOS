//
//  MineViewController.swift
//  mine
//
//  个人中心主控制器 — 从旧版 iOS/App/RT-Cube/Mine/ui/MineViewController.swift 迁移
//
//  变更说明：
//    - 移除 `import ImSDK_Plus / TUIContact / RTCCommon / BusinessService / ITLogin / AtomicXCore`
//    - 退出登录改为通过 `onLogout` 回调通知外部，由外部调用 LoginEntry.shared.logout()
//    - 语言切换改为使用 v2/ios/language/ 模块的 LanguageEntry
//    - `LanguageSelectViewControllerDelegate` 替换为 onLanguageChanged 闭包回调
//

import UIKit
import AtomicX
import TUICore
import Login

class MineViewController: UIViewController {
    
    /// 退出登录回调（由外部注入）
    var onLogout: (() -> Void)?
    
    /// 语言切换回调（由外部注入）
    var onLanguageChanged: ((String) -> Void)?
    
    /// 体验房点击回调（由外部注入）
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
            title: MineLocalize("mine_info_dialog_logout"),
            message: nil,
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(
            title: MineLocalize("mine_common_btn_cancel"),
            style: .cancel, handler: nil
        )
        let sureAction = UIAlertAction(
            title: MineLocalize("mine_common_btn_determine"),
            style: .default
        ) { [weak self] _ in
            self?.onLogout?()
        }
        alertVC.addAction(cancelAction)
        alertVC.addAction(sureAction)
        navigationController?.present(alertVC, animated: true, completion: nil)
    }
}
