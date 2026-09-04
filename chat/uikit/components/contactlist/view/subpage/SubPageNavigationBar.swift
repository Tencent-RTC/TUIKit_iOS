import UIKit
import SnapKit

final class SubPageNavigationBar: UIView {
    private static let closeButtonLeading: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let closeButtonSize: CGFloat = 44

    private static let backSymbolPointSize: CGFloat = 18

    var onClose: (() -> Void)?

    private let closeButton = UIButton(type: .system)

    private let titleLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        addSubview(closeButton)
        addSubview(titleLabel)
    }

    private func activateConstraints() {
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.closeButtonLeading)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.closeButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func bindInteraction() {
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        titleLabel.font = FontScheme.caption1Medium
        titleLabel.textColor = colors.textColorPrimary
        let image = AtomicXChatResources.image(named: "contact_info_back")?
            .withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "chevron.left",
                       withConfiguration: UIImage.SymbolConfiguration(pointSize: Self.backSymbolPointSize, weight: .semibold))
        closeButton.setImage(image, for: .normal)
        closeButton.tintColor = colors.textColorPrimary
    }

    @objc private func handleClose() {
        onClose?()
    }
}
