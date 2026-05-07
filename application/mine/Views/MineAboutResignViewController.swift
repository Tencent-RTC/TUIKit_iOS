//
//  MineAboutResignViewController.swift
//  mine
//

import UIKit
import AtomicX
import Login
import SnapKit
import Toast_Swift

class MineAboutResignViewController: UIViewController {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "resign"))
        return imageView
    }()
    
    lazy var tipsLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.text = MineLocalize("Demo.TRTC.Portal.resigntips")
        return label
    }()
    
    lazy var numberLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()
    
    lazy var confirmBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(MineLocalize("Demo.TRTC.Portal.confirmresign"), for: .normal)
        btn.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        btn.addTarget(self, action: #selector(resignBtnClick), for: .touchUpInside)
        return btn
    }()
    
    lazy var loading: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .large)
        } else {
            return UIActivityIndicatorView(style: .whiteLarge)
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        
        self.title = MineLocalize("Demo.TRTC.Portal.resignaccount")
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.font: ThemeStore.shared.typographyTokens.Bold18
        ]
        navigationController?.navigationBar.barTintColor = .white
        navigationController?.navigationBar.isTranslucent = false
        
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "main_mine_about_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = .black
        navigationItem.leftBarButtonItem = item
        
        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(40)
        }
        
        view.addSubview(tipsLabel)
        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        
        view.addSubview(numberLabel)
        numberLabel.snp.makeConstraints { make in
            make.top.equalTo(tipsLabel.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        
        view.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { make in
            make.top.equalTo(numberLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(40)
            make.trailing.equalToSuperview().offset(-40)
            make.height.equalTo(56)
        }
        
        numberLabel.text = MineLocalize(
            "Demo.TRTC.Portal.currentaccount",
            LoginEntry.shared.userModel?.userId ?? ""
        )
        
        view.addSubview(loading)
        loading.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.centerX.centerY.equalTo(view)
        }
    }
    
    @objc func resignBtnClick() {
        let alert = UIAlertController(
            title: MineLocalize("Demo.TRTC.Portal.alerttoresign"),
            message: "",
            preferredStyle: .alert
        )
        let cancel = UIAlertAction(
            title: MineLocalize("App.PortalViewController.cancel"),
            style: .cancel, handler: nil
        )
        let confirm = UIAlertAction(
            title: MineLocalize("Demo.TRTC.Portal.confirmresign"),
            style: .default
        ) { [weak self] _ in
            self?.resignPhoneNumber()
        }
        alert.addAction(cancel)
        alert.addAction(confirm)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func resignPhoneNumber() {
        loading.startAnimating()
        LoginEntry.shared.logoff { [weak self] result in
            guard let self = self else { return }
            self.loading.stopAnimating()
            switch result {
            case .success:
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    window.makeToast(MineLocalize("Demo.TRTC.Portal.resignsuccess"))
                }
                if let mineVC = self.navigationController?.viewControllers.first(where: { $0 is MineViewController }) as? MineViewController {
                    mineVC.onLogout?()
                }
            case .failure(let error):
                self.view.makeToast("\(error)")
            }
        }
    }
    
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
}
