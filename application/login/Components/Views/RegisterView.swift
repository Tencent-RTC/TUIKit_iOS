//
//  RegisterView.swift
//  login
//

import UIKit
import Kingfisher
import AtomicX

class RegisterView: UIView {
    
    // MARK: - Callbacks
    
    var onRegisterButtonTapped: ((_ nickName: String, _ avatarURL: String) -> Void)?
    var onHeadImageTapped: (() -> Void)?
    
    // MARK: - SubViews
    
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular20
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.text = LoginLocalize("Demo.TRTC.Login.regist")
        return label
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        label.text = LoginLocalize("Demo.TRTC.LoginMock.adduserinformationforfirstlogin")
        label.numberOfLines = 0
        return label
    }()
    
    lazy var headImageViewBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 50
        btn.clipsToBounds = true
        btn.adjustsImageWhenHighlighted = false
        return btn
    }()
    
    lazy var textField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        textField.font = ThemeStore.shared.typographyTokens.Regular16
        textField.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        textField.attributedPlaceholder = NSAttributedString(
            string: LoginLocalize("Demo.TRTC.LoginMock.fillinusernickname"),
            attributes: [
                .font: ThemeStore.shared.typographyTokens.Regular16,
                .foregroundColor: ThemeStore.shared.colorTokens.textColorDisable,
            ]
        )
        textField.delegate = self
        textField.text = nickNameArray.randomElement() ?? ""
        return textField
    }()
    
    lazy var textFieldSpacingLine: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = .darkGray
        label.text = LoginLocalize("Demo.TRTC.Login.limit20count")
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var footerLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textColor = ThemeStore.shared.colorTokens.textColorDisable
        label.text = LoginLocalize("Demo.TRTC.Login.modifyLaterInSettings")
        label.textAlignment = .center
        return label
    }()
    
    lazy var registBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitleColor(ThemeStore.shared.colorTokens.textColorButton, for: .normal)
        btn.setTitle(LoginLocalize("Demo.TRTC.Login.regist"), for: .normal)
        btn.adjustsImageWhenHighlighted = false
        btn.setBackgroundImage(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.trans2Image(), for: .normal)
        btn.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium18
        btn.layer.shadowColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 6)
        btn.layer.shadowRadius = 16
        btn.layer.shadowOpacity = 0.4
        btn.layer.masksToBounds = true
        btn.isEnabled = false
        return btn
    }()
    
    // MARK: - State
    
    private var selectedAvatarUrl: String?
    private var canUse = true
    private let enableColor = ThemeStore.shared.colorTokens.textColorDisable
    private let disableColor = ThemeStore.shared.colorTokens.textColorError
    
    private lazy var nickNameArray: [String] = {
        if let userModel = LoginManager.shared.getCurrentUser(),
           userModel.isMoa(),
           !userModel.name.isEmpty {
            return [userModel.name]
        }
        var datas = [String]()
        for i in 1..<34 {
            datas.append(LoginLocalize("Demo.TRTC.login_custom_name_\(i)"))
        }
        return datas
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChange(noti:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Lifecycle
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        registBtn.layer.cornerRadius = registBtn.frame.height * 0.5
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        textField.resignFirstResponder()
        UIView.animate(withDuration: 0.3) {
            self.transform = .identity
        }
        checkRegistBtnState()
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        initAvatar()
    }
    
    // MARK: - Public
    
    func setAvatarURL(_ url: String) {
        selectedAvatarUrl = url
        if let imageURL = URL(string: url) {
            headImageViewBtn.kf.setImage(with: .network(imageURL), for: .normal)
        }
    }
    
    // MARK: - UI Lifecycle Methods
    
    func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(headImageViewBtn)
        addSubview(textField)
        addSubview(textFieldSpacingLine)
        addSubview(descLabel)
        addSubview(registBtn)
        addSubview(footerLabel)
        checkRegistBtnState(textField.text?.count ?? -1)
    }
    
    func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(convertPixel(w: 40))
            make.top.equalToSuperview().offset(kDeviceSafeTopHeight + 10)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualToSuperview().offset(-convertPixel(w: 40))
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
        headImageViewBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(subtitleLabel.snp.bottom).offset(30)
            make.size.equalTo(CGSize(width: 100, height: 100))
        }
        textField.snp.makeConstraints { make in
            make.top.equalTo(headImageViewBtn.snp.bottom).offset(convertPixel(h: 40))
            make.leading.equalToSuperview().offset(convertPixel(w: 40))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 40))
            make.height.equalTo(convertPixel(h: 57))
        }
        textFieldSpacingLine.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalTo(textField)
            make.height.equalTo(1)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(convertPixel(w: 40))
            make.trailing.lessThanOrEqualToSuperview().offset(convertPixel(w: -40))
        }
        registBtn.snp.makeConstraints { make in
            make.top.equalTo(descLabel.snp.bottom).offset(convertPixel(h: 40))
            make.leading.equalToSuperview().offset(convertPixel(w: 20))
            make.trailing.equalToSuperview().offset(-convertPixel(w: 20))
            make.height.equalTo(convertPixel(h: 52))
        }
        footerLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(registBtn.snp.bottom).offset(12)
        }
    }
    
    func bindInteraction() {
        registBtn.addTarget(self, action: #selector(registBtnClick), for: .touchUpInside)
        headImageViewBtn.addTarget(self, action: #selector(headBtnClick), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func headBtnClick() {
        textField.resignFirstResponder()
        UIView.animate(withDuration: 0.3) {
            self.transform = .identity
        }
        onHeadImageTapped?()
    }
    
    @objc private func registBtnClick() {
        textField.resignFirstResponder()
        guard let name = textField.text, !name.isEmpty else { return }
        let avatarURL = selectedAvatarUrl ?? ""
        
        if let userModel = LoginManager.shared.getCurrentUser() {
            if !avatarURL.isEmpty {
                IMLogicRequest.synchronizUserInfo(currentUserModel: userModel,
                                                  avatar: avatarURL,
                                                  success: { _ in
                    debugPrint("set IM avatar and name success")
                }, failed: { code, message in
                    debugPrint("set IM avatar and name errorStr: \(message ?? ""), errorCode: \(code)")
                })
            } else {
                IMLogicRequest.synchronizUserInfo(currentUserModel: userModel, name: name, success: { _ in
                    debugPrint("set IM name success")
                }, failed: { code, message in
                    debugPrint("set IM name errorStr: \(message ?? ""), errorCode: \(code)")
                })
            }
        }
        
        onRegisterButtonTapped?(name, avatarURL)
    }
    
    // MARK: - Private
    
    private func initAvatar() {
        if let avatar = LoginManager.shared.getCurrentUser()?.avatar, !avatar.isEmpty,
           let url = URL(string: avatar) {
            headImageViewBtn.kf.setImage(with: .network(url), for: .normal)
            selectedAvatarUrl = avatar
        } else {
            let model = AvatarViewModel()
            let randomAvatar = model.avatarListDataSource[Int(arc4random()) % model.avatarListDataSource.count]
            if let url = URL(string: randomAvatar.url) {
                headImageViewBtn.kf.setImage(with: .network(url), for: .normal)
                selectedAvatarUrl = randomAvatar.url
            }
        }
    }
    
    @objc private func keyboardFrameChange(noti: Notification) {
        guard let info = noti.userInfo else { return }
        guard let value = info[UIResponder.keyboardFrameEndUserInfoKey], value is CGRect else { return }
        guard let superview = textField.superview else { return }
        let rect = value as! CGRect
        let converted = superview.convert(textField.frame, to: self)
        if rect.intersects(converted) {
            transform = CGAffineTransform(translationX: 0, y: -converted.maxY + rect.minY)
        }
    }
    
    func checkRegistBtnState(_ count: Int = -1) {
        var ctt = textField.text?.count ?? 0
        if count > -1 {
            ctt = count
        }
        registBtn.isEnabled = canUse && ctt > 0
    }
}

// MARK: - UITextFieldDelegate

extension RegisterView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.becomeFirstResponder()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        UIView.animate(withDuration: 0.3) {
            self.transform = .identity
        }
        checkRegistBtnState()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        checkRegistBtnState()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxCount = 20
        guard let textFieldText = textField.text,
              let rangeOfTextToReplace = Range(range, in: textFieldText) else {
            return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        let res = count <= maxCount
        if res {
            let newText = (textFieldText as NSString).replacingCharacters(in: range, with: string)
            checkAlertTitleLState(newText)
            checkRegistBtnState(count)
        }
        return res
    }
    
    private func checkAlertTitleLState(_ text: String = "") {
        if text.isEmpty {
            if let str = textField.text {
                canUse = validate(userName: str)
                descLabel.textColor = canUse ? enableColor : disableColor
            } else {
                canUse = false
                descLabel.textColor = disableColor
            }
        } else {
            canUse = validate(userName: text)
            descLabel.textColor = canUse ? enableColor : disableColor
        }
    }
    
    private func validate(userName: String) -> Bool {
        let reg = "^[a-z0-9A-Z\\u4e00-\\u9fa5\\_]{2,20}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", reg)
        return predicate.evaluate(with: userName)
    }
}
