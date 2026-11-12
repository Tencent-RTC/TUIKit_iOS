import SnapKit
import UIKit

final class LightSheetHeader: UIView {

    var onClose: (() -> Void)? {
        didSet { closeButton.isHidden = onClose == nil }
    }

    var onAction: (() -> Void)? {
        didSet { actionButton.isHidden = onAction == nil }
    }

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .custom)
    private let actionButton = UIButton(type: .custom)

    init(title: String) {
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = CallKitTheme.sheetText
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        closeButton.isHidden = true
        closeButton.setTitle("×", for: .normal)
        closeButton.setTitleColor(CallKitTheme.sheetText2, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 14)
        closeButton.backgroundColor = CallKitTheme.sheetGrey
        closeButton.layer.cornerRadius = 13
        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(26)
        }

        actionButton.isHidden = true
        actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        actionButton.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        let border = UIView()
        border.backgroundColor = CallKitTheme.sheetLine
        addSubview(border)
        border.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        snp.makeConstraints { make in
            make.height.equalTo(52)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActionTitle(_ title: String, isCancel: Bool) {
        actionButton.setTitle(title, for: .normal)
        actionButton.setTitleColor(isCancel ? CallKitTheme.callRed : CallKitTheme.brand, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: isCancel ? .regular : .semibold)
    }

    func setActionEnabled(_ enabled: Bool) {
        actionButton.isEnabled = enabled
    }

    @objc private func handleCloseTap() {
        onClose?()
    }

    @objc private func handleActionTap() {
        onAction?()
    }
}
