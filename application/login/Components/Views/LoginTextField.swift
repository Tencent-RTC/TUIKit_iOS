//
//  LoginTextField.swift
//  login
//
//  统一输入框样式（从旧版 TRTCLoginRootView.createTextField 提取）
//  圆角、字号、placeholder 颜色保持一致
//

import UIKit
import AtomicX

class LoginTextField: UITextField {
    
    init(placeholder: String) {
        super.init(frame: .zero)
        let tokens = ThemeStore.shared
        backgroundColor = tokens.colorTokens.bgColorOperate
        font = tokens.typographyTokens.Regular16
        textColor = tokens.colorTokens.textColorPrimary
        attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.font: tokens.typographyTokens.Regular16,
                NSAttributedString.Key.foregroundColor: tokens.colorTokens.textColorDisable,
            ]
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
