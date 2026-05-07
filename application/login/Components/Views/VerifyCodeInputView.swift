//
//  VerifyCodeInputView.swift
//  login
//

import UIKit
import AtomicX

class VerifyCodeInputView: UIView {
    
    var onTextChanged: ((String) -> Void)?
    
    lazy var textField: LoginTextField = {
        let tf = LoginTextField(placeholder: LoginLocalize("V2.Live.LinkMicNew.enterverificationcode"))
        tf.keyboardType = .numberPad
        tf.layer.borderWidth = 1.0
        tf.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
        tf.layer.cornerRadius = 10.0
        tf.leftView = leftContainerView
        tf.leftViewMode = .always
        tf.delegate = self
        return tf
    }()
    
    lazy var getVerifyCodeButton: CountdownButton = {
        let button = CountdownButton()
        return button
    }()
    
    private lazy var leftContainerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: convertPixel(w: 42), height: convertPixel(h: 24)))
        let iconView = UIImageView(frame: CGRect(x: 14, y: 0, width: convertPixel(w: 20), height: convertPixel(h: 20)))
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage.loginImage(named: "login_safe")
        iconView.center.y = view.center.y
        view.addSubview(iconView)
        return view
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
        addSubview(getVerifyCodeButton)
    }
    
    func activateConstraints() {
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        getVerifyCodeButton.snp.makeConstraints { make in
            make.trailing.equalTo(textField).offset(convertPixel(w: -12))
            make.centerY.equalTo(textField)
        }
    }
}

extension VerifyCodeInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxCount = 6
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
}
