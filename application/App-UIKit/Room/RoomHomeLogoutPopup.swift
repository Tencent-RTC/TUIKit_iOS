import TUIRoomKit
import UIKit
import SnapKit

final class RoomHomeLogoutPopup: UIView {

    var onSettings: (() -> Void)?
    var onShareLogs: (() -> Void)?
    var onLogout: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let container = UIView()
    private let settingsButton = SheetActionButton()
    private let shareLogsButton = SheetActionButton()
    private let logoutButton = SheetActionButton()

    private weak var popup: RoomPopup?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupViews() {
        backgroundColor = .clear
        addSubview(container)
        container.addSubview(settingsButton)
        container.addSubview(shareLogsButton)
        container.addSubview(logoutButton)
    }

    private func setupConstraints() {
        container.snp.makeConstraints { $0.edges.equalToSuperview() }

        settingsButton.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
            $0.height.equalTo(Self.BUTTON_HEIGHT)
        }
        shareLogsButton.snp.makeConstraints {
            $0.top.equalTo(settingsButton.snp.bottom).offset(Self.BUTTON_GAP)
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
            $0.height.equalTo(Self.BUTTON_HEIGHT)
        }
        logoutButton.snp.makeConstraints {
            $0.top.equalTo(shareLogsButton.snp.bottom).offset(Self.BUTTON_GAP)
            $0.leading.trailing.equalToSuperview().inset(Self.EDGE_INSET)
            $0.height.equalTo(Self.BUTTON_HEIGHT)
            $0.bottom.equalToSuperview().offset(-Self.BOTTOM_INSET)
        }
    }

    private func setupStyles() {
        configure(
            settingsButton,
            title: .settingsTitle,
            textColor: UIColor.roomKitFgPrimary,
            background: UIColor.roomKitBgHover,
            pressedBackground: UIColor.roomKitBgPress
        )
        configure(
            shareLogsButton,
            title: .shareLogsTitle,
            textColor: UIColor.roomKitFgPrimary,
            background: UIColor.roomKitBgHover,
            pressedBackground: UIColor.roomKitBgPress
        )
        configure(
            logoutButton,
            title: .homeLogout,
            textColor: UIColor.roomKitDanger,
            background: UIColor.roomKitDangerSoft,
            pressedBackground: UIColor.roomKitDangerSoftStrong
        )
        applyTheme()
    }

    private func configure(
        _ button: SheetActionButton,
        title: String,
        textColor: UIColor,
        background: UIColor,
        pressedBackground: UIColor
    ) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: Self.BUTTON_FONT_SIZE, weight: .semibold)
        button.setTitleColor(textColor, for: .normal)
        button.layer.cornerRadius = Self.BUTTON_RADIUS
        button.normalBackgroundColor = background
        button.pressedBackgroundColor = pressedBackground
    }

    private func setupBindings() {
        settingsButton.addTarget(self, action: #selector(handleSettingsTap), for: .touchUpInside)
        shareLogsButton.addTarget(self, action: #selector(handleShareLogsTap), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(handleLogoutTap), for: .touchUpInside)
    }

    @objc private func handleSettingsTap() {
        onSettings?()
    }

    @objc private func handleShareLogsTap() {
        onShareLogs?()
    }

    @objc private func handleLogoutTap() {
        onLogout?()
    }

    private func applyTheme() {
        settingsButton.backgroundColor = settingsButton.normalBackgroundColor
        shareLogsButton.backgroundColor = shareLogsButton.normalBackgroundColor
        logoutButton.backgroundColor = logoutButton.normalBackgroundColor
    }
}

extension RoomHomeLogoutPopup {

    func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        snp.makeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in
            self?.onDismiss?()
        }
        self.popup = popup
        popup.show(in: host)
    }

    func dismiss(completion: (() -> Void)? = nil) {
        popup?.dismiss(completion: completion)
    }
}

private extension RoomHomeLogoutPopup {
    static let EDGE_INSET: CGFloat = 16
    static let BUTTON_GAP: CGFloat = 12
    static let BUTTON_HEIGHT: CGFloat = 44
    static let BUTTON_RADIUS: CGFloat = 12
    static let BUTTON_FONT_SIZE: CGFloat = 16
    static let BOTTOM_INSET: CGFloat = 16
}

private final class SheetActionButton: UIButton {

    var normalBackgroundColor: UIColor = .clear {
        didSet { backgroundColor = normalBackgroundColor }
    }
    var pressedBackgroundColor: UIColor = UIColor.roomKitBgPress

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? pressedBackgroundColor : normalBackgroundColor
        }
    }
}

private extension String {
    static var settingsTitle: String { NSLocalizedString("app.settings.title", comment: "") }
    static var homeLogout: String { NSLocalizedString("app.home.logout", comment: "") }
    static var shareLogsTitle: String { NSLocalizedString("app.logs.title", comment: "") }
}
