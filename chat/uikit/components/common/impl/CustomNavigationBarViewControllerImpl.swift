import UIKit
import SnapKit

final class CustomNavigationBarViewControllerImpl: PageImplementation {
    var onBack: (() -> Void)?

    var contentTopItem: ConstraintItem {
        return divider.snp.bottom
    }

    private static let navBarHeight: CGFloat = 56

    private static let navHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let backButtonSize: CGFloat = 28

    private static let backIconPointSize: CGFloat = 18

    private static let titleFontSize: CGFloat = 16

    private static let dividerHeight: CGFloat = 0.5

    private let navigationBar = UIView()

    private let statusBarBackgroundView = UIView()

    private let backButton = ExpandedHitButton(type: .custom)

    private let titleLabel = UILabel()

    private let divider = UIView()

    private var navLeadingView: UIView?

    private var navTrailingView: UIView?

    func viewDidLoad() {
        constructNavigationBar()
        activateNavigationBarConstraints()
        setupNavigationBarStyle()
        backButton.addTarget(self, action: #selector(handleBackTapped), for: .touchUpInside)
    }

    func setNavTitle(_ text: String) {
        titleLabel.text = text
    }

    func setNavBackHidden(_ hidden: Bool) {
        backButton.isHidden = hidden
    }

    func setNavLeadingView(_ leadingView: UIView) {
        navLeadingView?.removeFromSuperview()
        navLeadingView = leadingView
        navigationBar.addSubview(leadingView)
        leadingView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.navHorizontalInset)
            make.centerY.equalToSuperview()
        }
        updateTitleConstraints()
    }

    func setNavTrailingView(_ trailingView: UIView) {
        navTrailingView?.removeFromSuperview()
        navTrailingView = trailingView
        navigationBar.addSubview(trailingView)
        trailingView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.navHorizontalInset)
            make.centerY.equalToSuperview()
        }
        updateTitleConstraints()
    }

    func pushOrPresent(_ viewController: UIViewController) {
        if let navigationController = navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            present(viewController, animated: true)
        }
    }

    private func updateTitleConstraints() {
        titleLabel.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            if let navLeadingView = navLeadingView {
                make.leading.greaterThanOrEqualTo(navLeadingView.snp.trailing).offset(Self.navHorizontalInset)
            } else {
                make.leading.greaterThanOrEqualTo(backButton.snp.trailing).offset(Self.navHorizontalInset)
            }
            if let navTrailingView = navTrailingView {
                make.trailing.lessThanOrEqualTo(navTrailingView.snp.leading).offset(-Self.navHorizontalInset)
            } else {
                make.trailing.lessThanOrEqualToSuperview().offset(-Self.navHorizontalInset)
            }
        }
    }

    private func constructNavigationBar() {
        view.addSubview(statusBarBackgroundView)
        view.addSubview(navigationBar)
        navigationBar.addSubview(backButton)
        navigationBar.addSubview(titleLabel)
        view.addSubview(divider)
    }

    private func activateNavigationBarConstraints() {

        statusBarBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(navigationBar.snp.top)
        }
        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.navBarHeight)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.navHorizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.backButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing).offset(Self.navHorizontalInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.navHorizontalInset)
        }
        divider.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
    }

    private func setupNavigationBarStyle() {
        let colors = TUIChatKitTheme.colors
        statusBarBackgroundView.backgroundColor = colors.bgColorOperate
        navigationBar.backgroundColor = colors.bgColorOperate
        divider.backgroundColor = colors.strokeColorSecondary
        if let backImage = AtomicXChatResources.image(named: "contact_info_back") {
            backButton.setImage(backImage.withRenderingMode(.alwaysTemplate), for: .normal)
        } else {
            backButton.setImage(
                UIImage(systemName: "chevron.left")?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.backIconPointSize, weight: .semibold)),
                for: .normal
            )
        }
        backButton.tintColor = colors.textColorPrimary
        backButton.contentHorizontalAlignment = .leading
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .semibold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
    }

    @objc private func handleBackTapped() {
        if let onBack = onBack {
            onBack()
        } else if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

