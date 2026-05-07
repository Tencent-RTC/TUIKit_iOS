//
//  ProfileDatePickerView.swift
//  mine
//

import UIKit
import AtomicX
import TUICore

class ProfileDatePickerView: UIView {
    var profile: V2TIMUserFullInfo?
    var confirmClosure: (String) -> Void = { _ in }
    var hideClosure: () -> Void = {}
    
    convenience init(withProfile profile: V2TIMUserFullInfo?, frame: CGRect) {
        self.init(frame: frame)
        self.profile = profile
    }
    
    private var themedInterfaceStyle: UIUserInterfaceStyle {
        switch ThemeStore.shared.currentMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return .unspecified
        }
    }
    
    lazy var picker: UIDatePicker = {
        let picker = UIDatePicker()
        let language = TUIGlobalization.getPreferredLanguage()
        picker.locale = Locale(identifier: language ?? "en")
        if profile?.birthday != 0 {
            guard let number = profile?.birthday else { return picker }
            let numberString = String(number)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            if let date = dateFormatter.date(from: numberString) {
                picker.date = date
            } else {
                picker.date = Date()
            }
        } else {
            picker.date = Date()
        }
        picker.maximumDate = Date()
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        picker.datePickerMode = .date
        picker.overrideUserInterfaceStyle = themedInterfaceStyle
        return picker
    }()
    
    lazy var menuView: UIView = {
        let menuView = UIView()
        menuView.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        menuView.overrideUserInterfaceStyle = themedInterfaceStyle
        return menuView
    }()
    
    lazy var cancelButton: UIButton = {
        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(MineLocalize("Demo.TRTC.Portal.Mine.cancel"), for: .normal)
        cancelButton.setTitleColor(ThemeStore.shared.colorTokens.textColorPrimary, for: .normal)
        cancelButton.titleLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        cancelButton.addTarget(self, action: #selector(onViewHide), for: .touchUpInside)
        return cancelButton
    }()
    
    lazy var okButton: UIButton = {
        let okButton = UIButton(type: .custom)
        okButton.setTitle(MineLocalize("Demo.TRTC.Portal.Mine.determine"), for: .normal)
        okButton.setTitleColor(ThemeStore.shared.colorTokens.textColorPrimary, for: .normal)
        okButton.titleLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        okButton.addTarget(self, action: #selector(onConfirmClicked), for: .touchUpInside)
        return okButton
    }()
    
    var isViewReady = false
    override func didMoveToWindow() {
        guard !isViewReady else { return }
        isViewReady = true
        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let tap = UITapGestureRecognizer(target: self, action: #selector(onViewHide))
        isUserInteractionEnabled = true
        addGestureRecognizer(tap)
        constructViewHierarchy()
        activateConstraints()
    }
    
    func constructViewHierarchy() {
        addSubview(menuView)
        menuView.addSubview(cancelButton)
        menuView.addSubview(okButton)
        addSubview(picker)
    }
    
    func activateConstraints() {
        menuView.frame = CGRect(x: 0, y: UIScreen.main.bounds.size.height - 340,
                                width: UIScreen.main.bounds.size.width, height: 40)
        cancelButton.frame = CGRect(x: 10, y: 0, width: 60, height: 35)
        okButton.frame = CGRect(x: bounds.size.width - 10 - 60, y: 0, width: 60, height: 35)
        picker.frame = CGRect(x: 0, y: menuView.frame.maxY,
                              width: bounds.size.width, height: 300)
    }
}

// MARK: - Actions

extension ProfileDatePickerView {
    @objc func onViewHide() {
        hideClosure()
    }
    
    @objc func onConfirmClicked() {
        let date = self.picker.date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var dateStr = dateFormatter.string(from: date)
        dateStr = dateStr.replacingOccurrences(of: "-", with: "")
        confirmClosure(dateStr)
        onViewHide()
    }
}
