import UIKit
import SnapKit

final class RoomAudioRouteRow: UIControl {

    let output: RoomAudioOutput
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

    init(output: RoomAudioOutput, icon: String, title: String) {
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
