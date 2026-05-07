//
//  SafetyReminderView.swift
//  main
//

import UIKit
import SnapKit
import AtomicX

class SafetyReminderView: UIView {

    // MARK: - UI Elements

    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 15
        return view
    }()

    private let safeTitle: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("Demo.TRTC.Portal.Main.safetyReminderTitle")
        label.font = ThemeStore.shared.typographyTokens.Medium18
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()

    private let reminderContentScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.bounces = false
        return scrollView
    }()

    private let reminderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0

        let firstPara = MainLocalize("Demo.TRTC.Portal.Main.safetyReminderFirstPara") + "\n"
        let midPara = MainLocalize("Demo.TRTC.Portal.Main.safetyReminderMidPara") + "\n"
        let endPara = MainLocalize("Demo.TRTC.Portal.Main.safetyReminderEndPara") + "\n"
        let reminderText = firstPara + midPara + endPara

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5

        let regularFont = ThemeStore.shared.typographyTokens.Regular12
        let semiboldFont = ThemeStore.shared.typographyTokens.Bold12

        let regularAttr: [NSAttributedString.Key: Any] = [
            .font: regularFont,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: ThemeStore.shared.colorTokens.textColorPrimary,
        ]
        let attributedStr = NSMutableAttributedString(string: reminderText, attributes: regularAttr)

        let firstRange = NSRange(location: 0, length: firstPara.count)
        attributedStr.addAttribute(.font, value: semiboldFont, range: firstRange)

        let endRange = NSRange(location: firstPara.count + midPara.count, length: endPara.count)
        attributedStr.addAttribute(.font, value: semiboldFont, range: endRange)

        label.attributedText = attributedStr
        return label
    }()

    private let confirmButtonView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 18
        return view
    }()

    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.isEnabled = false
        return button
    }()

    private let buttonTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = ThemeStore.shared.colorTokens.textColorButtonDisabled
        return label
    }()

    // MARK: - Properties

    var confirmTimeCount: Int = 0 {
        didSet {
            buttonTitleLabel.text = MainLocalize("Demo.TRTC.Portal.Main.safetyReminderConfirm") + "(\(confirmTimeCount))"
        }
    }

    var clickConfirmBlock: () -> Void = {}
    private var isViewReady = false

    // MARK: - Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true

        backgroundColor = ThemeStore.shared.colorTokens.bgColorMask
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        configTimer()
        reminderContentScrollView.contentSize = CGSize(width: 268, height: reminderLabel.frame.height)
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        addSubview(contentView)
        contentView.addSubview(safeTitle)
        contentView.addSubview(reminderContentScrollView)
        reminderContentScrollView.addSubview(reminderLabel)
        contentView.addSubview(confirmButtonView)
        confirmButtonView.addSubview(buttonTitleLabel)
        confirmButtonView.insertSubview(confirmButton, at: 0)
    }

    private func activateConstraints() {
        contentView.snp.makeConstraints { make in
            make.height.equalTo(383)
            make.width.equalTo(300)
            make.center.equalToSuperview()
        }
        safeTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
        }
        reminderLabel.snp.makeConstraints { make in
            make.top.left.equalToSuperview()
            make.width.equalTo(268)
        }
        reminderLabel.layoutIfNeeded()
        buttonTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        confirmButtonView.snp.makeConstraints { make in
            make.height.equalTo(36)
            make.width.equalTo(120)
            make.bottom.equalToSuperview().offset(-20)
            make.centerX.equalToSuperview()
        }
        confirmButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        reminderContentScrollView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalTo(safeTitle.snp.bottom).offset(20)
            make.bottom.equalTo(confirmButtonView.snp.top).offset(-20)
        }
    }

    private func bindInteraction() {
        confirmButton.addTarget(self, action: #selector(confirmButtonClicked), for: .touchUpInside)
    }

    // MARK: - Timer

    private func configTimer() {
        var timeCount = confirmTimeCount
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if timeCount == 0 {
                timer.invalidate()
                self?.confirmButton.isEnabled = true
                self?.buttonTitleLabel.text = MainLocalize("Demo.TRTC.Portal.Main.safetyReminderConfirm")
                self?.buttonTitleLabel.textColor = ThemeStore.shared.colorTokens.textColorButton
                self?.confirmButtonView.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
            } else {
                timeCount -= 1
                self?.buttonTitleLabel.text =
                    MainLocalize("Demo.TRTC.Portal.Main.safetyReminderConfirm") + "(\(timeCount))"
            }
        }
    }

    func resetTimer(timeCount: Int = 5) {
        confirmTimeCount = timeCount
        confirmButtonView.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled
        buttonTitleLabel.textColor = ThemeStore.shared.colorTokens.textColorButtonDisabled
        confirmButton.isEnabled = false
        configTimer()
    }

    // MARK: - Actions

    @objc private func confirmButtonClicked() {
        clickConfirmBlock()
    }
}
