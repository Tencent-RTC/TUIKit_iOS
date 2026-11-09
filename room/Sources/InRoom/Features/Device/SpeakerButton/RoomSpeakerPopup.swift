import UIKit
import SnapKit
import AtomicXCore

final class RoomSpeakerPopup: UIView {

    var onSelect: ((AudioRoute) -> Void)?
    var onDismiss: (() -> Void)?

    private weak var popup: RoomPopup?
    private let routeGroup = UIView()
    private let routeStack = UIStackView()
    private let routeRows: [Row]
    private let cancelButton = UIButton(type: .custom)

    init(current: AudioRoute) {
        routeRows = [
            Row(output: .speakerphone, icon: "roomkit_icon_speaker", title: .audioSpeaker),
            Row(output: .earpiece, icon: "roomkit_icon_earpiece", title: .audioEarpiece),
        ]
        super.init(frame: .zero)
        routeRows.forEach { $0.isCurrent = $0.output == current }
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
        addSubview(routeGroup)
        routeGroup.addSubview(routeStack)
        addSubview(cancelButton)
        routeRows.forEach { routeStack.addArrangedSubview($0) }
    }

    private func setupConstraints() {
        routeGroup.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        routeStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(6) }
        cancelButton.snp.makeConstraints {
            $0.top.equalTo(routeGroup.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.bottom.equalToSuperview().offset(-12)
            $0.height.equalTo(48)
        }
    }

    private func setupStyles() {
        routeGroup.layer.cornerRadius = 16
        routeStack.axis = .vertical
        routeStack.spacing = 2

        cancelButton.layer.cornerRadius = 12
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15)
        cancelButton.setTitle(RoomKitResources.localizedString("roomkit.common.cancel"), for: .normal)

        applyTheme()
    }

    private func setupBindings() {
        routeRows.forEach { $0.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside) }
        cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
    }

    private func applyTheme() {
        routeGroup.backgroundColor = UIColor.roomKitBgCanvas
        cancelButton.backgroundColor = UIColor.roomKitBgCanvas
        cancelButton.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
    }
}

extension RoomSpeakerPopup {

    func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.panelBackgroundColor = .clear
        popup.panelBorderColor = .clear
        popup.showsHandleBar = false
        popup.contentView.addSubview(self)
        popup.contentView.backgroundColor = .clear
        snp.remakeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in self?.onDismiss?() }
        self.popup = popup
        popup.show(in: host)
    }
}

extension RoomSpeakerPopup {

    @objc private func handleRowTap(_ row: Row) {
        let output = row.output
        let action = onSelect
        popup?.dismiss { action?(output) }
    }

    @objc private func handleCancelTap() {
        let action = onDismiss
        popup?.dismiss { action?() }
    }
}

private extension RoomSpeakerPopup {

    final class Row: UIControl {

        let output: AudioRoute
        private let iconName: String

        var isCurrent = false {
            didSet {
                checkView.isHidden = !isCurrent
                iconView.image = RoomKitResources.image(
                    named: isCurrent ? "\(iconName)_accent" : "\(iconName)_primary"
                )
                applyTheme()
            }
        }

        override var isHighlighted: Bool {
            didSet {
                guard oldValue != isHighlighted else { return }
                applyTheme()
            }
        }

        private let iconView = UIImageView()
        private let titleLabel = UILabel()
        private let checkView = UIImageView()

        init(output: AudioRoute, icon: String, title: String) {
            self.output = output
            self.iconName = icon
            super.init(frame: .zero)

            layer.cornerRadius = 12
            iconView.image = RoomKitResources.image(named: "\(icon)_primary")
            iconView.contentMode = .scaleAspectFit
            iconView.isUserInteractionEnabled = false
            titleLabel.text = title
            titleLabel.font = .systemFont(ofSize: 15)
            checkView.image = RoomKitResources.image(named: "roomkit_icon_check_accent")
            checkView.contentMode = .scaleAspectFit
            checkView.isUserInteractionEnabled = false
            checkView.isHidden = true

            addSubview(iconView)
            addSubview(titleLabel)
            addSubview(checkView)

            snp.makeConstraints { $0.height.equalTo(52) }
            iconView.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(14)
                $0.centerY.equalToSuperview()
                $0.size.equalTo(22)
            }
            checkView.snp.makeConstraints {
                $0.trailing.equalToSuperview().offset(-14)
                $0.centerY.equalToSuperview()
                $0.size.equalTo(18)
            }
            titleLabel.snp.makeConstraints {
                $0.leading.equalTo(iconView.snp.trailing).offset(12)
                $0.trailing.lessThanOrEqualTo(checkView.snp.leading).offset(-12)
                $0.centerY.equalToSuperview()
            }

            applyTheme()
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

        private func applyTheme() {
            if isCurrent {
                backgroundColor = UIColor.roomKitAccentSoft
                titleLabel.textColor = UIColor.roomKitAccent
            } else {
                backgroundColor = isHighlighted ? UIColor.roomKitBgPress : .clear
                titleLabel.textColor = UIColor.roomKitFgPrimary
            }
        }
    }
}

extension String {
    fileprivate static var audioSpeaker: String { RoomKitResources.localizedString("roomkit.main.audio_route_speaker") }
    fileprivate static var audioEarpiece: String { RoomKitResources.localizedString("roomkit.main.audio_route_earpiece") }
}
