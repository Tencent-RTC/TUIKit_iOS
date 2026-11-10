import UIKit
import SnapKit

final class RoomSettingsButton: UIControl, MeetingToolBarTitleDisplaying {

    var onRequestDismiss: (() -> Void)?

    weak var routerContext: RouterContext?

    var showsTitle = false {
        didSet {
            guard oldValue != showsTitle else { return }
            applyTitleVisibility()
        }
    }

    private let container = UIStackView()
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override var intrinsicContentSize: CGSize {
        let box = showsTitle ? Self.menuIconBoxSize : Self.buttonSize
        return CGSize(
            width: box,
            height: showsTitle ? box + Self.titleSpacing + titleLabel.intrinsicContentSize.height : box
        )
    }

    init() {
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { applyTheme() }
    }

    private func setupViews() {
        // container 不参与命中测试，触摸直接落到控件本身
        container.isUserInteractionEnabled = false
        iconBox.addSubview(iconView)
        container.addArrangedSubview(iconBox)
        container.addArrangedSubview(titleLabel)
        addSubview(container)
    }

    private func setupConstraints() {
        container.snp.makeConstraints { $0.edges.equalToSuperview() }
        iconBox.snp.makeConstraints { $0.size.equalTo(Self.buttonSize) }
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(20)
        }
    }

    private func setupStyles() {
        iconBox.layer.cornerRadius = Self.buttonSize / 2
        container.axis = .vertical
        container.alignment = .center
        container.spacing = Self.titleSpacing
        iconView.image = RoomKitResources.image(named: "roomkit_icon_settings")
        iconView.tintColor = UIColor.roomKitFgPrimary
        iconView.contentMode = .scaleAspectFit
        titleLabel.text = .settingsTitle
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.textColor = UIColor.roomKitFgSecondary
        titleLabel.textAlignment = .center
        titleLabel.isHidden = !showsTitle
        accessibilityLabel = .settingsTitle
        applyTheme()
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
}

extension RoomSettingsButton {

    private func applyTheme() {
        iconBox.backgroundColor = UIColor.roomKitBgHover
    }

    private func applyTitleVisibility() {
        titleLabel.isHidden = !showsTitle
        let box = showsTitle ? Self.menuIconBoxSize : Self.buttonSize
        iconBox.snp.remakeConstraints { $0.size.equalTo(box) }
        iconBox.layer.cornerRadius = box / 2
        iconView.snp.remakeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(showsTitle ? Self.menuIconSize : Self.iconSize)
        }
        invalidateIntrinsicContentSize()
    }
}

extension RoomSettingsButton {

    @objc private func handleTap() {
        onRequestDismiss?()
        routerContext?.push(RoomSettingsViewController(), animated: true)
    }
}

extension String {
    fileprivate static var settingsTitle: String { RoomKitResources.localizedString("roomkit.settings.title") }
}

private extension RoomSettingsButton {
    static let buttonSize: CGFloat = 44
    static let iconSize: CGFloat = 20
    static let menuIconBoxSize: CGFloat = 46
    static let menuIconSize: CGFloat = 21
    static let titleSpacing: CGFloat = 7
}
