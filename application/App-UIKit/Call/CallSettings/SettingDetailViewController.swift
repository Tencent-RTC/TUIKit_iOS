//
//  SettingDetailViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
//
import Foundation
import UIKit
import TUICore
import RTCRoomEngine

#if canImport(TUICallKit_Swift)
import TUICallKit_Swift
#elseif canImport(TUICallKit)
import TUICallKit
#endif

class SettingDetailViewController: UIViewController, UITextViewDelegate {
    enum DetailType{
        case ringInfo
        case entendInfo
        case offlinePushInfo
    }
    private var detail: DetailType
    
    init(type: DetailType) {
        self.detail = type
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let textView: UITextView = {
        let view = UITextView(frame: .zero)
        view.backgroundColor = UIColor.clear
        view.font = UIFont(name: "PingFangSC-Regular", size: 16)
        view.textColor = UIColor(hex: "333333")
        view.textAlignment = .left
        view.isScrollEnabled = true
        return view
    }()
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "back"), for: .normal)
        button.tintColor = .black
        return button
    }()

    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(("Yes").localized, for: .normal)
        button.tintColor = .black
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavigationBar()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setTextView()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.black
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: confirmButton)
        navigationController?.navigationBar.isHidden = false
    }
    
    private func constructViewHierarchy() {
        view.addSubview(textView)
    }
    
    private func activateConstraints() {
        textView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100.scale375Height())
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    private func bindInteraction() {
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmButtonClick), for: .touchUpInside)
        textView.delegate = self
    }
    
    private func setTextView() {
        switch detail {
        case .ringInfo:
            textView.text = ("SetRingTip").localized
        case .entendInfo:
            textView.text = ("SetExtendTip").localized
        case .offlinePushInfo:
            textView.text = ("SetOffLineInfoTip").localized
        }
    }
    
    @objc private func backButtonClick() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func confirmButtonClick() {
        guard let textString = textView.text else { return }
        switch detail {
        case .ringInfo:
            ringSetting(text: textString)
        case .entendInfo:
            entendInfoSetting(text: textString)
        case .offlinePushInfo:
            offlinePushInfoSetting(text: textString)
        }
    }
    
    private func ringSetting(text: String) {
        if text.isEmpty {
            return
        }
        TUICallKit.createInstance().setCallingBell(filePath: text)
        SettingsConfig.share.ringUrl = text
        TUITool.makeToast("Set Successful: \(SettingsConfig.share.ringUrl)")
    }
    
    private func entendInfoSetting(text: String) {
        if text.isEmpty {
            return
        }
        SettingsConfig.share.userData = text
        TUITool.makeToast("Set Successful: \(text)")
    }
    
    private func offlinePushInfoSetting(text: String) {
        if text.isEmpty {
            return
        }
        setOfflineData(jsonStr: text)
        TUITool.makeToast("Set Successful: \(SettingsConfig.share.pushInfo)")
    }
    
    private func setOfflineData(jsonStr: String) {
        guard let jsonData = jsonStr.data(using: String.Encoding.utf8) else { return }
        let json = try? JSONSerialization.jsonObject(with: jsonData)
        if let jsonDic = json as? [String : Any] {
            
            if let value = jsonDic["title"] as? String {
                SettingsConfig.share.pushInfo.title = value
            }
            
            if let value = jsonDic["desc"] as? String {
                SettingsConfig.share.pushInfo.desc = value
            }
            
            if let value = jsonDic["iOSPushType"] as? Int {
                SettingsConfig.share.pushInfo.iOSPushType = value == 0 ? .apns : .voIP
            }
            
            if let value = jsonDic["ignoreIOSBadge"] as? Bool {
                SettingsConfig.share.pushInfo.ignoreIOSBadge = value
            }
            
            if let value = jsonDic["iOSSound"] as? String {
                SettingsConfig.share.pushInfo.iOSSound = value
            }
            
            if let value = jsonDic["androidSound"] as? String {
                SettingsConfig.share.pushInfo.androidSound = value
            }
            
            if let value = jsonDic["androidOPPOChannelID"] as? String {
                SettingsConfig.share.pushInfo.androidOPPOChannelID = value
            }
            
            if let value = jsonDic["androidFCMChannelID"] as? String {
                SettingsConfig.share.pushInfo.androidFCMChannelID = value
            }
            
            if let value = jsonDic["title"] as? String {
                SettingsConfig.share.pushInfo.title = value
            }
            
            if let value = jsonDic["androidVIVOClassification"] as? Int {
                SettingsConfig.share.pushInfo.androidVIVOClassification = value
            }
            
            if let value = jsonDic["androidHuaWeiCategory"] as? String {
                SettingsConfig.share.pushInfo.androidHuaWeiCategory = value
            }
        }
    }
    
}
