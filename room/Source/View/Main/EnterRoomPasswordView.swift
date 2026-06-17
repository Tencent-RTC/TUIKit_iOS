//
//  EnterRoomPasswordView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/5/14.
//

import UIKit

public class EnterRoomPasswordView: UIView {
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 8
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = .passwordTitle
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .bold)
        label.textColor = RoomColors.g2
        return label
    }()
   
    private let inputPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = .inputRoomPasswordTitle
        textField.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        textField.textColor = RoomColors.g2
        textField.isSecureTextEntry = true
        textField.keyboardType = .numberPad
        textField.layer.borderWidth = 1
        textField.layer.borderColor = RoomColors.b1.cgColor
        textField.layer.cornerRadius = 8
        textField.clipsToBounds = true
        textField.backgroundColor = .white
        textField.attributedPlaceholder = NSAttributedString(
            string: String.inputRoomPasswordTitle,
            attributes: [.foregroundColor: RoomColors.g6]
        )
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        textField.leftView = leftPadding
        textField.leftViewMode = .always
        textField.clearButtonMode = .never
        return textField
    }()
    
    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("room_password_close"), for: .normal)
        button.addTarget(self, action: #selector(clearPasswordText), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        button.isHidden = true
        return button
    }()

    private let cancelButton: HighlightButton = {
        let button = HighlightButton(highlightColor: RoomColors.g6.withAlphaComponent(0.1))
        button.setTitle(.cancelTitle, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        button.setTitleColor(RoomColors.aiRecordBorderColor, for: .normal)
        button.setTitleColor(RoomColors.aiRecordBorderColor.withAlphaComponent(0.5), for: .highlighted)
        return button
    }()

    private let joinRoomButton: HighlightButton = {
        let button = HighlightButton(highlightColor: RoomColors.b1.withAlphaComponent(0.1))
        button.setTitle(.joinRoomTitle, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        button.setTitleColor(RoomColors.b1d, for: .normal)
        button.setTitleColor(RoomColors.b1d.withAlphaComponent(0.5), for: .highlighted)
        return button
    }()
    
    private let separatorLine1: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.segmentTitleColor
        return view
    }()
    
    private let separatorLine2: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.segmentTitleColor
        return view
    }()
    
    private var onCancel: (() -> Void)
    private var onJoin: ((String?) -> Void)
    
    init(onCancel: @escaping () -> Void, onJoin: @escaping (String?) -> Void) {
        self.onCancel = onCancel
        self.onJoin = onJoin
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupBindings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(inputPasswordTextField)
        containerView.addSubview(separatorLine1)
        containerView.addSubview(cancelButton)
        containerView.addSubview(separatorLine2)
        containerView.addSubview(joinRoomButton)
        inputPasswordTextField.rightView = clearButton
        inputPasswordTextField.rightViewMode = .always
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
            make.trailing.equalToSuperview().offset(-40)
        }
       
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(25)
            make.centerX.equalToSuperview()
        }
        
        inputPasswordTextField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.height.equalTo(32)
        }
        
        separatorLine1.snp.makeConstraints { make in
            make.top.equalTo(inputPasswordTextField.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(separatorLine1.snp.bottom)
            make.height.equalTo(54)
            make.trailing.equalTo(separatorLine2.snp.leading)
            make.bottom.equalToSuperview()
        }
        
        separatorLine2.snp.makeConstraints { make in
            make.top.equalTo(separatorLine1.snp.bottom)
            make.width.equalTo(1)
            make.height.equalTo(54)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        joinRoomButton.snp.makeConstraints { make in
            make.top.equalTo(separatorLine1.snp.bottom)
            make.leading.equalTo(separatorLine2.snp.trailing)
            make.height.equalTo(54)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
    }
    
    private func setupBindings() {
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        joinRoomButton.addTarget(self, action: #selector(joinRoomButtonTapped), for: .touchUpInside)
        inputPasswordTextField.delegate = self
        inputPasswordTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss { [weak self] in
            guard let self = self else { return }
            onCancel()
        }
    }
    
    @objc private func joinRoomButtonTapped() {
        onJoin(inputPasswordTextField.text)
    }
    
    @objc private func clearPasswordText() {
        inputPasswordTextField.text = ""
        clearButton.isHidden = true
    }
    
    @objc private func textFieldDidChange() {
        let hasText = !(inputPasswordTextField.text?.isEmpty ?? true)
        clearButton.isHidden = !hasText
    }
    
    // MARK: - Show & Dismiss
    func show(in parentView: UIView) {
        parentView.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        parentView.layoutIfNeeded()
        
        backgroundColor = .clear
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.backgroundColor = .black.withAlphaComponent(0.8)
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        } completion: { _ in
            self.inputPasswordTextField.becomeFirstResponder()
        }
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        inputPasswordTextField.resignFirstResponder()
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.backgroundColor = .clear
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

extension EnterRoomPasswordView: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 6
    }
}

fileprivate extension String {
    static let passwordTitle = "roomkit_enter_room_password_title".localized
    static let cancelTitle = "roomkit_cancel".localized
    static let inputRoomPasswordTitle = "roomkit_please_input_room_password".localized
    static let joinRoomTitle = "roomkit_join_room".localized
}

private class HighlightButton: UIButton {
    private let highlightColor: UIColor
    
    init(highlightColor: UIColor) {
        self.highlightColor = highlightColor
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? highlightColor : .clear
        }
    }
}
