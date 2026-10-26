import TUIChatKit
import SnapKit
import UIKit

internal final class ChatSecurityWarningView: UIView {
    internal var onClose: (() -> Void)?

    private static let leadingInset: CGFloat = 20
    private static let trailingInset: CGFloat = 17
    private static let verticalInset: CGFloat = 16
    private static let iconSize: CGFloat = 16
    private static let iconTextGap: CGFloat = 10
    private static let textCloseGap: CGFloat = 7
    private static let closeButtonSize: CGFloat = 22
    private static let warningFontSize: CGFloat = 14
    private static let textHeightTolerance: CGFloat = 0.5
    private static let reportURL = "https://cloud.tencent.com/act/event/report-platform"

    private let iconView = UIImageView()
    private let warningTextView = UITextView()
    private let closeButton = UIButton(type: .custom)
    private var textHeightConstraint: Constraint?
    private var currentTextHeight: CGFloat = 0

    internal override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    internal required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal override func layoutSubviews() {
        super.layoutSubviews()
        let textWidth = bounds.width - Self.leadingInset - Self.iconSize - Self.iconTextGap
            - Self.textCloseGap - Self.closeButtonSize - Self.trailingInset
        guard textWidth > 0 else { return }
        let fitting = warningTextView.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        guard abs(fitting.height - currentTextHeight) > Self.textHeightTolerance else { return }
        currentTextHeight = fitting.height
        textHeightConstraint?.update(offset: fitting.height)
    }

    private func constructViewHierarchy() {
        addSubview(iconView)
        addSubview(warningTextView)
        addSubview(closeButton)
    }

    private func activateConstraints() {
        let firstLineHeight = UIFont.systemFont(ofSize: Self.warningFontSize).lineHeight
        let iconTopOffset = Self.verticalInset + max(0, (firstLineHeight - Self.iconSize) / 2)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.leadingInset)
            make.top.equalToSuperview().offset(iconTopOffset)
            make.width.height.equalTo(Self.iconSize)
        }
        warningTextView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Self.iconTextGap)
            make.top.equalToSuperview().offset(Self.verticalInset)
            make.bottom.equalToSuperview().offset(-Self.verticalInset)
            make.trailing.equalTo(closeButton.snp.leading).offset(-Self.textCloseGap)
            textHeightConstraint = make.height.equalTo(0).constraint
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.trailingInset)
            make.top.equalToSuperview().offset(Self.verticalInset)
            make.width.height.equalTo(Self.closeButtonSize)
        }
    }

    private func setupViewStyle() {
        let colors = ThemeState.shared.colors
        backgroundColor = colors.toastColorWarning
        iconView.image = UIImage(named: "demo_ic_security_warning")?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = colors.textColorWarning
        iconView.contentMode = .scaleAspectFit
        closeButton.setImage(
            UIImage(named: "demo_ic_security_close")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        closeButton.tintColor = colors.textColorWarning
        closeButton.imageView?.contentMode = .scaleAspectFit
        warningTextView.isEditable = false
        warningTextView.isScrollEnabled = false
        warningTextView.backgroundColor = .clear
        warningTextView.textContainerInset = .zero
        warningTextView.textContainer.lineFragmentPadding = 0
        warningTextView.dataDetectorTypes = []
        warningTextView.linkTextAttributes = [.foregroundColor: colors.textColorLink]
        warningTextView.attributedText = makeWarningText()
    }

    private func bindInteraction() {
        warningTextView.delegate = self
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
    }

    private func makeWarningText() -> NSAttributedString {
        let colors = ThemeState.shared.colors
        let warning = LocalizedChatString("ChatSecurityWarning")
        let report = LocalizedChatString("ChatSecurityWarningReport")
        let text = NSMutableAttributedString(
            string: warning + " ",
            attributes: [
                .font: UIFont.systemFont(ofSize: Self.warningFontSize),
                .foregroundColor: colors.textColorWarning
            ]
        )
        text.append(NSAttributedString(
            string: report,
            attributes: [
                .font: UIFont.systemFont(ofSize: Self.warningFontSize),
                .foregroundColor: colors.textColorLink,
                .link: URL(string: Self.reportURL) as Any
            ]
        ))
        return text
    }

    @objc private func handleCloseTapped() {
        onClose?()
    }
}

extension ChatSecurityWarningView: UITextViewDelegate {
    internal func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }
}
