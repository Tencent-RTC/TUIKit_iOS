//
//  EntranceReportView.swift
//  main
//
//  举报提示横条 — 从旧版 EntranceReportView.swift 迁移
//
//  变更说明：
//    - 改为继承 UIView（旧版继承 UICollectionViewCell 但实际作为普通视图使用）
//    - addTapGesture 扩展改为直接使用 UITapGestureRecognizer
//    - 其他 UI 布局完全保持旧版不变
//

import UIKit
import SnapKit
import AtomicX

/// 举报提示横条
///
/// 仅在中文环境 + 非 MOA 用户时显示，点击后跳转腾讯云举报平台。
class EntranceReportView: UIView {

    /// 点击举报的回调
    var reportHandler: (() -> Void)?

    // MARK: - UI Elements

    private let reportLabel: UILabel = {
        let label = UILabel()
        let font = ThemeStore.shared.typographyTokens.Regular12

        // 将">"箭头添加到富文本中
        let arrowImage = UIImage(named: "main_entrance_report_arrow") ?? UIImage()
        let attachment = NSTextAttachment(image: arrowImage)
        // ">"垂直居中
        attachment.bounds = CGRect(
            x: 0,
            y: round(font.capHeight - arrowImage.size.height) / 2.0,
            width: arrowImage.size.width,
            height: arrowImage.size.height
        )

        let mutableAttrStr = NSMutableAttributedString(string: MainLocalize("main_report_hint"))
        let arrowImageAttr = NSAttributedString(attachment: attachment)
        mutableAttrStr.append(arrowImageAttr)

        label.attributedText = mutableAttrStr
        label.font = font
        label.numberOfLines = 0
        label.textColor = ThemeStore.shared.colorTokens.textColorError
        return label
    }()

    // MARK: - Lifecycle

    private var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true

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
            make.bottom.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(8)
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(clickReportEvent))
        addGestureRecognizer(tap)
    }

    // MARK: - Actions

    @objc private func clickReportEvent() {
        reportHandler?()
    }
}
