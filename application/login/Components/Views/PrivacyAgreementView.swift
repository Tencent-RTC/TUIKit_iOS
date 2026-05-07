//
//  PrivacyAgreementView.swift
//  login
//

import UIKit
import AtomicX

class AgreementButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if (bounds.size.width <= 16) && (bounds.size.height <= 16) {
            let expandSize: CGFloat = 16.0
            let x = bounds.origin.x - expandSize
            let y = bounds.origin.y - expandSize
            let width = bounds.size.width + 2 * expandSize
            let height = bounds.size.height + 2 * expandSize
            let buttonRect = CGRect(x: x, y: y, width: width, height: height)
            return buttonRect.contains(point)
        } else {
            return super.point(inside: point, with: event)
        }
    }
}

class LoginAgreementTextView: UITextView {
    override var canBecomeFirstResponder: Bool {
        return false
    }
}

// MARK: - PrivacyAgreementView

class PrivacyAgreementView: UIView {
    
    weak var hostViewController: UIViewController?
    
    var isAgreed: Bool {
        return agreementButton.isSelected
    }
    
    lazy var agreementButton: AgreementButton = {
        let button = AgreementButton(type: .custom)
        button.setImage(UIImage.loginImage(named: "checkbox_nor"), for: .normal)
        button.setImage(UIImage.loginImage(named: "checkbox_sel"), for: .selected)
        button.sizeToFit()
        button.imageView?.contentMode = .scaleAspectFill
        return button
    }()
    
    lazy var agreementTextView: LoginAgreementTextView = {
        let textView = LoginAgreementTextView(frame: .zero, textContainer: nil)
        textView.delegate = self
        textView.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        textView.isEditable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link
        textView.textAlignment = .left
        let totalStr = LoginLocalize("Demo.TRTC.Portal.privateandagreement",
                                     LoginLocalize("Demo.TRTC.Portal.<privacysummary>"),
                                     LoginLocalize("Demo.TRTC.Portal.<private>"),
                                     LoginLocalize("Demo.TRTC.Portal.<agreement>"))
        
        let privaSummaryStr = LoginLocalize("Demo.TRTC.Portal.<privacysummary>")
        let privaStr = LoginLocalize("Demo.TRTC.Portal.<private>")
        let protoStr = LoginLocalize("Demo.TRTC.Portal.<agreement>")
        
        guard let privaR = totalStr.range(of: privaStr),
              let protoR = totalStr.range(of: protoStr),
              let privaSummaryR = totalStr.range(of: privaSummaryStr) else {
            return textView
        }
        
        let totalRange = NSRange(location: 0, length: totalStr.count)
        let privaSummaryRange = NSRange(privaSummaryR, in: totalStr)
        let privaRange = NSRange(privaR, in: totalStr)
        let protoRange = NSRange(protoR, in: totalStr)
        
        let attribute = NSMutableAttributedString(string: totalStr)
        
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping
        attribute.addAttribute(.paragraphStyle, value: style, range: totalRange)
        
        attribute.addAttribute(.font, value: ThemeStore.shared.typographyTokens.Regular14, range: totalRange)
        attribute.addAttribute(.foregroundColor, value: UIColor.lightGray, range: totalRange)
        
        attribute.addAttribute(.link, value: "privacySummary", range: privaSummaryRange)
        attribute.addAttribute(.link, value: "privacy", range: privaRange)
        attribute.addAttribute(.link, value: "protocol", range: protoRange)
        
        attribute.addAttribute(.foregroundColor, value: UIColor.blue, range: privaSummaryRange)
        attribute.addAttribute(.foregroundColor, value: UIColor.blue, range: privaRange)
        attribute.addAttribute(.foregroundColor, value: UIColor.blue, range: protoRange)
        textView.attributedText = attribute
        return textView
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
        bindInteraction()
        isViewReady = true
    }
    
    func constructViewHierarchy() {
        addSubview(agreementButton)
        addSubview(agreementTextView)
        bringSubviewToFront(agreementButton)
    }
    
    func activateConstraints() {
        agreementButton.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.size.equalTo(CGSize(width: 16, height: 16))
        }
        agreementTextView.snp.makeConstraints { make in
            make.leading.equalTo(agreementButton.snp.trailing).offset(8)
            make.top.equalTo(agreementButton).offset(convertPixel(h: -1))
            make.trailing.equalToSuperview()
            make.height.equalTo(convertPixel(h: 40))
        }
    }
    
    func bindInteraction() {
        agreementButton.addTarget(self, action: #selector(agreementCheckboxBtnClick), for: .touchUpInside)
    }
    
    @objc private func agreementCheckboxBtnClick() {
        agreementButton.isSelected = !agreementButton.isSelected
    }
    
    func setAgreed(_ agreed: Bool) {
        agreementButton.isSelected = agreed
    }
}

// MARK: - UITextViewDelegate

extension PrivacyAgreementView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        if URL.absoluteString == "privacy" {
            LoginEntry.shared.privacyLinkHandler?("privacy", hostViewController)
        } else if URL.absoluteString == "protocol" {
            LoginEntry.shared.privacyLinkHandler?("agreement", hostViewController)
        } else if URL.absoluteString == "privacySummary" {
            LoginEntry.shared.privacyLinkHandler?("privacySummary", hostViewController)
        }
        return true
    }
}
