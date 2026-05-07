//
//  PhoneInputView.swift
//  login
//

import UIKit
import AtomicX

class PhoneInputView: UIView {
    
    var onTextChanged: ((String) -> Void)?
    
    let defaultLocaleCode = "+86"
    
    lazy var countryCodeLabel: UILabel = {
        let label = UILabel()
        label.text = defaultLocaleCode
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = .darkGray
        return label
    }()
    
    private lazy var leftContainerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: convertPixel(w: 96), height: convertPixel(h: 24)))
        let iconView = UIImageView(frame: CGRect(x: 14, y: 0, width: 20, height: 20))
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage.loginImage(named: "login_phone")
        iconView.center.y = view.center.y
        view.addSubview(iconView)
        view.addSubview(countryCodeLabel)
        return view
    }()
    
    lazy var textField: LoginTextField = {
        let tf = LoginTextField(placeholder: LoginLocalize("V2.Live.LinkMicNew.enterphonenumber"))
        tf.keyboardType = .phonePad
        tf.layer.borderWidth = 1.0
        tf.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
        tf.layer.cornerRadius = 10.0
        tf.leftView = leftContainerView
        tf.leftViewMode = .always
        tf.delegate = self
        return tf
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
    
    func constructViewHierarchy() {
        addSubview(textField)
        leftContainerView.addSubview(countryCodeLabel)
    }
    
    func activateConstraints() {
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        countryCodeLabel.sizeToFit()
        updatePhoneAccountLeftView()
    }
    
    func updatePhoneAccountLeftView() {
        let buttonSize = countryCodeLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        countryCodeLabel.frame = CGRect(x: 40,
                                        y: (leftContainerView.frame.height - convertPixel(h: 24)) / 2,
                                        width: buttonSize.width,
                                        height: convertPixel(h: 24))
        var leftContainerFrame = leftContainerView.frame
        leftContainerFrame.size.width = 40 + buttonSize.width + 8.0
        leftContainerView.frame = leftContainerFrame
    }
}

extension PhoneInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxCount = 11
        guard let textFieldText = textField.text,
              let rangeOfTextToReplace = Range(range, in: textFieldText) else {
            return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        let res = count <= maxCount
        if res {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.onTextChanged?(textField.text ?? "")
            }
        }
        return res
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        onTextChanged?(textField.text ?? "")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
