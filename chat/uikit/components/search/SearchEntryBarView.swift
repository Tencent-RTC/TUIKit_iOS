import UIKit
import SnapKit

final class SearchEntryBarView: UIView {
    private let onTapItem: SearchResultHandler

    private static let barHeight: CGFloat = 36

    private static let barHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let barCornerRadius: CGFloat = 10

    private static let iconSize: CGFloat = 16

    private static let iconTextGap: CGFloat = 6

    private let inputContainer = UIView()

    private let centerStack = UIStackView()

    private let iconView = UIImageView()

    private let placeholderLabel = UILabel()

    init(onTapItem: @escaping SearchResultHandler) {
        self.onTapItem = onTapItem
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        addSubview(inputContainer)
        centerStack.addArrangedSubview(iconView)
        centerStack.addArrangedSubview(placeholderLabel)
        inputContainer.addSubview(centerStack)
    }

    private func activateConstraints() {
        inputContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.barHorizontalInset)
            make.trailing.equalToSuperview().offset(-Self.barHorizontalInset)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(Self.barHeight)
        }
        centerStack.axis = .horizontal
        centerStack.spacing = Self.iconTextGap
        centerStack.alignment = .center
        centerStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Self.barHorizontalInset / 2)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.barHorizontalInset / 2)
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.iconSize)
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.clearColor
        inputContainer.backgroundColor = colors.bgColorInput
        inputContainer.layer.cornerRadius = Self.barCornerRadius
        inputContainer.layer.masksToBounds = true

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.tintColor = colors.textColorSecondary
        iconView.contentMode = .scaleAspectFit

        placeholderLabel.text = LocalizedChatString("Search")
        placeholderLabel.font = FontScheme.caption2Regular
        placeholderLabel.textColor = colors.textColorSecondary
    }

    @objc private func handleTap() {
        let resultController = SearchResultViewController(onTapItem: onTapItem)
        resultController.hidesBottomBarWhenPushed = true
        findViewController()?.navigationController?.pushViewController(resultController, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            responder = next
        }
        return nil
    }
}
