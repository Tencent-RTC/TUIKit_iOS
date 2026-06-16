//
//  ContactUsTipsView.swift
//  main
//
//  "联系我们"提示视图 — 从 Tencent-RTC/MainViewController.swift 内部类迁移
//
//  变更说明：
//    - 从 MainViewController 内嵌类提取为独立文件
//    - 移除 `import RTCCommon` 依赖
//    - 其他 UI 布局完全保持旧版不变
//

import UIKit
import SnapKit
import AtomicX

/// 联系我们提示视图
///
/// 在 Discovery Lab Tab 顶部展示富文本"如有需求请 xxx 联系我们"，
/// 其中"联系我们"为蓝色可点击文字。
class ContactUsTipsView: UIView {

    /// 点击联系我们回调
    var contactUsHandler: () -> Void = {}

    // MARK: - UI Elements

    private let reportLabel: UILabel = {
        let label = UILabel()

        let replace = MainLocalize("main_overseas_contact_us")
        let descStr = MainLocalize("main_overseas_discovery_tips")

        let font = ThemeStore.shared.typographyTokens.Regular10
        let contactRange = (descStr as NSString).range(of: replace)
        let mutableAttrStr = NSMutableAttributedString(
            string: descStr,
            attributes: [.font: font, .foregroundColor: ThemeStore.shared.colorTokens.textColorSecondary]
        )
        mutableAttrStr.addAttribute(.foregroundColor,
                                    value: ThemeStore.shared.colorTokens.textColorLink,
                                    range: contactRange)
        label.attributedText = mutableAttrStr
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle

    private var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true

        backgroundColor = .clear
        isUserInteractionEnabled = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        addSubview(reportLabel)
    }

    private func activateConstraints() {
        reportLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.left.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-4)
            make.top.equalToSuperview().offset(4)
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(clickContactUs))
        isUserInteractionEnabled = true
        addGestureRecognizer(tap)
    }

    // MARK: - Action

    @objc private func clickContactUs() {
        contactUsHandler()
    }
}
