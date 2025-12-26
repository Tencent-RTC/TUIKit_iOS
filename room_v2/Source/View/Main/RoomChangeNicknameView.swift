//
//  RoomChangeNicknameView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/27.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore

// MARK: - Protocol
protocol RoomChangeNicknameViewDelegate: AnyObject {
    func changeNickname(view: RoomChangeNicknameView, didConfirmName name: String)
}

// MARK: - RoomChangeNicknameView
class RoomChangeNicknameView: UIView, BasePanel, PanelHeightProvider {
    
    // MARK: - BasePanel Properties
    weak var parentView: UIView?
    var backgroundMaskView: PanelMaskView?
    
    // MARK: - PanelHeightProvider
    var panelHeight: CGFloat {
        return 60
    }
    
    weak var delegate: RoomChangeNicknameViewDelegate?
    
    // MARK: - Properties
    private let currentName: String
    private var lastValidKeyboardHeight: CGFloat = 0
    
    // MARK: - UI Components
    
    private lazy var inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        return view
    }()
    
    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .clear
        textField.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        textField.textColor = RoomColors.g7
        textField.returnKeyType = .done
        textField.delegate = self
        textField.attributedPlaceholder = NSAttributedString(
            string: .enterNickname,
            attributes: [
                .foregroundColor: RoomColors.g7.withAlphaComponent(0.5),
                .font: RoomFonts.pingFangSCFont(size: 12, weight: .regular)
            ]
        )
        return textField
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setTitle(.okTitle, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = RoomColors.b1d
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 14, weight: .bold)
        return button
    }()
    
    
    // MARK: - Initialization
    init(currentName: String) {
        self.currentName = currentName
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard superview != nil else { return }
        textField.becomeFirstResponder()
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        addSubview(inputContainerView)
        addSubview(confirmButton)
        inputContainerView.addSubview(textField)
    }
    
    private func setupConstraints() {
        inputContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.standard)
            make.right.equalTo(confirmButton.snp.left).offset(-RoomSpacing.medium)
            make.height.equalTo(36)
            make.centerY.equalToSuperview()
        }
        
        confirmButton.snp.makeConstraints { make in
            make.left.equalTo(inputContainerView.snp.right).offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.standard)
            make.centerY.equalTo(inputContainerView.snp.centerY)
            make.height.equalTo(36)
            make.width.equalTo(60)
        }
        
        textField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.medium)
            make.right.equalToSuperview().offset(-RoomSpacing.medium)
            make.centerY.equalToSuperview()
        }
    }
    
    private func setupStyles() {
        backgroundColor = RoomColors.g2
        inputContainerView.layer.cornerRadius = 18
        inputContainerView.layer.masksToBounds = true
        textField.text = currentName
        confirmButton.layer.cornerRadius = 18
    }
    
    private func setupBindings() {
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Deinitialization
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Action Handlers
extension RoomChangeNicknameView {
    @objc private func confirmButtonTapped() {
        guard let newName = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newName.isEmpty else {
            showToast(.enterNickname)
            return
        }
        
        delegate?.changeNickname(view: self, didConfirmName: newName)
        textField.resignFirstResponder()
        dismiss()
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardEndFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardEndFrame = keyboardEndFrameValue.cgRectValue
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) { [weak self] in
            guard let self = self else { return }
            transform = CGAffineTransform(translationX: 0, y: -keyboardEndFrame.height)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardEndFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) { [weak self] in
            guard let self = self else { return }
            transform = CGAffineTransform(translationX: 0, y: keyboardEndFrameValue.height)
            dismiss()
        } completion: { [weak self] _ in
            guard let self = self else { return }
            lastValidKeyboardHeight = 0
        }
    }
}

// MARK: - UITextFieldDelegate
extension RoomChangeNicknameView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        confirmButtonTapped()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 20
    }
}

fileprivate extension String {
    static let enterNickname = "Enter nickname".localized
    static let okTitle = "OK".localized
}
