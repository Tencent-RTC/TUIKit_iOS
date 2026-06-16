//
//  FirstLaunchPrivacyAlertView.swift
//  login
//
//  首次启动隐私合规弹窗（对标旧版 LiteAVPrivacyAlertViewController）
//  全屏半透明遮罩 + 居中圆角卡片 + 可滚动详细隐私政策正文 + 底部同意/不同意按钮
//

import UIKit
import AtomicX

class FirstLaunchPrivacyAlertView: UIView {
    lazy var containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()
    lazy var bgView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        return view
    }()
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.text = LoginLocalize("login_home_welcome")
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    lazy var descTextView: LoginAgreementTextView = {
        let textView = LoginAgreementTextView(frame: .zero)
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.isEditable = false
        textView.showsVerticalScrollIndicator = true
        textView.linkTextAttributes = [.foregroundColor: UIColor.blue]
        textView.attributedText = buildPrivacyAttributedContent()
        return textView
    }()
    lazy var confirmBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(LoginLocalize("login_common_agree"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .blue
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return btn
    }()
    lazy var cancelBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(LoginLocalize("login_common_disagree"), for: .normal)
        btn.setTitleColor(ThemeStore.shared.colorTokens.textColorPrimary, for: .normal)
        btn.backgroundColor = .clear
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return btn
    }()
    lazy var lineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .lightGray
        return view
    }()

    var didClickCancelBtn: (() -> Void)?
    var didClickConfirmBtn: (() -> Void)?
    var didDismiss: (() -> Void)?

    weak var superVC: UIViewController?

    init(superVC: UIViewController, frame: CGRect = .zero) {
        self.superVC = superVC
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    func constructViewHierarchy() {
        addSubview(bgView)
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descTextView)
        containerView.addSubview(lineView)
        containerView.addSubview(cancelBtn)
        containerView.addSubview(confirmBtn)
    }
    func activateConstraints() {
        let alertHeight = UIScreen.main.bounds.height / 2.0

        bgView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        containerView.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(alertHeight)
        }
        titleLabel.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(15)
            make.centerX.equalToSuperview()
        }
        cancelBtn.snp.makeConstraints { (make) in
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(40)
        }
        confirmBtn.snp.makeConstraints { (make) in
            make.leading.equalTo(cancelBtn.snp.trailing)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(40)
            make.width.equalTo(cancelBtn.snp.width)
        }
        lineView.snp.makeConstraints { (make) in
            make.bottom.equalTo(cancelBtn.snp.top)
            make.height.equalTo(0.5)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        descTextView.snp.makeConstraints { (make) in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.bottom.equalTo(lineView.snp.top).offset(-10)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
        }
    }
    func bindInteraction() {
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        confirmBtn.addTarget(self, action: #selector(confirmBtnClick), for: .touchUpInside)
    }

    @objc func cancelBtnClick() {
        if let action = didClickCancelBtn {
            action()
        }
        dismiss()
    }

    @objc func confirmBtnClick() {
        if let action = didClickConfirmBtn {
            action()
        }
        dismiss()
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { (finish) in
            if let action = self.didDismiss {
                action()
            }
            self.removeFromSuperview()
        }
    }

    // MARK: - 构建隐私协议富文本内容

    private func buildPrivacyAttributedContent() -> NSAttributedString {
        let appName = LoginLocalize("login_home_welcome")
            .replacingOccurrences(of: "欢迎使用", with: "")
            .replacingOccurrences(of: "Welcome to Tencent Cloud ", with: "")
            .replacingOccurrences(of: "Tencent Cloud ", with: "")
            .replacingOccurrences(of: "へようこそ", with: "")
            .trimmingCharacters(in: .whitespaces)
        let appNameDisplay = appName.isEmpty ? "腾讯云音视频" : appName

        let privacySummaryTitle = LoginLocalize("login_privacy_summary_link")
        let dataCollectionTitle = LoginLocalize("login_privacy_data_collection_list")
        let thirdShareTitle = LoginLocalize("login_privacy_third_share_list")
        let privacyTitle = LoginLocalize("login_privacy_protection_guide")
        let agreementTitle = LoginLocalize("login_privacy_user_agreement")

        // 构建主内容（xcstrings 中占位符为 xxx/yyy/zzz/mmm/nnn）
        var content = LoginLocalize("login_privacy_alert_full_content")
            .replacingOccurrences(of: "xxx", with: appNameDisplay)
            .replacingOccurrences(of: "yyy", with: privacySummaryTitle)
            .replacingOccurrences(of: "zzz", with: dataCollectionTitle)
            .replacingOccurrences(of: "mmm", with: thirdShareTitle)
            .replacingOccurrences(of: "nnn", with: privacyTitle)

        // 恢复段落换行（工具生成 xcstrings 时将 \n 替换为空格，需手动恢复）
        content = restoreParagraphBreaks(content)

        // 构建同意后缀
        let agreeContent = LoginLocalize("login_privacy_alert_content_agree")
            .replacingOccurrences(of: "xxx", with: agreementTitle)
            .replacingOccurrences(of: "yyy", with: privacyTitle)
            .replacingOccurrences(of: "zzz", with: dataCollectionTitle)
            .replacingOccurrences(of: "mmm", with: thirdShareTitle)

        let fullContent = content + agreeContent
        let contentColor = ThemeStore.shared.colorTokens.textColorPrimary

        let contentAttributed = NSMutableAttributedString(string: fullContent, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: contentColor
        ])

        // 添加链接 - 隐私政策摘要
        addLink(to: contentAttributed, text: fullContent, linkText: privacySummaryTitle, urlValue: "privacySummary")

        // 添加链接 - 个人信息收集清单
        addLink(to: contentAttributed, text: fullContent, linkText: dataCollectionTitle, urlValue: "dataCollection", allOccurrences: true)

        // 添加链接 - 第三方信息共享清单
        addLink(to: contentAttributed, text: fullContent, linkText: thirdShareTitle, urlValue: "thirdShare", allOccurrences: true)

        // 添加链接 - 隐私保护指引
        addLink(to: contentAttributed, text: fullContent, linkText: privacyTitle, urlValue: "privacy", allOccurrences: true)

        // 添加链接 - 用户协议
        addLink(to: contentAttributed, text: fullContent, linkText: agreementTitle, urlValue: "protocol")

        return contentAttributed
    }

    /// 恢复段落换行
    ///
    /// xcstrings 工具将 CSV 中的 `\n` 转为空格，这里根据段落标记恢复换行。
    /// 支持中文 "N、" 和英文 "N." 两种编号格式。
    private func restoreParagraphBreaks(_ text: String) -> String {
        var result = text
        for i in 1...5 {
            // 中文格式: " 1、"
            let cnMarker = " \(i)、"
            if let range = result.range(of: cnMarker) {
                result = result.replacingCharacters(in: range, with: "\n\n\(i)、")
            }
            // 英文格式: " 1. " (注意需空格区分句号)
            let enMarker = " \(i). "
            if let range = result.range(of: enMarker) {
                result = result.replacingCharacters(in: range, with: "\n\n\(i). ")
            }
        }
        return result
    }

    /// 为富文本中的指定文本添加链接
    private func addLink(to attributed: NSMutableAttributedString,
                         text: String,
                         linkText: String,
                         urlValue: String,
                         allOccurrences: Bool = false) {
        guard !linkText.isEmpty else { return }
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(of: linkText, range: searchRange) {
            let nsRange = NSRange(range, in: text)
            attributed.addAttribute(.link, value: urlValue, range: nsRange)
            attributed.addAttribute(.foregroundColor, value: UIColor.blue, range: nsRange)

            if !allOccurrences { break }
            searchRange = range.upperBound..<text.endIndex
        }
    }
}

extension FirstLaunchPrivacyAlertView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        let linkType = URL.absoluteString
        switch linkType {
        case "privacy":
            LoginEntry.shared.privacyLinkHandler?("privacy", superVC)
        case "protocol":
            LoginEntry.shared.privacyLinkHandler?("agreement", superVC)
        case "privacySummary":
            LoginEntry.shared.privacyLinkHandler?("privacySummary", superVC)
        case "dataCollection":
            LoginEntry.shared.privacyLinkHandler?("dataCollection", superVC)
        case "thirdShare":
            LoginEntry.shared.privacyLinkHandler?("thirdShare", superVC)
        default:
            break
        }
        return false
    }
}
