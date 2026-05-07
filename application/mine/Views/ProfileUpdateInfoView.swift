//
//  ProfileUpdateInfoView.swift
//  mine
//

import UIKit
import AtomicX
import SnapKit

private class CustomRefreshButton: UIButton {
    var isViewReady = false
    override func didMoveToWindow() {
        guard !isViewReady else { return }
        isViewReady = true
        super.didMoveToWindow()
        let imageWidth: CGFloat = 12.5
        let imageHeight: CGFloat = 12.5
        let imageX: CGFloat = 0
        let imageY: CGFloat = (bounds.height - imageHeight) / 2
        imageView?.frame = CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
        let titleX: CGFloat = bounds.width - (titleLabel?.bounds.width ?? 0)
        let titleY: CGFloat = (bounds.height - (titleLabel?.bounds.height ?? 0)) / 2
        titleLabel?.frame = CGRect(x: titleX, y: titleY, width: titleLabel?.bounds.width ?? 0, height: titleLabel?.bounds.height ?? 0)
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title, for: state)
        sizeToFit()
    }

    override func setImage(_ image: UIImage?, for state: UIControl.State) {
        super.setImage(image, for: state)
        sizeToFit()
    }
}

enum UpdateInfoViewType {
    case noInput
    case hasInput
}

class ProfileUpdateInfoView: UIView {

    var submitClosure: (String?) -> Void = { _ in }
    var viewType: UpdateInfoViewType?
    var oldInfo: String?
    
    lazy var containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = MineLocalize("Demo.TRTC.Portal.Mine.profileName")
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    
    lazy var intervalView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorPrimary
        return view
    }()
    
    lazy var inputBackView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius8
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var inputTextView: UITextField = {
        let view = UITextField()
        view.delegate = self
        view.backgroundColor = .clear
        view.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        view.font = ThemeStore.shared.typographyTokens.Regular16
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var inputLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        return label
    }()
    
    lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.text = MineLocalize("Demo.TRTC.Portal.Mine.profileEditAliasDesc")
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        return label
    }()
    
    let submitButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.trans2Image(), for: .normal)
        button.layer.shadowColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius8
        button.layer.masksToBounds = true
        button.setTitle(MineLocalize("Demo.TRTC.Portal.Mine.profileOK"), for: .normal)
        return button
    }()
    
    let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "mine_profilepop_close"), for: .normal)
        return button
    }()
    
    let backButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()
    
    private let randomButton: CustomRefreshButton = {
        let button = CustomRefreshButton(type: .system)
        button.setTitle(MineLocalize("Demo.TRTC.Portal.Mine.profileRandom"), for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Regular14
        button.setTitleColor(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault, for: .normal)
        button.setImage(UIImage(named: "mine_profile_refresh"), for: .normal)
        button.sizeToFit()
        button.isEnabled = true
        return button
    }()
    
    var isViewReady = false
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        observeKeyboardNotifications()
    }
    
    convenience init(viewType: UpdateInfoViewType, oldInfo: String? = nil) {
        self.init()
        self.viewType = viewType
        self.oldInfo = oldInfo
        let hasInputTextField = (viewType == .hasInput)
        if hasInputTextField {
            self.inputTextView.text = oldInfo
        } else {
            self.inputLabel.text = oldInfo
        }
        self.tipsLabel.isHidden = !hasInputTextField
        self.randomButton.isHidden = hasInputTextField
        self.inputLabel.isHidden = hasInputTextField
        self.inputTextView.isHidden = !hasInputTextField
        self.submitButton.isEnabled = !hasInputTextField
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect(rect: self.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 12, height: 12))
    }
    
    func constructViewHierarchy() {
        addSubview(backButton)
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(intervalView)
        containerView.addSubview(closeButton)
        containerView.addSubview(inputBackView)
        containerView.addSubview(tipsLabel)
        inputBackView.addSubview(inputLabel)
        inputBackView.addSubview(inputTextView)
        inputBackView.addSubview(randomButton)
        containerView.addSubview(submitButton)
    }
    
    func activateConstraints() {
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
        randomButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(convertPixel(w: -12))
            make.centerY.equalToSuperview()
        }
        submitButton.snp.makeConstraints { make in
            make.leading.trailing.equalTo(inputBackView)
            make.top.equalTo(inputBackView.snp.bottom).offset(convertPixel(h: 27))
            make.height.equalTo(convertPixel(h: 44))
        }
    }
    
    func bindInteraction() {
        backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        randomButton.addTarget(self, action: #selector(randomClicked), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitClicked), for: .touchUpInside)
        inputTextView.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
}

// MARK: - Actions

extension ProfileUpdateInfoView {
    @objc func closeButtonClicked() {
        self.removeFromSuperview()
    }
    
    @objc func randomClicked() {
        self.inputLabel.text = getRandomName()
    }
    
    @objc func submitClicked() {
        var newInfo: String?
        if viewType == .hasInput {
            newInfo = inputTextView.text
        } else {
            newInfo = inputLabel.text
        }
        if oldInfo != newInfo {
            self.submitClosure(newInfo)
        }
        self.removeFromSuperview()
    }
    
    @objc func show(in viewController: UIViewController) {
        self.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: ScreenHeight)
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        viewController.view.window?.addSubview(self)
        viewController.view.window?.bringSubviewToFront(self)
    }
    
    @objc func textFieldDidChange() {
        checkSubmitButtonState()
    }
}

// MARK: - Random Name

extension ProfileUpdateInfoView {
    func getRandomName() -> String {
        let randomNumber = Int.random(in: 1...33)
        return BundleLoader.moduleLocalized(key: "Demo.TRTC.login_custom_name_\(randomNumber)", in: Bundle.main, tableName: "LoginLocalized")
    }
}

// MARK: - Keyboard

extension ProfileUpdateInfoView {
    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
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

// MARK: - UITextFieldDelegate

extension ProfileUpdateInfoView: UITextFieldDelegate {
    func checkSubmitButtonState() {
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
