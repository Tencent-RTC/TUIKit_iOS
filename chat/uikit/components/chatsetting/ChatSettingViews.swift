import UIKit
import SnapKit

public class ChatSettingBaseViewController: UIViewController {
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

    private let backButton = UIButton(type: .custom)

    private let titleLabel = UILabel()

    private let divider = UIView()

    private var navLeadingView: UIView?

    private var navTrailingView: UIView?

    public override func viewDidLoad() {
        super.viewDidLoad()
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
        let colors = ChatUIKitTheme.colors
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

// MARK: - Row Views（规格对齐 Android SettingRowNavigate / SettingRowToggle / ActionItem 行）

final class ChatSettingRowView: UIControl {
    enum Accessory {
        case none
        case arrow
        case edit
    }

    override var isEnabled: Bool {
        didSet { isUserInteractionEnabled = isEnabled }
    }

    private static let horizontalPadding: CGFloat = 14

    private static let verticalPadding: CGFloat = 12

    private static let rowMinHeight: CGFloat = 48

    private static let accessorySize: CGFloat = 16

    private static let accessoryLeadingGap: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let titleTrailingGap: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private let titleLabel = UILabel()

    private let valueLabel = UILabel()

    private let accessoryImageView = UIImageView()

    private var valueTrailingToAccessory: Constraint?

    private var valueTrailingToSuperview: Constraint?

    init(title: String, value: String = "", accessory: Accessory = .arrow) {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        titleLabel.text = title
        update(value: value, accessory: accessory)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    func update(value: String, accessory: Accessory) {
        valueLabel.text = value
        if accessory == .none {
            valueTrailingToAccessory?.deactivate()
            valueTrailingToSuperview?.activate()
        } else {
            valueTrailingToSuperview?.deactivate()
            valueTrailingToAccessory?.activate()
        }
        switch accessory {
        case .none:
            accessoryImageView.isHidden = true
        case .arrow:
            accessoryImageView.isHidden = false
            accessoryImageView.image = AtomicXChatResources.image(named: "contact_info_arrow_right")?
                .withRenderingMode(.alwaysTemplate)
        case .edit:
            accessoryImageView.isHidden = false
            accessoryImageView.image = AtomicXChatResources.image(named: "group_setting_edit_icon")?
                .withRenderingMode(.alwaysTemplate)
        }
    }

    private func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(accessoryImageView)
    }

    private func activateConstraints() {
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.rowMinHeight)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.centerY.equalToSuperview()
        }
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.accessorySize)
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.titleTrailingGap)
            valueTrailingToAccessory = make.trailing.equalTo(accessoryImageView.snp.leading).offset(-Self.accessoryLeadingGap).constraint
            valueTrailingToSuperview = make.trailing.equalToSuperview().offset(-Self.horizontalPadding).constraint
            make.centerY.equalToSuperview()
        }
        valueTrailingToSuperview?.deactivate()
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorSecondary
        valueLabel.font = FontScheme.caption1Regular
        valueLabel.textColor = colors.textColorPrimary
        valueLabel.textAlignment = LanguageHelper.isRTL ? .left : .right
        valueLabel.lineBreakMode = .byTruncatingTail
        accessoryImageView.tintColor = colors.textColorTertiary
        accessoryImageView.contentMode = .scaleAspectFit
    }
}

final class ChatSettingToggleRowView: UIView {
    var onToggle: ((Bool) -> Void)?

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let verticalPadding: CGFloat = 10

    private let titleLabel = UILabel()

    private let toggle = UISwitch()

    init(title: String, isOn: Bool = false) {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        titleLabel.text = title
        toggle.isOn = isOn
        toggle.addTarget(self, action: #selector(handleToggleChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setOn(_ isOn: Bool) {
        toggle.setOn(isOn, animated: false)
    }

    private func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(toggle)
    }

    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.centerY.equalToSuperview()
        }
        toggle.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorSecondary
        toggle.onTintColor = colors.switchColorOn
    }

    @objc private func handleToggleChanged() {
        onToggle?(toggle.isOn)
    }
}

final class ChatSettingActionRowView: UIControl {
    private static let verticalPadding: CGFloat = 15

    private static let rowMinHeight: CGFloat = 56

    private static let fontSize: CGFloat = 17

    private let titleLabel = UILabel()

    init(title: String, textColor: UIColor) {
        super.init(frame: .zero)
        addSubview(titleLabel)
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.rowMinHeight)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
        }
        backgroundColor = ChatUIKitTheme.colors.bgColorOperate
        titleLabel.font = .systemFont(ofSize: Self.fontSize)
        titleLabel.textColor = textColor
        titleLabel.text = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Section Helpers

private let chatSettingSectionSpacerHeight: CGFloat = 10

private let chatSettingRowDividerHeight: CGFloat = 0.5

func makeChatSettingSectionSpacer() -> UIView {
    let spacer = UIView()
    spacer.backgroundColor = ChatUIKitTheme.colors.bgColorTopBar
    spacer.snp.makeConstraints { make in
        make.height.equalTo(chatSettingSectionSpacerHeight)
    }
    return spacer
}

func makeChatSettingRowDivider() -> UIView {
    let divider = UIView()
    divider.backgroundColor = ChatUIKitTheme.colors.strokeColorPrimary
    divider.snp.makeConstraints { make in
        make.height.equalTo(chatSettingRowDividerHeight)
    }
    return divider
}
