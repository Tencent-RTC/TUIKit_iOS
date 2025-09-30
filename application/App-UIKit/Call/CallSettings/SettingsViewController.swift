//
//  SettingsViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
//

import Foundation
import TUICore
import UIKit
import RTCRoomEngine

#if canImport(TUICallKit_Swift)
import TUICallKit_Swift
#elseif canImport(TUICallKit)
import TUICallKit
#endif

class SettingsViewController: UIViewController, UITextFieldDelegate {
    private var intRoomId: UInt32 = 0
    private var strRoomId: String = ""
    private var timeout: Int = 30
    private var userData: String = ""
    private var offlineData: String = ""
    private var beautyLevel: Int = 6
    
    private var currentTextField: UITextField?
    
    private let scrollView: UIScrollView = {
        return UIScrollView()
    }()
    
    private let scrollContentView: UIView = {
        return UIView(frame: CGRect.zero)
    }()
    
    private let basicSettingContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "AAAAAA")
        return view
    }()
    private lazy var basicSettingLabel: UILabel = {
        return createLabel(textSize: 16, text: ("BasicSetting").localized)
    }()
    
    private let ringContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var ringLabel: UILabel = {
        return createLabel(textSize: 16, text: ("RingSetting").localized)
    }()
    private lazy var ringInfoLabel: UILabel = {
        let place: String = SettingsConfig.share.ringUrl.isEmpty ?
        ("NotSet").localized : SettingsConfig.share.ringUrl
        let view = createLabel(textSize: 16, text: place)
        view.textColor = UIColor(hex: "AAAAAA")
        view.textAlignment = .right
        return view
    }()
    private lazy var ringAvBtn: UILabel = {
        let view = createLabel(textSize: 16, text: " > ")
        view.textAlignment = .center
        view.isUserInteractionEnabled = true
        return view
    }()
    private lazy var muteSwitchView: UIView = {
        let customSwitchView = SettingsCustomSwitchView(title: ("MuteMode").localized,
                                                        isOn: SettingsConfig.share.mute)
        customSwitchView.switchValueChanged = { isOn in
            self.muteSwitchClick(isOn)
        }
        return customSwitchView
    }()
    private lazy var floatingSwitchView: UIView = {
        let customSwitchView = SettingsCustomSwitchView(title: ("EnableFloating").localized,
                                                        isOn: SettingsConfig.share.floatWindow)
        customSwitchView.switchValueChanged = { isOn in
            self.floatingSwitchClick(isOn)
        }
        return customSwitchView
    }()
#if canImport(TUICallKit_Swift)
    private lazy var virtualBackgroundSwitchView: SettingsCustomSwitchView = {
        let customSwitchView = SettingsCustomSwitchView(title: ("EnableVirtualBackground").localized,
                                                        isOn: SettingsConfig.share.enableVirtualBackground)
        customSwitchView.switchValueChanged = { isOn in
            self.virtualBackgroundSwitchClick(isOn)
        }
        return customSwitchView
    }()
    private lazy var incomingBannerSwitchView: SettingsCustomSwitchView = {
        let customSwitchView = SettingsCustomSwitchView(title: ("EnableIncomingBanner").localized,
                                                        isOn: SettingsConfig.share.enableIncomingBanner)
        customSwitchView.switchValueChanged = { isOn in
            self.incomingBannerSwitchClick(isOn)
        }
        return customSwitchView
    }()
#endif
    private let callSettingContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "AAAAAA")
        return view
    }()
    private lazy var callSettingLabel: UILabel = {
        return createLabel(textSize: 16, text: ("CallParamsSetting").localized)
    }()
    
    private let stringRoomIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var stringRoomIdLabel: UILabel = {
        return createLabel(textSize: 16, text: "strRoomId")
    }()
    private lazy var stringRoomIdTextField: UITextField = {
        let timeoutTextField = createTextField(text: SettingsConfig.share.strRoomId.isEmpty ? "null" : SettingsConfig.share.strRoomId)
        timeoutTextField.keyboardType = .phonePad
        return timeoutTextField
    }()
    
    private let intRoomIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var intRoomIdLabel: UILabel = {
        return createLabel(textSize: 16, text: "intRoomId")
    }()
    private lazy var intRoomIdTextField: UITextField = {
        let timeoutTextField = createTextField(text: String(SettingsConfig.share.intRoomId))
        timeoutTextField.keyboardType = .phonePad
        return timeoutTextField
    }()
    
    private let timeoutContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var timeoutLabel: UILabel = {
        return createLabel(textSize: 16, text: ("Timeout").localized)
    }()
    private lazy var timeoutTextField: UITextField = {
        let timeoutTextField = createTextField(text: "30")
        timeoutTextField.keyboardType = .phonePad
        return timeoutTextField
    }()
    
    private let extendedInfoContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var extendedInfoLabel: UILabel = {
        return createLabel(textSize: 16, text: ("ExpendedInfo").localized)
    }()
    private lazy var extendedInfo: UILabel = {
        let place = SettingsConfig.share.userData.isEmpty ? ("NotSet").localized : SettingsConfig.share.userData
        let view = createLabel(textSize: 16, text: place)
        view.textColor = UIColor(hex: "AAAAAA")
        view.textAlignment = .right
        return view
    }()
    private lazy var extendedBtn: UILabel = {
        let view = createLabel(textSize: 16, text: " > ")
        view.textAlignment = .center
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let offlinePushContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var offlinePushLabel: UILabel = {
        return createLabel(textSize: 16, text: ("OfflinePushInfo").localized)
    }()
    private lazy var offlinePushInfo: UILabel = {
        let view = createLabel(textSize: 16, text: ("GoToSettings").localized)
        view.textColor = UIColor(hex: "AAAAAA")
        view.textAlignment = .right
        return view
    }()
    private lazy var offlinePushBtn: UILabel = {
        let view = createLabel(textSize: 16, text: " > ")
        view.textAlignment = .center
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let videoSettingContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "AAAAAA")
        return view
    }()
    private lazy var videoSettingLabel: UILabel = {
        return createLabel(textSize: 16, text: ("VideoSetting").localized)
    }()
    
    private let resolutionContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var resolutionLabel: UILabel = {
        return createLabel(textSize: 16, text: ("Resolution").localized)
    }()
    private let resolutionData = ["640*360","960*540","1280*720","1920*1080"]
    private lazy var resolutionDropMenu: SwiftDropMenuListView = {
        let menu = SwiftDropMenuListView(frame: CGRect.zero)
        let titleStr: String = resolutionData[convertResolutionToIndex(resolution: SettingsConfig.share.resolution)] + " >"
        menu.setTitle(titleStr, for: .normal)
        menu.setTitleColor(.black, for: .normal)
        menu.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 16)
        menu.backgroundColor = UIColor.clear
        menu.translatesAutoresizingMaskIntoConstraints = true
        return menu
    }()
    
    private let resolutionModeContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var resolutionModeLabel: UILabel = {
        return createLabel(textSize: 16, text: ("ResolutionMode").localized)
    }()
    private lazy var resolutionModeSegment: UISegmentedControl = {
        let index = SettingsConfig.share.resolutionMode == .landscape ? 0 : 1
        return createSegment(item: [("Horizontal").localized,
                                    ("Vertical").localized,], select: index)
    }()
    
    private let fillModeContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var fillModeLabel: UILabel = {
        return createLabel(textSize: 16, text: ("FillMode").localized)
    }()
    private lazy var fillModeSegment: UISegmentedControl = {
        let index = SettingsConfig.share.fillMode == .fit ? 0 : 1
        return createSegment(item: [("Fit").localized,
                                    ("Fill").localized,], select: index)
    }()
    
    private let rotationContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var rotationLabel: UILabel = {
        return createLabel(textSize: 16, text: ("Rotation").localized)
    }()
    private lazy var rotationSegment: UISegmentedControl = {
        return createSegment(item: ["0", "90", "180", "270"], select: convertRotationToIndex(rotation: SettingsConfig.share.rotation))
    }()
    
    private let beautyLevelContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var beautyLevelLabel: UILabel = {
        return createLabel(textSize: 16, text: ("BeautyLevel").localized)
    }()
    private lazy var beautyLevelTextField: UITextField = {
        let textField = createTextField(text: "\(SettingsConfig.share.beautyLevel)")
        textField.keyboardType = .phonePad
        return textField
    }()
    
    private let screenContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    private lazy var screenModeLabel: UILabel = {
        return createLabel(textSize: 16, text: ("OtherSetting").localized)
    }()
    private lazy var screenModeSegment: UISegmentedControl = {
        let titles = [
            ("Screen_Vertical").localized,
            ("Screen_Horizontal").localized,
            ("Screen_Auto").localized
        ]
        return createSegment(item: titles, select: SettingsConfig.share.screenOrientation)
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "back"), for: .normal)
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
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if let current = currentTextField {
            current.resignFirstResponder()
            currentTextField = nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateView()
    }
    
    private func updateView() {
        ringInfoLabel.text = SettingsConfig.share.ringUrl.isEmpty ?
        ("NotSet").localized : SettingsConfig.share.ringUrl
        extendedInfo.text = SettingsConfig.share.userData.isEmpty ?
        ("NotSet").localized : SettingsConfig.share.userData
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
    }
    
    private func constructViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(scrollContentView)
        
        scrollContentView.addSubview(basicSettingContentView)
        basicSettingContentView.addSubview(basicSettingLabel)
        
        scrollContentView.addSubview(ringContentView)
        ringContentView.addSubview(ringLabel)
        ringContentView.addSubview(ringInfoLabel)
        ringContentView.addSubview(ringAvBtn)
        
        scrollContentView.addSubview(muteSwitchView)
        scrollContentView.addSubview(floatingSwitchView)
        
#if canImport(TUICallKit_Swift)
        scrollContentView.addSubview(virtualBackgroundSwitchView)
        scrollContentView.addSubview(incomingBannerSwitchView)
#endif
        
        scrollContentView.addSubview(callSettingContentView)
        callSettingContentView.addSubview(callSettingLabel)
                
        scrollContentView.addSubview(stringRoomIdContentView)
        stringRoomIdContentView.addSubview(stringRoomIdLabel)
        stringRoomIdContentView.addSubview(stringRoomIdTextField)
        
        scrollContentView.addSubview(intRoomIdContentView)
        intRoomIdContentView.addSubview(intRoomIdLabel)
        intRoomIdContentView.addSubview(intRoomIdTextField)
        
        scrollContentView.addSubview(timeoutContentView)
        timeoutContentView.addSubview(timeoutLabel)
        timeoutContentView.addSubview(timeoutTextField)
        
        scrollContentView.addSubview(extendedInfoContentView)
        extendedInfoContentView.addSubview(extendedInfoLabel)
        extendedInfoContentView.addSubview(extendedInfo)
        extendedInfoContentView.addSubview(extendedBtn)
        
        scrollContentView.addSubview(offlinePushContentView)
        offlinePushContentView.addSubview(offlinePushLabel)
        offlinePushContentView.addSubview(offlinePushInfo)
        offlinePushContentView.addSubview(offlinePushBtn)
        
        scrollContentView.addSubview(videoSettingContentView)
        videoSettingContentView.addSubview(videoSettingLabel)
        
        scrollContentView.addSubview(resolutionContentView)
        resolutionContentView.addSubview(resolutionLabel)
        resolutionContentView.addSubview(resolutionDropMenu)
        
        scrollContentView.addSubview(resolutionModeContentView)
        resolutionModeContentView.addSubview(resolutionModeLabel)
        resolutionModeContentView.addSubview(resolutionModeSegment)
        
        scrollContentView.addSubview(fillModeContentView)
        fillModeContentView.addSubview(fillModeLabel)
        fillModeContentView.addSubview(fillModeSegment)
        
        scrollContentView.addSubview(rotationContentView)
        rotationContentView.addSubview(rotationLabel)
        rotationContentView.addSubview(rotationSegment)
        
        scrollContentView.addSubview(beautyLevelContentView)
        beautyLevelContentView.addSubview(beautyLevelLabel)
        beautyLevelContentView.addSubview(beautyLevelTextField)
        
        scrollContentView.addSubview(screenContentView)
        screenContentView.addSubview(screenModeLabel)
        screenContentView.addSubview(screenModeSegment)
   
    }
    
    private func activateConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.top.equalToSuperview().offset(100)
        }
        
        scrollContentView.snp.makeConstraints { make in
            make.top.bottom.equalTo(scrollView)
            make.left.right.equalTo(view)
        }
        
        basicSettingContentView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(30)
        }
        basicSettingLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        
        ringContentView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(basicSettingLabel.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        ringLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        ringAvBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(30)
        }
        ringInfoLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(ringAvBtn.snp.leading)
            make.leading.equalTo(ringLabel.snp.trailing).offset(20)
        }
        muteSwitchView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(ringContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        floatingSwitchView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(muteSwitchView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
#if canImport(TUICallKit_Swift)
        virtualBackgroundSwitchView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(floatingSwitchView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        incomingBannerSwitchView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(virtualBackgroundSwitchView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        callSettingContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(incomingBannerSwitchView.snp.bottom).offset(20)
            make.height.equalTo(30)
        }
#elseif canImport(TUICallKit)
        callSettingContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(floatingSwitchView.snp.bottom).offset(20)
            make.height.equalTo(30)
        }
#endif
        callSettingLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        
        stringRoomIdContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(callSettingContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        stringRoomIdLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        stringRoomIdTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-50)
            make.leading.equalTo(stringRoomIdLabel.snp.trailing).offset(20)
        }
        
        intRoomIdContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(stringRoomIdContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        intRoomIdLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        intRoomIdTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-50)
            make.leading.equalTo(intRoomIdLabel.snp.trailing).offset(20)
        }
        
        timeoutContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(intRoomIdContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        timeoutLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        timeoutTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-50)
            make.leading.equalTo(timeoutLabel.snp.trailing).offset(20)
        }
        
        extendedInfoContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(timeoutContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        extendedInfoLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        extendedBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(30)
        }
        extendedInfo.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(extendedInfoLabel.snp.trailing).offset(20)
            make.trailing.equalTo(extendedBtn.snp.leading)
        }
        
        offlinePushContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(extendedInfoContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        offlinePushLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        offlinePushBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(30)
        }
        offlinePushInfo.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(offlinePushLabel.snp.trailing).offset(20)
            make.trailing.equalTo(offlinePushBtn.snp.leading)
        }
        
        videoSettingContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(offlinePushContentView.snp.bottom).offset(20)
            make.height.equalTo(30)
        }
        videoSettingLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
        }
        
        resolutionContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(videoSettingLabel.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        resolutionLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(120)
        }
        resolutionDropMenu.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-30)
        }
        
        resolutionModeContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(resolutionContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        resolutionModeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(120)
        }
        resolutionModeSegment.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.leading.equalTo(resolutionModeLabel.snp.trailing).offset(20)
        }
        
        fillModeContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(resolutionModeContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        fillModeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(120)
        }
        fillModeSegment.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.leading.equalTo(fillModeLabel.snp.trailing).offset(20)
        }
        
        rotationContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(fillModeContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        rotationLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(120)
        }
        rotationSegment.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.leading.equalTo(rotationLabel.snp.trailing).offset(20)
        }
        
        beautyLevelContentView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(rotationContentView.snp.bottom).offset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(20)
        }
        beautyLevelLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(120)
        }
        beautyLevelTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(beautyLevelLabel.snp.leading).offset(30)
            make.trailing.equalToSuperview().offset(-50)
        }
        
        screenContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(rotationContentView.snp.bottom).offset(20)
            make.height.equalTo(20)
        }
        screenModeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(120)
        }
        screenModeSegment.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.leading.equalTo(screenModeLabel.snp.trailing).offset(20)
        }
    }
    
    private func bindInteraction() {       
        let ringAvBtnTapGesture = UITapGestureRecognizer(target: self, action: #selector(ringAvBtnClick))
        ringAvBtn.addGestureRecognizer(ringAvBtnTapGesture)
        
        let offlinePushBtnTapGesture = UITapGestureRecognizer(target: self, action: #selector(offlinePushClick))
        offlinePushBtn.addGestureRecognizer(offlinePushBtnTapGesture)
        
        let extendedBtnTapGesture = UITapGestureRecognizer(target: self, action: #selector(extendClick))
        extendedBtn.addGestureRecognizer(extendedBtnTapGesture)
        
        resolutionModeSegment.addTarget(self, action: #selector(resolutionModeSegmentClick), for: .valueChanged)
        fillModeSegment.addTarget(self, action: #selector(fillModeSegmentClick), for: .valueChanged)
        rotationSegment.addTarget(self, action: #selector(rotationSegmentClick), for: .valueChanged)
        screenModeSegment.addTarget(self, action: #selector(screenModeSegmentClick), for: .valueChanged)
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        
        resolutionDropMenu.delegate = self
        resolutionDropMenu.dataSource = self
    }
    
    @objc private func ringAvBtnClick() {
        let offlinePushVC = SettingDetailViewController(type: .ringInfo)
        offlinePushVC.title = ("SetRing").localized
        offlinePushVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(offlinePushVC, animated: true)
    }
    
    @objc private func offlinePushClick() {
        let offlinePushVC = SettingDetailViewController(type: .offlinePushInfo)
        offlinePushVC.title = ("SetOffLineInfo").localized
        offlinePushVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(offlinePushVC, animated: true)
    }
    
    @objc private func extendClick() {
        let extendVC = SettingDetailViewController(type: .entendInfo)
        extendVC.title = ("SetExtend").localized
        extendVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(extendVC, animated: true)
    }
    
    private func muteSwitchClick(_ isOn: Bool) {
        SettingsConfig.share.mute = isOn
        TUICallKit.createInstance().enableMuteMode(enable: isOn)
    }
    private func floatingSwitchClick(_ isOn: Bool) {
        SettingsConfig.share.floatWindow = isOn
        TUICallKit.createInstance().enableFloatWindow(enable: isOn)
    }
#if canImport(TUICallKit_Swift)
    private func virtualBackgroundSwitchClick(_ isOn: Bool) {
        SettingsConfig.share.enableVirtualBackground = isOn
        TUICallKit.createInstance().enableVirtualBackground(enable: isOn)
    }
    private func incomingBannerSwitchClick(_ isOn: Bool) {
        SettingsConfig.share.enableIncomingBanner = isOn
        TUICallKit.createInstance().enableIncomingBanner(enable: isOn)
    }
#endif
    
    @objc private func resolutionModeSegmentClick(_ sender: UISegmentedControl) {
        SettingsConfig.share.resolutionMode = sender.selectedSegmentIndex == 0 ? .landscape : .portrait
        let params = TUIVideoEncoderParams()
        params.resolution = SettingsConfig.share.resolution
        params.resolutionMode = sender.selectedSegmentIndex == 0 ? .landscape : .portrait
        TUICallEngine.createInstance().setVideoEncoderParams(params) {
        } fail: { code, message in
        }
    }
    
    @objc private func fillModeSegmentClick(_ sender: UISegmentedControl) {
        SettingsConfig.share.fillMode = sender.selectedSegmentIndex == 0 ? .fit : .fill
        
        let param = TUIVideoRenderParams()
        param.fillMode = SettingsConfig.share.fillMode
        param.rotation = SettingsConfig.share.rotation
        TUICallEngine.createInstance().setVideoRenderParams(userId: SettingsConfig.share.userId, params: param) {
        } fail: { code, message in
        }
    }
    
    @objc private func rotationSegmentClick(_ sender: UISegmentedControl) {
        SettingsConfig.share.rotation = convertIndexToRotation(index: sender.selectedSegmentIndex)
        let param = TUIVideoRenderParams()
        param.fillMode = SettingsConfig.share.fillMode
        param.rotation = SettingsConfig.share.rotation
        TUICallEngine.createInstance().setVideoRenderParams(userId: SettingsConfig.share.userId, params: param) {
        } fail: { code, message in
        }
    }
    
    @objc private func screenModeSegmentClick(_ sender: UISegmentedControl) {
        let orientation = sender.selectedSegmentIndex
        SettingsConfig.share.screenOrientation = orientation
        let tuiCallKit = TUICallKit()
        tuiCallKit.setScreenOrientation(orientation: orientation, succ: {
            print("Screen orientation changed successfully")
        }, fail: { error, arg in
            print("Failed to change screen orientation")
        })
    }
    
    @objc private func backButtonClick() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setStringRoomId(text: String) {
        SettingsConfig.share.strRoomId = text
    }
    
    private func setIntRoomId(text: UInt32) {
        SettingsConfig.share.intRoomId = text
    }
    
    private func timeoutButtonClick(text: String) {
        if text.isEmpty {
            return
        }
        SettingsConfig.share.timeout = Int(text) ?? 30
        
        self.timeoutTextField.attributedPlaceholder = NSAttributedString(string: String(SettingsConfig.share.timeout))
    }
    
    private func beautyLevelSetBtnClick(text: String) {
        if text.isEmpty {
            return
        }
        
        TUICallEngine.createInstance().setBeautyLevel(CGFloat(Int(text) ?? 0)) { [weak self] in
            guard let self = self else { return }
            SettingsConfig.share.beautyLevel = Int(text) ?? SettingsConfig.share.beautyLevel
            
            self.beautyLevelTextField.attributedPlaceholder = NSAttributedString(string: String(SettingsConfig.share.beautyLevel))
        } fail: { code, message in
            TUITool.makeToast("Error \(code):\(message ?? "")")
        }
    }
}

extension SettingsViewController {
    func createTextField(text: String) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16)
        textField.textColor = UIColor(hex: "333333")
        textField.attributedPlaceholder = NSAttributedString(string: text)
        textField.textAlignment = .right
        textField.delegate = self
        return textField
    }
    
    func createSettingButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitle(("Settings").localized, for: .normal)
        btn.adjustsImageWhenHighlighted = false
        btn.setBackgroundImage(UIColor(hex: "006EFF")?.trans2Image(), for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 15)
        btn.layer.shadowColor = UIColor(hex: "006EFF")?.cgColor ?? UIColor.blue.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 6)
        btn.layer.shadowRadius = 16
        btn.layer.shadowOpacity = 0.4
        btn.layer.masksToBounds = true
        btn.layer.cornerRadius = 5
        return btn
    }
    
    func createLabel(textSize: CGFloat, text: String) -> UILabel {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: textSize)
        label.textColor = .black
        label.text = text
        return label
    }
    
    func createSwitch(isOn: Bool) -> UISwitch {
        let switchBtn = UISwitch(frame: CGRect.zero)
        switchBtn.isOn = isOn
        return switchBtn
    }
    
    func createSegment(item: [Any], select: Int) -> UISegmentedControl {
        let segment = UISegmentedControl(items: item)
        segment.selectedSegmentIndex = select
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.gray], for: UIControl.State.normal)
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: UIControl.State.selected)
        return segment
    }
    
    func convertResolutionToIndex(resolution: TUIVideoEncoderParamsResolution) -> Int {
        switch resolution {
        case ._640_360:
            return 0
        case ._960_540:
            return 1
        case ._1280_720:
            return 2
        case ._1920_1080:
            return 3
        default:
            return 0
        }
    }
    
    func convertIndexToResolution(index: Int) -> TUIVideoEncoderParamsResolution {
        switch index {
        case 0:
            return ._640_360
        case 1:
            return ._960_540
        case 2:
            return ._1280_720
        case 3:
            return ._1920_1080
        default:
            return ._640_360
        }
    }
    
    func convertRotationToIndex(rotation: TUIVideoRenderParamsRotation) -> Int {
        switch rotation {
        case ._0:
            return 0
        case ._90:
            return 1
        case ._180:
            return 2
        case ._270:
            return 3
        default:
            return 0
        }
    }
    
    func convertIndexToRotation(index: Int) -> TUIVideoRenderParamsRotation {
        switch index {
        case 0:
            return ._0
        case 1:
            return ._90
        case 2:
            return ._180
        case 3:
            return ._270
        default:
            return ._0
        }
    }
}

extension SettingsViewController {
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        if let last = currentTextField {
            last.resignFirstResponder()
        }
        currentTextField = textField
        textField.becomeFirstResponder()
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        currentTextField = nil
        
        guard let text = textField.text else { return }
        if textField == timeoutTextField {
            timeoutButtonClick(text: text)
        }  else if  textField == beautyLevelTextField {
            beautyLevelSetBtnClick(text: text)
        } else if textField == stringRoomIdTextField {
            setStringRoomId(text: text)
        } else if textField == intRoomIdTextField {
            setIntRoomId(text: UInt32(text) ?? 0)
        }
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}

extension SettingsViewController: SwiftDropMenuListViewDataSource, SwiftDropMenuListViewDelegate {
    func numberOfItems(in menu: SwiftDropMenuListView) -> Int {
        return resolutionData.count
    }
    
    func dropMenu(_ menu: SwiftDropMenuListView, titleForItemAt index: Int) -> String {
        return resolutionData[index]
    }
    
    func heightOfRow(in menu: SwiftDropMenuListView) -> CGFloat {
        return 16
    }
    
    func numberOfColumns(in menu: SwiftDropMenuListView) -> Int {
        return 2
    }
    
    func dropMenu(_ menu: SwiftDropMenuListView, didSelectItem: String?, atIndex index: Int) {
        
        let params = TUIVideoEncoderParams()
        params.resolution = convertIndexToResolution(index: index)
        params.resolutionMode = SettingsConfig.share.resolutionMode
        TUICallEngine.createInstance().setVideoEncoderParams(params) {
            SettingsConfig.share.resolution = self.convertIndexToResolution(index: index)
            if let titleStr: String = didSelectItem {
                self.resolutionDropMenu.setTitle(titleStr + " >", for: .normal)
            }
        } fail: { code, message in
            
        }
    }
}
