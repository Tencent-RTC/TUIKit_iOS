//
//  TRTCCallingContactViewController.swift
//  main
//

import Foundation
import TUICallKit_Swift
import RTCRoomEngine
import UIKit
import TUICore
import AtomicXCore
import Login
import AtomicX

public class TRTCCallingContactViewController: UIViewController {
    var selectedFinished: (([UserModel]) -> Void)? = nil
    var callType: CallMediaType = .audio

    lazy var callingContactView: TRTCCallingContactView = {
        let callingContactView = TRTCCallingContactView(frame: .zero, type: .call) { [weak self] users in
            guard let self = self else { return }
            var userIds: [String] = []
            for userModel in users {
                userIds.append(userModel.userId)
            }
            self.showCallVC(users: userIds)
        }
        return callingContactView
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item

        setupUI()
        bindInteraction()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }

    deinit {
        debugPrint("deinit \(self)")
    }
}

extension TRTCCallingContactViewController {

    func setupUI() {
        view.addSubview(callingContactView)

        callingContactView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bindInteraction() {
        callingContactView.gotoGuideVCHandler = { [weak self] in
            guard let self = self else { return }
            let currentLanguageCode = TUIGlobalization.getPreferredLanguage()
            let url = "https://rtcube.cloud.tencent.com/component/experience-center/index.html#/detail?scene=callkit"
            let urlEn = "https://trtc.io/demo/homepage/#/detail?scene=callkit"
            let guideVC = GuideHomeViewController(selectedIndex: 0, homeJsonData: GuideHomeModel(singlePlayerJsonName: "callingSingleGuideData",
                                                                                                 withAppJsonName: "callingWithAppGuideData",
                                                                                                 withWebJsonName: "callingWithWebGuideData"),
                                                  copyUrl: url,
                                                  copyUrlEn: urlEn)
            guideVC.title = CallingLocalize("Demo.TRTC.calling.guideTitle")
            self.navigationController?.pushViewController(guideVC, animated: true)
        }
    }

    func showCallVC(users: [String]) {
        TUICallKit.createInstance().calls(userIdList: users, mediaType: callType, params: nil, completion: nil)
    }
}
