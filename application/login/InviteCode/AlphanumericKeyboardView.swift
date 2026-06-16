//
//  AlphanumericKeyboardView.swift
//  login
//
//  仿系统键盘风格的自定义字母数字键盘
//  用于邀请码输入，避免多 TextField 切换焦点时键盘面板重置
//

import UIKit
import AtomicX

class AlphanumericKeyboardView: UIView {
    
    // MARK: - Callbacks
    
    var onKeyTapped: ((String) -> Void)?
    var onDeleteTapped: (() -> Void)?
    
    // MARK: - Constants
    
    /// 键盘行定义：数字行 + 三行字母（与系统 QWERTY 布局一致）
    private let rows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]
    
    // 仿系统键盘配色
    private let keyboardBackgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
    private let keyBackgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
    private let keyTextColor = ThemeStore.shared.colorTokens.textColorPrimary
    private let specialKeyBackgroundColor = ThemeStore.shared.colorTokens.buttonColorSecondaryDefault
    private let keyShadowColor = ThemeStore.shared.colorTokens.shadowColor
    
    private let keyCornerRadius: CGFloat = 5
    private let keySpacingH: CGFloat = 6
    private let keySpacingV: CGFloat = 11
    private let keyHeight: CGFloat = 42
    private let sideInset: CGFloat = 3
    private let topInset: CGFloat = 8
    private let bottomInsetAboveKeys: CGFloat = 4
    
    // MARK: - UI
    
    private var rowStackViews: [UIStackView] = []
    private var deleteButton: UIButton?
    /// 记录上一次计算的高度，避免重复触发 invalidateIntrinsicContentSize
    private var lastCalculatedHeight: CGFloat = 0
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = keyboardBackgroundColor
        setupKeys()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Intrinsic Size
    
    /// 键盘内容区域高度（不含 safe area）
    private var keysAreaHeight: CGFloat {
        return topInset + keyHeight * CGFloat(rows.count) + keySpacingV * CGFloat(rows.count - 1) + bottomInsetAboveKeys
    }
    
    override var intrinsicContentSize: CGSize {
        // 加上底部安全区域高度，避免刘海屏 Home Indicator 遮挡按键
        let safeBottom = safeAreaInsets.bottom
        let totalHeight = keysAreaHeight + safeBottom
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        // safe area 变化时（如旋转屏幕）重新计算高度
        let newHeight = keysAreaHeight + safeAreaInsets.bottom
        if newHeight != lastCalculatedHeight {
            lastCalculatedHeight = newHeight
            invalidateIntrinsicContentSize()
        }
    }
    
    // MARK: - Setup
    
    private func setupKeys() {
        let containerStack = UIStackView()
        containerStack.axis = .vertical
        containerStack.spacing = keySpacingV
        containerStack.alignment = .center
        addSubview(containerStack)
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sideInset),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sideInset),
        ])
        
        for (rowIndex, row) in rows.enumerated() {
            if rowIndex == rows.count - 1 {
                // 最后一行（Z-M）需要特殊处理：左侧留空，右侧放删除键
                let rowContainer = UIView()
                rowContainer.translatesAutoresizingMaskIntoConstraints = false
                containerStack.addArrangedSubview(rowContainer)
                rowContainer.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
                rowContainer.heightAnchor.constraint(equalToConstant: keyHeight).isActive = true
                
                // 字母键 StackView
                let letterStack = UIStackView()
                letterStack.axis = .horizontal
                letterStack.spacing = keySpacingH
                letterStack.distribution = .fillEqually
                rowContainer.addSubview(letterStack)
                
                for key in row {
                    let button = createKeyButton(title: key, isSpecial: false)
                    letterStack.addArrangedSubview(button)
                }
                
                // 删除键
                let delButton = createDeleteButton()
                rowContainer.addSubview(delButton)
                self.deleteButton = delButton
                
                letterStack.translatesAutoresizingMaskIntoConstraints = false
                delButton.translatesAutoresizingMaskIntoConstraints = false
                
                // 删除键宽度与系统键盘一致（约为普通键的 1.5 倍）
                NSLayoutConstraint.activate([
                    delButton.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
                    delButton.topAnchor.constraint(equalTo: rowContainer.topAnchor),
                    delButton.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
                    delButton.widthAnchor.constraint(equalTo: rowContainer.widthAnchor, multiplier: 0.115),
                    
                    letterStack.centerXAnchor.constraint(equalTo: rowContainer.centerXAnchor, constant: -20),
                    letterStack.topAnchor.constraint(equalTo: rowContainer.topAnchor),
                    letterStack.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
                ])
                
                // 字母键总宽度 = 7 个键 + 6 个间距，约占屏幕宽度的 70%
                letterStack.widthAnchor.constraint(equalTo: rowContainer.widthAnchor, multiplier: 0.72).isActive = true
                
            } else {
                let rowStack = UIStackView()
                rowStack.axis = .horizontal
                rowStack.spacing = keySpacingH
                rowStack.distribution = .fillEqually
                
                for key in row {
                    let button = createKeyButton(title: key, isSpecial: false)
                    rowStack.addArrangedSubview(button)
                }
                
                containerStack.addArrangedSubview(rowStack)
                rowStack.translatesAutoresizingMaskIntoConstraints = false
                rowStack.heightAnchor.constraint(equalToConstant: keyHeight).isActive = true
                
                if rowIndex == 0 || rowIndex == 1 {
                    // 数字行和第一行字母（QWERTY）：占满宽度
                    rowStack.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
                } else if rowIndex == 2 {
                    // 第二行字母（ASDF）：两侧缩进，与系统键盘一致
                    rowStack.widthAnchor.constraint(equalTo: containerStack.widthAnchor, multiplier: 0.885).isActive = true
                }
                
                rowStackViews.append(rowStack)
            }
        }
    }
    
    // MARK: - Key Creation
    
    private func createKeyButton(title: String, isSpecial: Bool) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(keyTextColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: title.count == 1 && title.first?.isLetter == true ? 22.5 : 20, weight: .regular)
        button.backgroundColor = isSpecial ? specialKeyBackgroundColor : keyBackgroundColor
        button.layer.cornerRadius = keyCornerRadius
        button.layer.shadowColor = keyShadowColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 1.0
        button.layer.shadowRadius = 0
        button.layer.masksToBounds = false
        
        button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    private func createDeleteButton() -> UIButton {
        let button = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let image = UIImage(systemName: "delete.backward", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = keyTextColor
        button.backgroundColor = specialKeyBackgroundColor
        button.layer.cornerRadius = keyCornerRadius
        button.layer.shadowColor = keyShadowColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 1.0
        button.layer.shadowRadius = 0
        button.layer.masksToBounds = false
        
        button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        
        return button
    }
    
    // MARK: - Actions
    
    @objc private func keyTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        onKeyTapped?(title)
    }
    
    @objc private func deleteTapped() {
        onDeleteTapped?()
    }
    
    // MARK: - Touch Feedback（仿系统键盘按下变暗效果）
    
    @objc private func keyTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) {
            sender.backgroundColor = sender.backgroundColor == self.specialKeyBackgroundColor
                ? self.specialKeyBackgroundColor.withAlphaComponent(0.6)
                : ThemeStore.shared.colorTokens.bgColorDefault
        }
    }
    
    @objc private func keyTouchUp(_ sender: UIButton) {
        let isSpecial = (sender == self.deleteButton)
        UIView.animate(withDuration: 0.15) {
            sender.backgroundColor = isSpecial ? self.specialKeyBackgroundColor : self.keyBackgroundColor
        }
    }
}
