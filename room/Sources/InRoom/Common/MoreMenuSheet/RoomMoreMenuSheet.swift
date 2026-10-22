import UIKit
import SnapKit

final class RoomMoreMenuSheet: UIView {

    struct Item {
        let iconName: String
        let title: String
        let isOn: Bool
        let isDanger: Bool
        let action: () -> Void

        init(iconName: String, title: String, isOn: Bool = false, isDanger: Bool = false, action: @escaping () -> Void) {
            self.iconName = iconName
            self.title = title
            self.isOn = isOn
            self.isDanger = isDanger
            self.action = action
        }
    }

    var onDismiss: (() -> Void)?

    private let items: [Item]
    private let grid = UIStackView()
    private weak var popup: RoomPopup?

    init(items: [Item]) {
        self.items = items
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(grid)
        var index = 0
        while index < items.count {
            let row = UIStackView(arrangedSubviews: items[index..<min(index + Self.COLUMN_COUNT, items.count)].map { Cell(item: $0) })
            row.axis = .horizontal
            row.distribution = .fillEqually
            grid.addArrangedSubview(row)
            index += Self.COLUMN_COUNT
        }
    }

    private func setupConstraints() {
        grid.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupStyles() {
        grid.axis = .vertical
        grid.spacing = Self.ROW_GAP
        grid.isLayoutMarginsRelativeArrangement = true
        grid.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 14, right: 8)
    }
}

// MARK: - public methods

extension RoomMoreMenuSheet {

    func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        snp.makeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in
            self?.popup = nil
            self?.onDismiss?()
        }
        self.popup = popup
        popup.show(in: host)
    }

    func dismiss() {
        popup?.dismiss()
    }
}

// MARK: - private constants

private extension RoomMoreMenuSheet {
    static let COLUMN_COUNT = 4
    static let ROW_GAP: CGFloat = 4
}


private final class Cell: UIControl {

    private let item: RoomMoreMenuSheet.Item
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(item: RoomMoreMenuSheet.Item) {
        self.item = item
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { transform = isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: Self.TOP_PADDING + Self.ICON_BOX_SIZE + Self.GAP + titleLabel.intrinsicContentSize.height + Self.BOTTOM_PADDING
        )
    }

    private func setupViews() {
        iconBox.addSubview(iconView)
        addSubview(iconBox)
        addSubview(titleLabel)
        iconBox.isUserInteractionEnabled = false
        titleLabel.isUserInteractionEnabled = false
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    private func setupConstraints() {
        iconBox.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Self.TOP_PADDING)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(Self.ICON_BOX_SIZE)
        }
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Self.ICON_SIZE)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(iconBox.snp.bottom).offset(Self.GAP)
            $0.leading.trailing.equalToSuperview().inset(2)
            $0.bottom.equalToSuperview().offset(-Self.BOTTOM_PADDING)
        }
    }

    private func setupStyles() {
        iconBox.layer.cornerRadius = Self.ICON_BOX_SIZE / 2
        iconBox.backgroundColor = UIColor.roomKitBgHover
        iconView.image = RoomKitResources.image(named: item.iconName)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = item.isDanger ? UIColor.roomKitDanger
            : (item.isOn ? UIColor.roomKitAccent : UIColor.roomKitFgPrimary)
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: Self.TITLE_FONT_SIZE)
        titleLabel.textColor = UIColor.roomKitFgSecondary
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        accessibilityLabel = item.title
    }

    @objc private func handleTap() {
        item.action()
    }

    static let ICON_BOX_SIZE: CGFloat = 46
    static let ICON_SIZE: CGFloat = 21
    static let TITLE_FONT_SIZE: CGFloat = 11
    static let TOP_PADDING: CGFloat = 10
    static let BOTTOM_PADDING: CGFloat = 10
    static let GAP: CGFloat = 7
}
