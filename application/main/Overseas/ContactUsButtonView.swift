//
//  ContactUsButtonView.swift
//  main
//

import UIKit
import SnapKit

class ContactUsButtonView: UIView {

    var contactBtnClickClosure: () -> Void = {}

    // MARK: - UI

    private lazy var consultBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(named: "main_entrance_contact"), for: .normal)
        return button
    }()

    // MARK: - Lifecycle

    private var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        addSubview(consultBtn)
    }

    private func activateConstraints() {
        consultBtn.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func bindInteraction() {
        consultBtn.addTarget(self, action: #selector(onConsultBtnClicked), for: .touchUpInside)
    }

    // MARK: - Action

    @objc private func onConsultBtnClicked() {
        contactBtnClickClosure()
    }
}
