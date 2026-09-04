import UIKit
import SnapKit

final class MessageListMultiSelectBar: UIView {
    static let barHeight: CGFloat = verticalPadding * 2 + iconSize + iconLabelSpacing + labelHeight

    var onForwardSeparate: (() -> Void)?

    var onForwardMerge: (() -> Void)?

    var onDelete: (() -> Void)?

    private static let verticalPadding = CGFloat(SpacingScheme.iconIconSpacing)

    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)

    private static let iconSize: CGFloat = 40

    private static let iconLabelSpacing: CGFloat = 6

    private static let labelHeight: CGFloat = 15

    private let separateForwardItem = MultiSelectBarActionItem()

    private let mergeForwardItem = MultiSelectBarActionItem()

    private let deleteItem = MultiSelectBarActionItem()

    private var bottomPaddingConstraint: Constraint?

    private var heightConstraint: Constraint?

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        bottomPaddingConstraint?.update(offset: -(Self.verticalPadding + safeAreaInsets.bottom))
        heightConstraint?.update(offset: Self.barHeight + safeAreaInsets.bottom)
    }

    // MARK: - Configure

    func configure(selectedCount: Int) {
        let enabled = selectedCount > 0
        separateForwardItem.setEnabledState(enabled)
        mergeForwardItem.setEnabledState(enabled)
        deleteItem.setEnabledState(enabled)
    }

    private func constructViewHierarchy() {
        let stack = UIStackView(arrangedSubviews: [separateForwardItem, mergeForwardItem, deleteItem])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            bottomPaddingConstraint = make.bottom.equalToSuperview()
                .offset(-Self.verticalPadding).constraint
        }
        snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(Self.barHeight).constraint
        }
    }

    private func setupViewStyle() {
        backgroundColor = TUIChatKitTheme.colors.bgColorBottomBar
        separateForwardItem.configure(
            icon: Self.icon(named: "message_multi_forward_separate"),
            title: LocalizedChatString("RelayOneByOneForward")
        )
        mergeForwardItem.configure(
            icon: Self.icon(named: "message_multi_forward_merge"),
            title: LocalizedChatString("RelayCombineForwad")
        )
        deleteItem.configure(
            icon: Self.icon(named: "message_multi_delete"),
            title: LocalizedChatString("Delete")
        )
    }

    private static func icon(named name: String) -> UIImage? {
        return AtomicXChatResources.image(named: name)?
            .withRenderingMode(.alwaysTemplate)
    }

    private func bindInteraction() {
        separateForwardItem.onTap = { [weak self] in self?.onForwardSeparate?() }
        mergeForwardItem.onTap = { [weak self] in self?.onForwardMerge?() }
        deleteItem.onTap = { [weak self] in self?.onDelete?() }
    }
}

// MARK: - Action Item

private final class MultiSelectBarActionItem: UIControl {
    var onTap: (() -> Void)?

    private static let iconLabelSpacing: CGFloat = 6

    private static let iconSize: CGFloat = 40

    private static let enabledAlpha: CGFloat = 1.0

    private static let disabledAlpha: CGFloat = 0.4

    private let iconView = UIImageView()

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Self.iconLabelSpacing
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.iconSize)
        }
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = TUIChatKitTheme.colors.textColorSecondary
        titleLabel.font = FontScheme.caption3Regular
        titleLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: UIImage?, title: String) {
        iconView.image = icon
        titleLabel.text = title
    }

    func setEnabledState(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? Self.enabledAlpha : Self.disabledAlpha
    }

    @objc private func handleTap() {
        onTap?()
    }
}
