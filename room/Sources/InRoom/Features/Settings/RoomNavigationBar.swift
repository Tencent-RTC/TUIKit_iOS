import UIKit
import SnapKit

public final class RoomNavigationBar: UIView {

    public var onBack: (() -> Void)?

    public var navigationTitle: String? {
        didSet { titleLabel.text = navigationTitle }
    }


    private let contentView = UIView()
    private let backButton = UIButton(type: .custom)
    private let backIcon = UIImageView()
    private let titleLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupViews() {
        backButton.addSubview(backIcon)
        contentView.addSubview(backButton)
        contentView.addSubview(titleLabel)
        addSubview(contentView)
    }

    private func setupConstraints() {
        contentView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(52)
        }
        backButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(40)
        }
        backIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(22)
        }
        titleLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(72)
            $0.trailing.lessThanOrEqualToSuperview().offset(-72)
        }
    }

    private func setupStyles() {
        backButton.layer.cornerRadius = 20
        backIcon.isUserInteractionEnabled = false
        backIcon.image = RoomKitResources.image(named: "roomkit_icon_back")
        backButton.accessibilityLabel = .commonBack

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center

        applyTheme()
    }

    private func setupBindings() {
        backButton.addTarget(self, action: #selector(handleBackTap), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(handleBackHighlight), for: [.touchDown, .touchDragEnter])
        backButton.addTarget(self, action: #selector(handleBackUnhighlight),
                             for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgSurface
        titleLabel.textColor = UIColor.roomKitFgPrimary
    }
}

extension RoomNavigationBar {

    @objc private func handleBackTap() {
        onBack?()
    }

    @objc private func handleBackHighlight() {
        backButton.alpha = 0.72
    }

    @objc private func handleBackUnhighlight() {
        backButton.alpha = 1
    }
}

extension String {
    fileprivate static var commonBack: String { RoomKitResources.localizedString("roomkit.common.back") }
}
