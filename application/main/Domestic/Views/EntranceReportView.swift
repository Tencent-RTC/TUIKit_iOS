//
//  EntranceReportView.swift
//  main
//

import UIKit
import SnapKit
import AtomicX

class EntranceReportView: UIView {

    var reportHandler: (() -> Void)?

    // MARK: - UI Elements

    private let reportLabel: UILabel = {
        let label = UILabel()
        let font = ThemeStore.shared.typographyTokens.Regular12

        let arrowImage = UIImage(named: "main_entrance_report_arrow") ?? UIImage()
        let attachment = NSTextAttachment(image: arrowImage)
        attachment.bounds = CGRect(
            x: 0,
            y: round(font.capHeight - arrowImage.size.height) / 2.0,
            width: arrowImage.size.width,
            height: arrowImage.size.height
        )

        let mutableAttrStr = NSMutableAttributedString(string: MainLocalize("Demo.TRTC.Portal.Main.Report"))
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
