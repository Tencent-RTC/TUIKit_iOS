import UIKit
import Combine
import SnapKit

final class ContactNavigationRowView: UIView {
    var onTap: (() -> Void)?

    private static let rowHeight: CGFloat = 60

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let iconSize: CGFloat = 40

    private static let iconTextSpacing: CGFloat = 14

    private static let badgeSize: CGFloat = 18

    private static let badgeMaxCount = 99

    private static let badgeFontSize: CGFloat = 11

    private let iconView = UIImageView()

    private let titleLabel = UILabel()

    private let badgeLabel = UILabel()

    init(title: String, icon: UIImage?) {
        super.init(frame: .zero)
        iconView.image = icon
        titleLabel.text = title
        constructViewHierarchy()
        activateConstraints(hasIcon: icon != nil)
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBadge(_ count: Int) {
        if count > 0 {
            badgeLabel.text = count > Self.badgeMaxCount ? "\(Self.badgeMaxCount)+" : "\(count)"
            badgeLabel.isHidden = false
        } else {
            badgeLabel.isHidden = true
        }
    }

    private func constructViewHierarchy() {
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(badgeLabel)
    }

    private func activateConstraints(hasIcon: Bool) {
        snp.makeConstraints { make in
            make.height.equalTo(Self.rowHeight)
        }
        if hasIcon {
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Self.horizontalPadding)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(Self.iconSize)
            }
            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(iconView.snp.trailing).offset(Self.iconTextSpacing)
                make.centerY.equalToSuperview()
            }
        } else {
            iconView.isHidden = true
            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Self.horizontalPadding)
                make.centerY.equalToSuperview()
            }
        }
        badgeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.badgeSize)
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorPrimary
        badgeLabel.font = .systemFont(ofSize: Self.badgeFontSize)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = colors.textColorError
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = Self.badgeSize / 2
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isHidden = true
    }

    @objc private func handleTap() {
        onTap?()
    }
}

final class ContactNavigationHeaderView: UIView {
    private static let dividerHeight: CGFloat = 0.5

    private static let dividerLeadingInset: CGFloat = 68

    private let stackView = UIStackView()

    private var badgeCancellables = Set<AnyCancellable>()

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setItems(_ items: [ContactCustomItem]) {
        badgeCancellables.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in items.enumerated() {
            let row = ContactNavigationRowView(
                title: item.title,
                icon: AtomicXChatResources.image(named: item.iconName)
            )
            row.onTap = item.onClick
            if let badgeCount = item.badgeCount {
                badgeCount
                    .receive(on: DispatchQueue.main)
                    .sink { [weak row] count in
                        row?.updateBadge(count)
                    }
                    .store(in: &badgeCancellables)
            }
            stackView.addArrangedSubview(row)
            if index < items.count - 1 {
                stackView.addArrangedSubview(makeDivider())
            }
        }
    }

    private func constructViewHierarchy() {
        stackView.axis = .vertical
        stackView.spacing = 0
        addSubview(stackView)
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = ChatUIKitTheme.colors.strokeColorSecondary
        divider.snp.makeConstraints { make in
            make.height.equalTo(Self.dividerHeight)
        }
        let insetWrapper = UIView()
        insetWrapper.addSubview(divider)
        divider.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.equalToSuperview().offset(Self.dividerLeadingInset)
        }
        return insetWrapper
    }

    private func activateConstraints() {
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        backgroundColor = ChatUIKitTheme.colors.bgColorOperate
    }
}
