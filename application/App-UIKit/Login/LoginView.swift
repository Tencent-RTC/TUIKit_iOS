//
//  LoginView.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import SnapKit
import UIKit
import RTCCommon
import RTCRoomEngine
import ImSDK_Plus
import TUICore

protocol LoginViewDelegate: NSObjectProtocol {
    func loginDelegate(userId: String)
    func autoLoginSwitchChanged(isOn: Bool)
}

class LoginView: UIView {
    weak var delegate: LoginViewDelegate?
    
    private let logoContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        return view
    }()

    private let tencentCloudImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "tencent_cloud"))
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 32)
        label.textColor = UIColor(hex: "333333") ?? .black
        label.text = "Tencent Real-Time Communication".localized
        label.numberOfLines = 0
        return label
    }()

    private let userIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gray.cgColor
        return view
    }()

    private let userIdTextLable: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 20)
        label.textColor = UIColor.black
        label.text = "UserId"
        return label
    }()

    let userIdTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = UIColor.white
        textField.font = UIFont(name: "PingFangSC-Regular", size: 20)
        textField.textColor = UIColor(hex: "333333")
        textField.attributedPlaceholder = NSAttributedString(string: "userId")
        return textField
    }()
    
    private let autoLoginView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()
    
    private let autoLoginTitleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .black
        label.text = "Auto Login".localized
        return label
    }()
    
    private let autoLoginSwitch: UISwitch = {
        let switcher = UISwitch(frame: .zero)
        switcher.isOn = UserDefaults.standard.bool(forKey: "AutoLoginKey")
        return switcher
    }()

    private weak var currentTextField: UITextField?
    private let loginBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitle("Log In".localized, for: .normal)
        btn.adjustsImageWhenHighlighted = false
        btn.setBackgroundImage(UIColor(hex: "006EFF")?.trans2Image(), for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 20)
        btn.layer.shadowColor = UIColor(hex: "006EFF")?.cgColor ?? UIColor.blue.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 6)
        btn.layer.masksToBounds = true
        btn.layer.cornerRadius = 10
        return btn
    }()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if let current = currentTextField {
            current.resignFirstResponder()
            currentTextField = nil
        }
        UIView.animate(withDuration: 0.3) {
            self.transform = .identity
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    private func constructViewHierarchy() {
        addSubview(logoContentView)
        logoContentView.addSubview(tencentCloudImage)
        logoContentView.addSubview(titleLabel)
        addSubview(userIdContentView)
        userIdContentView.addSubview(userIdTextLable)
        userIdContentView.addSubview(userIdTextField)
        addSubview(loginBtn)
        addSubview(autoLoginView)
        autoLoginView.addSubview(autoLoginTitleLabel)
        autoLoginView.addSubview(autoLoginSwitch)
    }

    private func activateConstraints() {
        logoContentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100.scale375Height())
            make.leading.equalToSuperview().offset(40.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.height.equalTo(100.scale375Height())
        }
        tencentCloudImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.height.width.equalTo(80.scale375Width())
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(tencentCloudImage)
            make.leading.equalTo(tencentCloudImage.snp.trailing).offset(10.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
        }
        
        userIdContentView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20.scale375Width())
            make.height.equalTo(60.scale375Height())
        }
        
        userIdTextLable.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20.scale375Width())
        }
        
        userIdTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(userIdTextLable.snp.trailing).offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
        }
        
        loginBtn.snp.makeConstraints { make in
            make.top.equalTo(userIdContentView.snp.bottom).offset(40.scale375Height())
            make.leading.trailing.equalToSuperview().inset(20.scale375Width())
            make.height.equalTo(52.scale375Height())
        }
        
        autoLoginView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.top.equalTo(loginBtn.snp.bottom).offset(20.scale375Height())
            make.height.equalTo(44.scale375Height())
            make.width.greaterThanOrEqualTo(120.scale375Height())
        }
        
        autoLoginSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10.scale375Width())
            make.centerY.equalToSuperview()
        }
        
        autoLoginTitleLabel.snp.makeConstraints { make in
            make.trailing.equalTo(autoLoginSwitch.snp.leading).offset(-20.scale375Width())
            make.leading.centerY.equalToSuperview()
        }
    }

    private func bindInteraction() {
        loginBtn.addTarget(self, action: #selector(loginBtnClick), for: .touchUpInside)
        autoLoginSwitch.addTarget(self, action: #selector(onAutoLoginSwitchValueChanged), for: .valueChanged)
        userIdTextField.delegate = self
    }

    @objc private func loginBtnClick() {
        if let current = currentTextField {
            current.resignFirstResponder()
        }
        guard let userId = userIdTextField.text else {
            return
        }
        delegate?.loginDelegate(userId: userId)
    }
    
    @objc private func onAutoLoginSwitchValueChanged(_ switcher: UISwitch) {
        delegate?.autoLoginSwitchChanged(isOn: switcher.isOn)
    }
}

extension LoginView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let last = currentTextField {
            last.resignFirstResponder()
        }
        currentTextField = textField
        textField.becomeFirstResponder()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        currentTextField = nil
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        if string.isEmpty {
            return true
        }

        let allowedCharacters = 
        CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
}
