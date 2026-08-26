import UIKit
import SnapKit
import Kingfisher

struct ForwardBottomBarItem {
    let key: String
    let avatarURL: String
    let fallbackName: String
}

final class ForwardBottomBar: UIView {
    private static let avatarCornerRadius = CGFloat(RadiusScheme.largeRadius)

    private static let avatarSize: CGFloat = 32

    private static let avatarSpacing: CGFloat = 6

    private static let horizontalInset = CGFloat(SpacingScheme.iconIconSpacing)

    private static let scrollViewVerticalInset: CGFloat = 10

    private static let confirmButtonCornerRadius: CGFloat = 6

    private static let confirmButtonContentInsets = UIEdgeInsets(
        top: CGFloat(SpacingScheme.smallSpacing),
        left: CGFloat(SpacingScheme.bubbleSpacing),
        bottom: CGFloat(SpacingScheme.smallSpacing),
        right: CGFloat(SpacingScheme.bubbleSpacing)
    )

    private static let placeholderFontSize: CGFloat = 13

    var onConfirm: (() -> Void)?

    private let scrollView = UIScrollView()

    private let avatarStack = UIStackView()

    private let confirmButton = UIButton(type: .custom)

    private var currentConfirmTitle: String?

    private var currentConfirmEnabled: Bool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(items: [ForwardBottomBarItem]) {
        avatarStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for item in items {
            let avatarView = UIImageView()
            avatarView.layer.cornerRadius = Self.avatarCornerRadius
            avatarView.clipsToBounds = true
            avatarView.contentMode = .scaleAspectFill
            avatarView.snp.makeConstraints { make in
                make.width.height.equalTo(Self.avatarSize)
            }
            if !item.avatarURL.isEmpty, let url = URL(string: item.avatarURL) {
                avatarView.kf.setImage(with: url, placeholder: generatePlaceholder(name: item.fallbackName))
            } else {
                avatarView.image = generatePlaceholder(name: item.fallbackName)
            }
            avatarStack.addArrangedSubview(avatarView)
        }

        updateConfirmButton(count: items.count)
    }

    private func setupUI() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate

        addSubview(scrollView)
        addSubview(confirmButton)

        scrollView.showsHorizontalScrollIndicator = false
        avatarStack.axis = .horizontal
        avatarStack.spacing = Self.avatarSpacing
        avatarStack.alignment = .center
        scrollView.addSubview(avatarStack)

        scrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalInset)
            make.top.equalToSuperview().offset(Self.scrollViewVerticalInset)
            make.bottom.equalToSuperview().offset(-Self.scrollViewVerticalInset)
            make.trailing.equalTo(confirmButton.snp.leading).offset(-Self.horizontalInset)
            make.height.equalTo(Self.avatarSize)
        }

        avatarStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }

        confirmButton.titleLabel?.font = FontScheme.caption2Bold
        confirmButton.layer.cornerRadius = Self.confirmButtonCornerRadius
        confirmButton.clipsToBounds = true
        confirmButton.contentEdgeInsets = Self.confirmButtonContentInsets
        confirmButton.addTarget(self, action: #selector(handleConfirmTapped), for: .touchUpInside)
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalInset)
            make.centerY.equalToSuperview()
        }

        updateConfirmButton(count: 0)
    }

    private func updateConfirmButton(count: Int) {
        let colors = ChatUIKitTheme.colors
        let enabled = count > 0
        let title = LocalizedChatString("Forward") + (count > 0 ? "(\(count))" : "")
        if title != currentConfirmTitle {
            currentConfirmTitle = title
            confirmButton.setTitle(title, for: .normal)
        }
        guard enabled != currentConfirmEnabled else { return }
        currentConfirmEnabled = enabled
        confirmButton.isEnabled = enabled
        confirmButton.setTitleColor(
            enabled ? colors.textColorButton : colors.textColorTertiary,
            for: .normal
        )
        confirmButton.backgroundColor = enabled ? colors.buttonColorPrimaryDefault : colors.buttonColorPrimaryDisabled
    }

    @objc private func handleConfirmTapped() {
        onConfirm?()
    }

    private func generatePlaceholder(name: String) -> UIImage? {
        let size = CGSize(width: Self.avatarSize, height: Self.avatarSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = ChatUIKitTheme.colors
            colors.buttonColorPrimaryDefault.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let initial = String(name.prefix(1)).uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: Self.placeholderFontSize, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let textSize = initial.size(withAttributes: attrs)
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            initial.draw(at: point, withAttributes: attrs)
        }
    }
}
