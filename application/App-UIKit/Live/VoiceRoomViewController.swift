//
//  LiveListViewController.swift
//  App-UIKit
//
//  Created by chensshi on 2024/10/9.
//

import UIKit
import TUICore
import TUILiveKit
import AtomicXCore
import AtomicX

class VoiceRoomViewController: UIViewController {

    private lazy var goLiveButton = {
        let button = AtomicButton(variant: .filled,
            colorType: .primary,
            size: .large,
            content: .iconLeading(text: .goLiveText, icon: UIImage(named: "livekit_ic_add")))
        button.addTarget(self, action: #selector(goLiveClick), for: .touchUpInside)
        return button
    }()

    private lazy var liveListViewController = {
        return TUILiveListViewController()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        constructViewHierarchy()
        activateConstraints()
        view.backgroundColor = .white
    }


    private func constructViewHierarchy() {
        view.addSubview(goLiveButton)

        addChild(liveListViewController)
        view.addSubview(liveListViewController.view)
        view.bringSubviewToFront(goLiveButton)
    }

    private func activateConstraints() {
        liveListViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        goLiveButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-15.scale375Height())
            make.centerX.equalToSuperview()
            make.height.equalTo(48.scale375())
            make.width.equalTo(154.scale375())
        }
    }

}

// MARK: - Private
extension VoiceRoomViewController {

    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let backItem = UIBarButtonItem(customView: backBtn)
        navigationItem.leftBarButtonItem = backItem

        let helpButton = UIButton()
        helpButton.setImage(UIImage(named: "help_small"), for: .normal)
        helpButton.addTarget(self, action: #selector(helpClick), for: .touchUpInside)
        helpButton.sizeToFit()
        let helpItem = UIBarButtonItem(customView: helpButton)
        helpItem.tintColor = .black
        navigationItem.rightBarButtonItem = helpItem

        let titleView = AtomicLabel(.voiceRoomTitle) { theme in
            return LabelAppearance(textColor: theme.tokens.color.textColorAntiPrimary,
                                   backgroundColor: theme.tokens.color.clearColor,
                                   font: theme.tokens.typography.Medium20,
                                   cornerRadius: 0.0)
        }
        titleView.adjustsFontSizeToFitWidth = true
        let width = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude)).width
        titleView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: width, height: 44))
        self.navigationItem.titleView = titleView
    }

}

// MARK: - Actions
extension VoiceRoomViewController {
    @objc private func backBtnClick(sender: UIButton) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func helpClick() {
        if let url = URL(string: "https://cloud.tencent.com/document/product/647/105441") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    @objc private func goLiveClick() {
        let userId = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let voiceRoomId = LiveIdentityGenerator.shared.generateId(userId, type: .voice)
        let params = CreateRoomParams()
        VoiceRoomKit.createInstance().createRoom(roomId: voiceRoomId, params: params)
    }
}


fileprivate extension String {
    static let voiceRoomTitle = "Voice Room".localized
    static let goLiveText = "Go Live".localized
}
