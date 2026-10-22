import UIKit
import SnapKit

public final class RoomDeviceFaultSheet: UIView {

    public var onPrimary: (() -> Void)?
    public var onDismiss: (() -> Void)?

    let kind: RoomDeviceKind

    private weak var popup: RoomPopup?
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)

    public init(kind: RoomDeviceKind) {
        self.kind = kind
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

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }


    private func setupViews() {
        iconContainer.addSubview(iconView)
        addSubview(iconContainer)
        addSubview(titleLabel)
        addSubview(descLabel)
        addSubview(primaryButton)
        addSubview(secondaryButton)
    }

    private func setupConstraints() {
        iconContainer.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(48)
        }
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(iconContainer.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        descLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        primaryButton.snp.makeConstraints {
            $0.top.equalTo(descLabel.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(44)
        }
        secondaryButton.snp.makeConstraints {
            $0.top.equalTo(primaryButton.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(44)
            $0.bottom.equalToSuperview().offset(-20)
        }
    }

    private func setupStyles() {
        iconContainer.layer.cornerRadius = 24
        iconView.contentMode = .center
        iconView.image = RoomKitResources.image(named: kind == .camera ? "roomkit_icon_camera_fault" : "roomkit_icon_microphone_fault")

        let name = kind.localizedName
        titleLabel.text = RoomKitResources.localizedFormat("roomkit.main.device_fault_system_title", name)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let descFont = UIFont.systemFont(ofSize: 13)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = max(13 * 1.55 - descFont.lineHeight, 0)
        descLabel.numberOfLines = 0
        descLabel.attributedText = NSAttributedString(
            string: RoomKitResources.localizedFormat("roomkit.main.device_fault_system_body", name),
            attributes: [.font: descFont, .paragraphStyle: paragraph]
        )

        for button in [primaryButton, secondaryButton] {
            button.layer.cornerRadius = 10
            button.clipsToBounds = true
        }
        primaryButton.setTitle(RoomKitResources.localizedString("roomkit.main.device_open_settings"), for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        secondaryButton.setTitle(RoomKitResources.localizedString("roomkit.main.device_not_now"), for: .normal)
        secondaryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)

        applyTheme()
    }

    private func setupBindings() {
        primaryButton.addTarget(self, action: #selector(handlePrimaryTap), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)
    }

    private func applyTheme() {
        iconContainer.backgroundColor = UIColor.roomKitWarningSoft
        titleLabel.textColor = UIColor.roomKitFgPrimary
        descLabel.textColor = UIColor.roomKitFgSecondary
        primaryButton.setBackgroundImage(.solid(.roomKitAccent), for: .normal)
        primaryButton.setBackgroundImage(.solid(.roomKitAccentSoft), for: .highlighted)
        primaryButton.setTitleColor(.roomKitFgOnAccent, for: .normal)
        secondaryButton.setBackgroundImage(.solid(.roomKitBgHover), for: .normal)
        secondaryButton.setBackgroundImage(.solid(.roomKitBgPress), for: .highlighted)
        secondaryButton.setTitleColor(.roomKitFgPrimary, for: .normal)
    }
}

// MARK: - public methods

extension RoomDeviceFaultSheet {

    public func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        snp.remakeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in self?.onDismiss?() }
        self.popup = popup
        popup.show(in: host)
    }

    func dismiss(completion: (() -> Void)? = nil) {
        guard let popup else {
            completion?()
            return
        }
        popup.dismiss(completion: completion)
    }
}

// MARK: - private methods

extension RoomDeviceFaultSheet {

    @objc private func handlePrimaryTap() {
        let action = onPrimary
        dismiss { action?() }
    }

    @objc private func handleDismissTap() {
        let action = onDismiss
        dismiss { action?() }
    }
}
