import UIKit

internal class PermissionOverlayView: UIView {

    private static let overlayAlpha: CGFloat = 0.7
    private static let cardWidth: CGFloat = 260
    private static let cardPaddingHorizontal: CGFloat = 24
    private static let cardPaddingVertical: CGFloat = 32
    private static let iconSize: CGFloat = 28
    private static let titleFontSize: CGFloat = 18
    private static let descriptionFontSize: CGFloat = 15
    private static let iconTitleSpacing: CGFloat = 16
    private static let titleDescSpacing: CGFloat = 8
    private static let cardTopOffset: CGFloat = 120

    private let titleText: String
    private let descriptionText: String
    private let iconName: String

    internal init(title: String, description: String, iconName: String = "folder.fill") {
        self.titleText = title
        self.descriptionText = description
        self.iconName = iconName
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(Self.overlayAlpha)
        isUserInteractionEnabled = true

        let card = createCard()
        addSubview(card)
        card.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Self.cardTopOffset)
            make.width.equalTo(Self.cardWidth)
        }
    }

    private func createCard() -> UIView {
        let card = UIView()

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Self.titleDescSpacing

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.iconSize)
        }

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let descLabel = UILabel()
        descLabel.text = descriptionText
        descLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        descLabel.font = .systemFont(ofSize: Self.descriptionFontSize, weight: .regular)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        stack.addArrangedSubview(iconView)
        stack.setCustomSpacing(Self.iconTitleSpacing, after: iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(descLabel)

        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.cardPaddingVertical)
            make.bottom.equalToSuperview().offset(-Self.cardPaddingVertical)
            make.leading.equalToSuperview().offset(Self.cardPaddingHorizontal)
            make.trailing.equalToSuperview().offset(-Self.cardPaddingHorizontal)
        }

        return card
    }
}
