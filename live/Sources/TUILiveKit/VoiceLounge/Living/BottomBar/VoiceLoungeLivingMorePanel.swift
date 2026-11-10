import SnapKit
import UIKit

final class VoiceLoungeLivingMorePanel: BottomSheetView {
    var onComment: (() -> Void)?

    private let settings: VoiceLoungeSettings
    private let livingActions: VoiceLoungeLivingActions
    private lazy var layoutPanel: VoiceLoungeSeatLayoutPanel = {
        let panel = VoiceLoungeSeatLayoutPanel()
        panel.onConfirm = { [weak self] layout, _ in self?.livingActions.changeLayout(layout) }
        return panel
    }()

    private let pauseItem = BigButton(iconKind: .pause, titleKey: "tuilivekit.voiceroom.living.pause")

    private let basicTitle = LiveText.voiceLounge(.metadata, tone: .tertiary, emphasized: true)
    private let layoutItem = SmallButton(iconKind: .layout, titleKey: "tuilivekit.voiceroom.prepare.more_layout")

    private let interactTitle = LiveText.voiceLounge(.metadata, tone: .tertiary, emphasized: true)
    private let commentItem = SmallButton(iconKind: .comment, titleKey: "tuilivekit.voiceroom.living.comment")

    private let topRow: UIStackView
    private let basicRow: UIStackView
    private let interactRow: UIStackView

    override var sheetHeight: CGFloat { 372 + safeAreaInsets.bottom }

    init(settings: VoiceLoungeSettings, livingActions: VoiceLoungeLivingActions) {
        self.settings = settings
        self.livingActions = livingActions
        topRow = Self.makeFourColumnRow(items: [pauseItem])
        basicRow = Self.makeFourColumnRow(items: [layoutItem])
        interactRow = Self.makeFourColumnRow(items: [commentItem])
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) override init(frame: CGRect) {
        fatalError("init(frame:) is unavailable; use init(settings:livingActions:)")
    }

    func show() { present() }

    private func setupViews() {
        contentView.addSubview(topRow)
        contentView.addSubview(basicTitle)
        contentView.addSubview(basicRow)
        contentView.addSubview(interactTitle)
        contentView.addSubview(interactRow)
    }

    private func setupConstraints() {
        let hInset: CGFloat = 24
        topRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(hInset)
            make.top.equalToSuperview().offset(26)
        }
        basicTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(hInset)
            make.top.equalTo(topRow.snp.bottom).offset(24)
        }
        basicRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(hInset)
            make.top.equalTo(basicTitle.snp.bottom).offset(14)
        }
        interactTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(hInset)
            make.top.equalTo(basicRow.snp.bottom).offset(24)
        }
        interactRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(hInset)
            make.top.equalTo(interactTitle.snp.bottom).offset(14)
            make.bottom.lessThanOrEqualToSuperview().inset(24)
        }
    }

    private func setupStyles() {
        sheetTitle = nil
        basicTitle.text = .sectionBasic
        interactTitle.text = .sectionInteract
    }

    private func setupBindings() {
        pauseItem.onTap = { [weak self] in
            self?.dismiss()
            self?.livingActions.pauseLive()
        }
        layoutItem.onTap = { [weak self] in
            self?.dismiss()
            self?.showLayoutPicker()
        }
        commentItem.onTap = { [weak self] in
            self?.dismiss()
            self?.onComment?()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else {
            [layoutPanel].forEach { $0.removeFromSuperview() }
            return
        }
        [layoutPanel].forEach { panel in
            guard panel.superview !== window else { return }
            panel.removeFromSuperview()
            window.addSubview(panel)
            panel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }

    private func showLayoutPicker() {
        layoutPanel.show(selected: settings.seatLayout, setAsDefault: false, skin: settings.skin)
    }

    private static func makeFourColumnRow(items: [UIView]) -> UIStackView {
        var cells = items
        while cells.count < 4 { cells.append(UIView()) }
        let row = UIStackView(arrangedSubviews: cells)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.alignment = .top
        return row
    }
}

private final class BigButton: UIControl {
    var onTap: (() -> Void)?

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.caption, tone: .primary, alignment: .center)

    init(iconKind: IconKind, titleKey: String) {
        super.init(frame: .zero)
        iconBackground.backgroundColor = VoiceLoungeColor.overlaySoft
        iconBackground.layer.cornerRadius = 26
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = iconKind.image
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconBackground.addSubview(iconView)

        titleLabel.text = LiveKitResources.localizedString(titleKey)
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        iconBackground.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(52)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(26)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func tap() { onTap?() }
}

private final class SmallButton: UIControl {
    var onTap: (() -> Void)?

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.caption, tone: .primary, alignment: .center)

    init(iconKind: IconKind, titleKey: String) {
        super.init(frame: .zero)
        iconBackground.backgroundColor = VoiceLoungeColor.overlaySoft
        iconBackground.layer.cornerRadius = 22
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = iconKind.image
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconBackground.addSubview(iconView)

        titleLabel.text = LiveKitResources.localizedString(titleKey)
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        iconBackground.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(44)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(7)
            make.leading.trailing.bottom.equalToSuperview()
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func tap() { onTap?() }
}

private enum IconKind {
    case pause, layout, comment

    var image: UIImage? {
        let name: String
        switch self {
        case .pause: name = "livekit_living_setting_pause"
        case .layout: name = "livekit_living_more"
        case .comment: name = "livekit_living_setting_comment"
        }
        return LiveKitResources.image(named: name)
    }
}

private extension String {
    static var sectionBasic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.section_basic") }
    static var sectionInteract: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.living.section_interact")
    }
}
