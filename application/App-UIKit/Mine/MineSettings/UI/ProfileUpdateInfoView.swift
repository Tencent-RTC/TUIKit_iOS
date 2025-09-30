//
//  NicknameUpdateInfoView.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/18.
//

import UIKit
import SnapKit
import RTCCommon


class ProfileUpdateInfoView: UIView {

    var submitClosure: (String?)->Void = { newInfo in }
    private var oldInfo: String?
    
    private let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = ("Nickname").localized
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        return label
    }()
    
    private let intervalView:UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "E7ECF6")
        return view
    }()
    
    private let inputBackView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "F5F5F5")
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }()
    
    private let inputTextView: UITextField = {
        let view = UITextField()
        view.backgroundColor = .clear
        view.layer.masksToBounds = true
        return view
    }()
    
    private let inputLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        label.textColor = UIColor(hex: "4E5461")
        return label
    }()
    
    private lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 12)
        label.text = ("EditAliasDesc").localized
        label.textColor = UIColor(hex: "888888")
        return label
    }()
    
    private let submitButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIColor(hex: "1C66E5")?.trans2Image(), for: .normal)
        button.layer.shadowColor = UIColor(hex: "1C66E5")?.cgColor ?? UIColor.blue.cgColor
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.setTitle(("OK").localized, for: .normal)
        return button
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "mine_profilepop_close"), for: .normal)
        return button
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()
    
    private var isViewReady = false
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        observeKeyboardNotifications()
    }
    
    convenience init(oldInfo: String? = nil) {
        self.init()
        self.inputTextView.text = oldInfo
        self.tipsLabel.isHidden = false
        self.inputLabel.isHidden = true
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect(rect: self.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 12, height: 12))
    }
    
    private func constructViewHierarchy() {
        addSubview(backButton)
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(intervalView)
        containerView.addSubview(closeButton)
        containerView.addSubview(inputBackView)
        containerView.addSubview(tipsLabel)
        inputBackView.addSubview(inputLabel)
        inputBackView.addSubview(inputTextView)
        containerView.addSubview(submitButton)
    }
    
    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.height.equalTo(convertPixel(h: 237))
            make.bottom.left.right.equalToSuperview()
        }
        backButton.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(containerView.snp.top)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(convertPixel(h: 20))
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel)
            make.right.equalToSuperview().offset(convertPixel(w: -16))
            make.size.equalTo(CGSize(width: convertPixel(w: 20), height: convertPixel(h: 20)))
        }
        intervalView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(convertPixel(h: 60))
            make.width.equalToSuperview()
            make.height.equalTo(convertPixel(h: 1))
        }
        inputBackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(convertPixel(h: 78))
            make.centerX.equalToSuperview()
            make.left.equalToSuperview().offset(convertPixel(w: 16))
            make.height.equalTo(convertPixel(h: 40))
        }
        inputTextView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(convertPixel(w: 8))
            make.top.bottom.equalToSuperview()
        }
        inputLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(convertPixel(w: 12))
        }
        tipsLabel.snp.makeConstraints { make in
            make.leading.equalTo(inputBackView)
            make.top.equalTo(inputBackView.snp.bottom).offset(8)
        }
        submitButton.snp.makeConstraints { make in
            make.leading.trailing.equalTo(inputBackView)
            make.top.equalTo(inputBackView.snp.bottom).offset(convertPixel(h: 27))
            make.height.equalTo(convertPixel(h: 44))
        }
        
    }
    
    private func bindInteraction() {
        backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitClicked), for: .touchUpInside)
        inputTextView.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        inputTextView.delegate = self
    }
    
}

extension ProfileUpdateInfoView {
    @objc func closeButtonClicked () {
        self.removeFromSuperview()
    }
    
    @objc func submitClicked() {
        var newInfo: String?
        newInfo = inputTextView.text
        if oldInfo != newInfo {
            self.submitClosure(newInfo)
        } else {
           
        }
        self.removeFromSuperview()
    }
    
    @objc func show (in viewController: UIViewController) {
        self.frame = CGRect(x: 0,
                            y: 0,
                            width: screenWidth,
                            height: ScreenHeight)
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        viewController.view.window?.addSubview(self)
        viewController.view.window?.bringSubviewToFront(self)
    }
    @objc func textFieldDidChange(){
        checkSubmitButtonState()
    }
    
}

extension ProfileUpdateInfoView {
    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        containerView.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(-keyboardFrame.height)
        }
        UIView.animate(withDuration: duration) {
            self.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        containerView.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
        }
        UIView.animate(withDuration: duration) {
            self.layoutIfNeeded()
        }
    }
}

extension ProfileUpdateInfoView: UITextFieldDelegate {
    func checkSubmitButtonState(){
        submitButton.isEnabled = !(inputTextView.text?.isEmpty ?? true)
    }
    func textFieldDidBeginEditing(_ textField: UITextField) {
        checkSubmitButtonState()
    }
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        checkSubmitButtonState()
        return true
    }
}
