//
//  CallingRecentCallsViewController.swift
//  main
//
//  通话模块 - 通话记录页（嵌入 TUICallKit 的 RecentCallsVC）
//

import UIKit
import AtomicX
import TUICallKit_Swift
import RTCRoomEngine
import TUICore

class CallingRecentCallsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = CallingLocalize("assembly_call_btn_start_call")
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item
        configSelfNavigationBar()

        var param: [String: Any] = Dictionary()
        param[TUICore_TUICallingObjectFactory_RecordCallsVC_UIStyle] = TUICore_TUICallingObjectFactory_RecordCallsVC_UIStyle_Classic
        if let vc = TUICore.createObject(TUICore_TUICallingObjectFactory,
                                         key: TUICore_TUICallingObjectFactory_RecordCallsVC,
                                         param: param) as? RecentCallsViewController
        {
            vc.view.frame = CGRect(x: 0, y: 44, width: ScreenWidth, height: ScreenHeight - 44)
            self.addChild(vc)
            view.addSubview(vc.view)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        configOtherNavigationBar()
    }

    @objc func backBtnClick() {
        self.navigationController?.popViewController(animated: true)
    }
}

extension CallingRecentCallsViewController {
    private func configSelfNavigationBar() {
        let appperance = UINavigationBarAppearance()
        appperance.backgroundColor = TUITheme.dynamicColor("head_bg_gradient_start_color", module: .core, defaultColor: "#EBF0F6")
        appperance.shadowImage = UIImage()
        appperance.shadowColor = nil
        self.navigationController?.navigationBar.standardAppearance = appperance
        self.navigationController?.navigationBar.scrollEdgeAppearance = appperance
    }

    private func configOtherNavigationBar() {
        let appperance = UINavigationBarAppearance()
        appperance.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        appperance.shadowImage = UIImage()
        appperance.shadowColor = nil
        appperance.titleTextAttributes = [NSAttributedString.Key.font: ThemeStore.shared.typographyTokens.Regular18,
                                          NSAttributedString.Key.foregroundColor: UIColor.black]
        self.navigationController?.navigationBar.standardAppearance = appperance
        self.navigationController?.navigationBar.scrollEdgeAppearance = appperance
    }
}
