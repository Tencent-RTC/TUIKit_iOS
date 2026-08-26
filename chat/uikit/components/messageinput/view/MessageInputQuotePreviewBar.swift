import UIKit
import SnapKit

final class MessageInputQuotePreviewBar: UIView {
    private static let senderNameFontSize: CGFloat = 13

    private static let summaryFontSize: CGFloat = 13

    private static let separatorHeight: CGFloat = 0.5

    private static let contentLeadingInset: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let contentTrailingGap: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let closeButtonSize: CGFloat = 32

    private static let closeButtonTitleFontSize: CGFloat = 20

    private static let closeButtonTrailingInset: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    var onClose: (() -> Void)?

    private let contentLabel = UILabel()

    private let closeButton = UIButton(type: .system)

    private let separatorLine = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(senderName: String, summary: String) {
        let colors = ChatUIKitTheme.colors
        let attributedText = NSMutableAttributedString()
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Self.senderNameFontSize, weight: .semibold),
            .foregroundColor: colors.textColorSecondary
        ]
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Self.summaryFontSize, weight: .regular),
            .foregroundColor: colors.textColorTertiary
        ]
        attributedText.append(NSAttributedString(string: senderName, attributes: nameAttributes))
        if !summary.isEmpty {
            attributedText.append(NSAttributedString(string: "：", attributes: nameAttributes))
            attributedText.append(NSAttributedString(string: summary, attributes: summaryAttributes))
        }
        contentLabel.attributedText = attributedText
    }

    private func constructViewHierarchy() {
        addSubview(separatorLine)
        addSubview(contentLabel)
        addSubview(closeButton)
    }

    private func activateConstraints() {
        separatorLine.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.separatorHeight)
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.closeButtonTrailingInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.closeButtonSize)
        }

        contentLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.contentLeadingInset)
            make.trailing.equalTo(closeButton.snp.leading).offset(-Self.contentTrailingGap)
            make.centerY.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorDefault
        clipsToBounds = true
        isHidden = true

        contentLabel.numberOfLines = 1
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.textAlignment = .natural

        separatorLine.backgroundColor = colors.strokeColorPrimary

        closeButton.setTitle("×", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: Self.closeButtonTitleFontSize)
        closeButton.setTitleColor(colors.textColorSecondary, for: .normal)
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
    }

    @objc private func handleCloseTapped() {
        onClose?()
    }
}
