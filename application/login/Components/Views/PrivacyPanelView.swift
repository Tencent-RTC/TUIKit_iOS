//
//  PrivacyPanelView.swift
//  login
//

import UIKit
import AtomicX

class PrivacyPanelView: UIView {
    weak var rootVC: UIViewController?
    var onAgreeButtonClickedClosure: (() -> Void)?
    var onDismissClosure: (() -> Void)?
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var bgView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.textColorPrimary
        view.alpha = 0.7
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(4, forKey: kCIInputRadiusKey)
        view.layer.compositingFilter = blurFilter
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius12
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var titleLabelView: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Medium16
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.text = LoginLocalize("Demo.TRTC.Portal.readAndAgreeConditions")
        label.textAlignment = .center
        return label
    }()
    
    private lazy var descTextView: LoginAgreementTextView = {
        let textView = LoginAgreementTextView(frame: .zero, textContainer: nil)
        textView.delegate = self
        textView.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        textView.isEditable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link
        textView.textAlignment = .center
        
        let privaSummaryStr = LoginLocalize("Demo.TRTC.Portal.<privacysummary>")
        let privaStr = LoginLocalize("Demo.TRTC.Portal.<private>")
        let protoStr = LoginLocalize("Demo.TRTC.Portal.<agreement>")
        let totalStr = privaSummaryStr + privaStr + protoStr
        
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
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        attribute.addAttribute(.paragraphStyle, value: style, range: totalRange)
        
        attribute.addAttribute(.font, value: ThemeStore.shared.typographyTokens.Regular14, range: totalRange)
        
        attribute.addAttribute(.link, value: "privacySummary", range: privaSummaryRange)
        attribute.addAttribute(.link, value: "privacy", range: privaRange)
        attribute.addAttribute(.link, value: "protocol", range: protoRange)
        
        attribute.addAttribute(.foregroundColor, value: UIColor.blue, range: privaSummaryRange)
        attribute.addAttribute(.foregroundColor, value: UIColor.blue, range: privaRange)
        attribute.addAttribute(.foregroundColor, value: UIColor.blue, range: protoRange)
        textView.attributedText = attribute
        return textView
    }()
    
    private lazy var agreeButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.setTitle(LoginLocalize("Demo.TRTC.Portal.agreeAndContinue"), for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium16
        button.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius20
        button.layer.masksToBounds = true
        return button
    }()
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
}

//MARK: - Private
extension PrivacyPanelView {
    private func constructViewHierarchy() {
        addSubview(bgView)
        addSubview(contentView)
        contentView.addSubview(titleLabelView)
        contentView.addSubview(descTextView)
        contentView.addSubview(agreeButton)
    }
    
    private func activateConstraints() {
        bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(206)
        }
        
        titleLabelView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().inset(24)
            make.height.equalTo(24)
        }
        
        descTextView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabelView.snp.bottom).offset(24)
            make.height.lessThanOrEqualTo(40)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        agreeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(descTextView.snp.bottom).offset(24)
            make.width.equalTo(315)
            make.height.equalTo(40)
        }
    }
    
    private func bindInteraction() {
        agreeButton.addTarget(self, action: #selector(onAgreeBtnClicked), for: .touchUpInside)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bgViewTapped))
        bgView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func bgViewTapped() {
        dismiss()
    }
    
    @objc private func onAgreeBtnClicked() {
        onAgreeButtonClickedClosure?()
        dismiss()
    }
    
    private func dismiss() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            self.alpha = 0
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.onDismissClosure?()
            self.removeFromSuperview()
        }
    }
}

extension PrivacyPanelView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        if URL.absoluteString == "privacy" {
            LoginEntry.shared.privacyLinkHandler?("privacy", rootVC)
        } else if URL.absoluteString == "protocol" {
            LoginEntry.shared.privacyLinkHandler?("agreement", rootVC)
        } else if URL.absoluteString == "privacySummary" {
            LoginEntry.shared.privacyLinkHandler?("privacySummary", rootVC)
        }
        return true
    }
}
