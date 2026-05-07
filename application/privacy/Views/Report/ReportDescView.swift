//
//  ReportDescView.swift
//  privacy
//

import Foundation
import UIKit
import RTCCommon
import SnapKit

class ReportDescView: UIView {

    private lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = PrivacyLocalize("Privacy.Report.description")
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor(hex: "888888") ?? UIColor.lightText
        return label
    }()

    lazy var textView: UITextView = {
        let view = UITextView(frame: .zero)
        view.textColor = UIColor(hex: "BBBBBB")
        view.font = UIFont.systemFont(ofSize: 12)
        view.layer.borderWidth = 1.0
        view.layer.borderColor = (UIColor(hex: "EEEEEE") ?? UIColor.lightText).cgColor
        view.text = PrivacyLocalize("Privacy.Report.description.placeholder")
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChange(noti:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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

// MARK: - UI Layout

extension ReportDescView {

    private func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(textView)
    }

    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.top.equalTo(0)
        }
        textView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(122)
            make.bottom.equalTo(-20)
        }
    }

    private func bindInteraction() {
        textView.delegate = self
    }
}

// MARK: - UITextViewDelegate

extension ReportDescView: UITextViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if textView.text == PrivacyLocalize("Privacy.Report.description.placeholder") {
            textView.text = ""
            textView.textColor = .black
        }
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = PrivacyLocalize("Privacy.Report.description.placeholder")
            textView.textColor = UIColor(hex: "BBBBBB")
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        textView.text = textView.text.subString(toByteLength: 150)
    }
}

// MARK: - Keyboard

extension ReportDescView {
    @objc
    func keyboardFrameChange(noti: Notification) {
        guard let info = noti.userInfo else { return }
        guard let value = info[UIResponder.keyboardFrameEndUserInfoKey], value is CGRect else { return }
        let rect = value as! CGRect
        if rect.minY == UIScreen.main.bounds.height {
            superview?.transform = .identity
        } else {
            let textRect = textView.convert(textView.frame, to: nil)
            superview?.transform = CGAffineTransform(translationX: 0, y: -(textRect.maxY - rect.minY))
        }
    }
}
