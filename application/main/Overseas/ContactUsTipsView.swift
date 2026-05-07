//
//  ContactUsTipsView.swift
//  main
//

import UIKit
import SnapKit
import AtomicX

class ContactUsTipsView: UIView {

    var contactUsHandler: () -> Void = {}

    // MARK: - UI Elements

    private let reportLabel: UILabel = {
        let label = UILabel()

        let replace = MainLocalize("Demo.TRTC.Portal.Main.contactUs")
        let descStr = MainLocalize("Demo.TRTC.Portal.Main.contactUsxxx", replace)

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
