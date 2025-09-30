//
//  RegisterView.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import UIKit
import Kingfisher
import TUICore

protocol RegisterViewDelegate: NSObjectProtocol {
    func registerDelegate(username: String)
}

class RegisterView: UIView {
    weak var delegate: RegisterViewDelegate?
    
    private let headImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 50
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var textField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = .white
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16)
        textField.textColor = UIColor.tui_color(withHex: "333333")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "PingFangSC-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.tui_color(withHex: "BBBBBB")
        ]
        textField.attributedPlaceholder = NSAttributedString(
            string: "Enter a userId".localized,
            attributes: attributes
        )
        textField.delegate = self
        return textField
    }()

    private let textFieldSpacingLine: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.tui_color(withHex: "EEEEEE")
        return view
    }()
    
    private let descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16)
        label.textColor = .darkGray
        label.text = "Chinese characters, letters, numbers and underscores, 1 – 20 words".localized
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private let registBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitle("Register".localized, for: .normal)
        btn.adjustsImageWhenHighlighted = false
        btn.setBackgroundImage(UIColor.tui_color(withHex: "006EFF").trans2Image(), for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 18)
        btn.layer.shadowColor = UIColor.tui_color(withHex: "006EFF").cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 6)
        btn.layer.shadowRadius = 16
        btn.layer.shadowOpacity = 0.4
        btn.layer.masksToBounds = true
        btn.isEnabled = false
        return btn
    }()
    
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameChange(noti:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func keyboardFrameChange(noti : Notification) {
        guard let info = noti.userInfo else {
            return
        }
        guard let value = info[UIResponder.keyboardFrameEndUserInfoKey], value is CGRect else {
            return
        }
        guard let superview = textField.superview else {
            return
        }
        let rect = value as! CGRect
        let converted = superview.convert(textField.frame, to: self)
        if rect.intersects(converted) {
            transform = CGAffineTransform(translationX: 0, y: -converted.maxY+rect.minY)
        }
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
        updateContent()
    }
    
    private func constructViewHierarchy() {
        addSubview(headImageView)
        addSubview(textField)
        addSubview(textFieldSpacingLine)
        addSubview(descLabel)
        addSubview(registBtn)
    }
    
    private func activateConstraints() {
        headImageView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(kDeviceSafeTopHeight + 70.scale375Height())
            make.size.equalTo(CGSize(width: 100.scale375Width(), height: 100.scale375Height()))
        }

        textField.snp.makeConstraints { (make) in
            make.top.equalTo(headImageView.snp_bottom).offset(40.scale375Height())
            make.leading.equalToSuperview().offset(40.scale375Width())
            make.trailing.equalToSuperview().offset(-40.scale375Width())
            make.height.equalTo(57.scale375Height())
        }

        textFieldSpacingLine.snp.makeConstraints { (make) in
            make.bottom.leading.trailing.equalTo(textField)
            make.height.equalTo(1.scale375Height())
        }

        descLabel.snp.makeConstraints { (make) in
            make.top.equalTo(textField.snp_bottom).offset(10.scale375Height())
            make.leading.equalToSuperview().offset(40.scale375Width())
            make.trailing.lessThanOrEqualToSuperview().offset(-40.scale375Width())
        }

        registBtn.snp.makeConstraints { (make) in
            make.top.equalTo(descLabel.snp_bottom).offset(40.scale375Height())
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.height.equalTo(52.scale375Height())
        }

    }
    
    private func bindInteraction() {
        registBtn.addTarget(self, action: #selector(registerBtnClick), for: .touchUpInside)
        TUICSToastManager.setDefaultPosition(TUICSToastPositionBottom)
    }
    
    private func updateContent() {
        let url = DEFAULT_AVATAR_REGISTER
        headImageView.kf.setImage(with: URL(string: url))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let superview = headImageView.superview else {
            return super.hitTest(point, with: event)
        }
        let rect = superview.convert(headImageView.frame, to: self)
        if rect.contains(point) {
            return headImageView
        }
        return super.hitTest(point, with: event)
    }
    
    @objc private func registerBtnClick() {
        textField.resignFirstResponder()
        guard let name = textField.text else { return }
        delegate?.registerDelegate(username: name)
    }
    
    private func checkRegistBtnState(_ count: Int = -1) {
        if count > -1 {
            registBtn.isEnabled = count > 0
        }
        else {
            registBtn.isEnabled = false
        }
    }
}

extension RegisterView : UITextFieldDelegate {
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
        return true
    }
    func textField(_ textField: UITextField, 
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let maxCount = 20
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
                return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        let result = count <= maxCount
        if result {
            checkRegistBtnState(count)
        }
        return result
    }
}
