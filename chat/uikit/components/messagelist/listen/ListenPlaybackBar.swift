import UIKit
import SnapKit

final class ListenPlaybackBar: UIView {
    var onClose: (() -> Void)?

    private static let rowHeight: CGFloat = 36

    private static let maxExpandedWidth: CGFloat = 320

    private static let horizontalPadding: CGFloat = 10

    private static let iconSize: CGFloat = 20

    private static let textIconSpacing = CGFloat(SpacingScheme.smallSpacing)

    private static let closeWidth: CGFloat = 36

    private static let textFontSize: CGFloat = 13

    private static let borderWidth: CGFloat = 0.5

    private static let shadowOpacity: Float = 0.15

    private static let shadowRadius: CGFloat = 4

    private static let shadowOffset = CGSize(width: 0, height: 2)

    private static let expandAnimationDuration: TimeInterval = 0.2

    private let iconImageView = UIImageView()

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let textLabel = UILabel()

    private let closeButton = UIButton(type: .system)

    private var expanded = false

    private var isLoading = false

    private var currentText = ""

    private var textWidthConstraint: Constraint?

    private var closeWidthConstraint: Constraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        updateViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func render(loading: Bool, text: String) {
        isLoading = loading
        currentText = text
        updateViews()
    }

    func collapse() {
        expanded = false
        updateViews()
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(iconImageView)
        addSubview(loadingIndicator)
        addSubview(textLabel)
        addSubview(closeButton)
    }

    private func activateConstraints() {
        snp.makeConstraints { make in
            make.height.equalTo(Self.rowHeight)
        }
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.iconSize)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(iconImageView)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            closeWidthConstraint = make.width.equalTo(0).constraint
        }
        textLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(Self.textIconSpacing)
            make.trailing.equalTo(closeButton.snp.leading)
            make.centerY.equalToSuperview()
            textWidthConstraint = make.width.equalTo(0).constraint
        }
    }

    private func setupViewStyle() {
        backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        layer.cornerRadius = Self.rowHeight / 2
        layer.masksToBounds = false
        layer.borderWidth = Self.borderWidth
        layer.borderColor = TUIChatKitTheme.colors.strokeColorPrimary.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Self.shadowOpacity
        layer.shadowRadius = Self.shadowRadius
        layer.shadowOffset = Self.shadowOffset

        iconImageView.image = AtomicXChatResources.image(named: "message_listen")
        iconImageView.tintColor = TUIChatKitTheme.colors.textColorLink
        iconImageView.contentMode = .scaleAspectFit
        loadingIndicator.color = TUIChatKitTheme.colors.textColorLink

        textLabel.font = .systemFont(ofSize: Self.textFontSize)
        textLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        textLabel.lineBreakMode = .byTruncatingTail

        closeButton.setImage(AtomicXChatResources.image(named: "message_listen_close"), for: .normal)
        closeButton.tintColor = TUIChatKitTheme.colors.textColorPrimary
    }

    private func bindInteraction() {
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBarTapped))
        addGestureRecognizer(tap)
    }

    private func updateViews() {
        loadingIndicator.isHidden = !isLoading
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        iconImageView.isHidden = isLoading
        textLabel.isHidden = !expanded
        closeButton.isHidden = !expanded
        textLabel.text = expanded ? currentText : nil
        textWidthConstraint?.update(offset: expanded ? Self.measuredTextWidth(currentText) : 0)
        closeWidthConstraint?.update(offset: expanded ? Self.closeWidth : 0)
        setNeedsLayout()
    }

    private static func measuredTextWidth(_ text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: textFontSize)
        let available = maxExpandedWidth - horizontalPadding - iconSize - textIconSpacing - closeWidth
        let width = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        return min(width, available)
    }

    @objc private func handleBarTapped() {
        expanded.toggle()
        UIView.animate(withDuration: Self.expandAnimationDuration) {
            self.updateViews()
            self.superview?.layoutIfNeeded()
        }
    }

    @objc private func handleCloseTapped() {
        onClose?()
    }
}
