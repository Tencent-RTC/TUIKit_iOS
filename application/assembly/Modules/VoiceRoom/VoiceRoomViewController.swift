//
//  VoiceRoomViewController.swift
//  main
//

import AtomicX
import Combine
import Login
import SnapKit
import Toast_Swift
import TUICore
import TUILiveKit
import UIKit

// MARK: - VoiceRoomViewController

final class VoiceRoomViewController: UIViewController {
    // MARK: - Properties

    private var cancellableSet = Set<AnyCancellable>()

    // MARK: - Subviews

    private lazy var liveListViewController: TUILiveListViewController = .init()

    private lazy var createButton = AtomicButton(variant: .filled,
                                                 colorType: .primary,
                                                 size: .large,
                                                 content: .iconLeading(text: AssemblyLocalize("Demo.TRTC.LiveRoom.createroom"),
                                                                       icon: AppAssemblyBundle.image(named: "livekit_ic_add")))

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        ThemeStore.shared.setMode(.dark)
        setupNavigation()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        view.backgroundColor = .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            ThemeStore.shared.setMode(.light)
        }
    }
}

// MARK: - UI

extension VoiceRoomViewController {
    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let titleLabel = AssemblyLocalize("Demo.TRTC.VoiceRoom.voicechatroom")
        let titleView = AtomicLabel(titleLabel) { theme in
            LabelAppearance(textColor: theme.tokens.color.textColorAntiPrimary,
                            backgroundColor: theme.tokens.color.clearColor,
                            font: theme.tokens.typography.Medium20,
                            cornerRadius: 0.0)
        }
        titleView.adjustsFontSizeToFitWidth = true
        titleView.font = ThemeStore.shared.currentTheme.tokens.typography.Medium20
        titleView.text = titleLabel
        let width = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude)).width
        titleView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: 44))
        navigationItem.titleView = titleView

        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let backItem = UIBarButtonItem(customView: backBtn)
        backItem.tintColor = .black
        navigationItem.leftBarButtonItem = backItem

        let helpBtn = UIButton(type: .custom)
        helpBtn.setImage(AppAssemblyBundle.image(named: "help_small"), for: .normal)
        helpBtn.addTarget(self, action: #selector(connectWeb), for: .touchUpInside)
        helpBtn.sizeToFit()
        let rightItem = UIBarButtonItem(customView: helpBtn)
        rightItem.tintColor = .black
        navigationItem.rightBarButtonItem = rightItem
    }

    private func constructViewHierarchy() {
        addChild(liveListViewController)
        view.addSubview(liveListViewController.view)
        view.addSubview(createButton)
    }

    private func activateConstraints() {
        liveListViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        createButton.snp.makeConstraints { make in
            make.bottom.equalTo(-(convertPixel(h: 15) + kDeviceSafeBottomHeight))
            make.centerX.equalToSuperview()
            make.height.equalTo(convertPixel(w: 48))
            make.width.equalTo(convertPixel(w: 154))
        }
    }

    private func bindInteraction() {
        createButton.addTarget(self, action: #selector(createRoom), for: .touchUpInside)
    }
}

// MARK: - Actions

extension VoiceRoomViewController {
    @objc private func createRoom() {
        guard AppAssembly.shared.canStartNewRoom else {
            AppAssembly.shared.showCannotStartRoomToast()
            return
        }

        let voiceRoomId = LiveIdentityGenerator.shared.generateId(LoginEntry.shared.userModel?.userId ?? "", type: .voice)
        let params = CreateRoomParams()
        VoiceRoomKit.createInstance().createRoom(roomId: voiceRoomId, params: params)
    }

    @objc private func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func connectWeb() {
        if let url = URL(string: "https://cloud.tencent.com/document/product/647/105441") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
