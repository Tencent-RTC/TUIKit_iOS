import SnapKit
import UIKit

final class VoiceLoungeLivingMorePanel: BottomSheetView {
    var onComment: (() -> Void)?

    private let settings: VoiceLoungeSettings
    private let livingActions: VoiceLoungeLivingActions
    private lazy var layoutPanel: VoiceLoungeSeatLayoutPanel = {
        let panel = VoiceLoungeSeatLayoutPanel()
        panel.onConfirm = { [weak self] layout in self?.livingActions.changeLayout(layout) }
        return panel
    }()

    private let pauseItem = MoreItemButton(iconName: "livekit_living_setting_pause", title: .pauseLive)
    private let layoutItem = MoreItemButton(iconName: "livekit_living_more", title: .layoutSetting)
    private let transcriberItem = MoreItemButton(image: MoreGlyph.transcriberImage(), title: .transcriber)
    private let commentItem = MoreItemButton(iconName: "livekit_living_setting_comment", title: .comment)
    private let itemsRow = UIStackView()

    override var sheetHeight: CGFloat { MoreStyle.contentHeight + safeAreaInsets.bottom }

    init(settings: VoiceLoungeSettings, livingActions: VoiceLoungeLivingActions) {
        self.settings = settings
        self.livingActions = livingActions
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupBindings()
    }

    @available(*, unavailable) override init(frame: CGRect) {
        fatalError("init(frame:) is unavailable; use init(settings:livingActions:)")
    }

    func show() {
        transcriberItem.applyTranscriberState(isOn: settings.isTranscriberEnabled)
        present()
    }

    private func setupViews() {
        sheetTitle = nil
        let cells: [UIView] = [pauseItem, layoutItem, transcriberItem, commentItem]
        cells.forEach(itemsRow.addArrangedSubview)
        itemsRow.axis = .horizontal
        itemsRow.distribution = .fillEqually
        itemsRow.alignment = .top
        contentView.addSubview(itemsRow)
    }

    private func setupConstraints() {
        itemsRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MoreStyle.horizontalInset)
            make.top.equalToSuperview().offset(MoreStyle.topInset)
        }
    }

    private func setupBindings() {
        pauseItem.addTarget(self, action: #selector(pauseLive), for: .touchUpInside)
        layoutItem.addTarget(self, action: #selector(showLayoutPicker), for: .touchUpInside)
        transcriberItem.addTarget(self, action: #selector(toggleTranscriber), for: .touchUpInside)
        commentItem.addTarget(self, action: #selector(comment), for: .touchUpInside)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else {
            layoutPanel.removeFromSuperview()
            return
        }
        if layoutPanel.superview !== window {
            layoutPanel.removeFromSuperview()
            window.addSubview(layoutPanel)
            layoutPanel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }
}

extension VoiceLoungeLivingMorePanel {
    @objc private func pauseLive() {
        dismiss()
        livingActions.pauseLive()
    }

    @objc private func showLayoutPicker() {
        dismiss()
        layoutPanel.show(selected: settings.seatLayout, setAsDefault: true, skin: settings.skin)
    }

    @objc private func toggleTranscriber() {
        let nextEnabled = !settings.isTranscriberEnabled
        let state = VoiceLoungeAITranscriberPanel.State(
            isEnabled: nextEnabled, showOriginal: settings.transcriberShowOriginal, scale: settings.transcriberScale,
            language: settings.transcriberLanguage, saveAsDefault: false)
        livingActions.updateTranscriber(state)
        transcriberItem.applyTranscriberState(isOn: settings.isTranscriberEnabled)
    }

    @objc private func comment() {
        dismiss()
        onComment?()
    }
}

private final class MoreItemButton: UIControl {
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.control, tone: .secondary, alignment: .center)
    private var originalImage: UIImage?

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.65 : 1 } }

    convenience init(iconName: String, title: String) {
        self.init(image: LiveKitResources.image(named: iconName), title: title)
    }

    init(image: UIImage?, title: String) {
        super.init(frame: .zero)
        originalImage = image
        iconBackground.backgroundColor = VoiceLoungeColor.overlaySoft
        iconBackground.layer.cornerRadius = MoreStyle.iconPlate / 2
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = image
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        accessibilityLabel = title

        iconBackground.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.centerX.equalToSuperview()
            make.size.equalTo(MoreStyle.iconPlate)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(MoreStyle.iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(4)
            make.bottom.equalToSuperview().inset(4)
        }
    }

    func applyTranscriberState(isOn: Bool) {
        iconBackground.backgroundColor = isOn ? .white : VoiceLoungeColor.overlaySoft
        iconView.image = MoreGlyph.transcriberImage(strokeColor: isOn ? .black : .white)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private enum MoreStyle {
    static let horizontalInset: CGFloat = 20
    static let topInset: CGFloat = 30
    static let iconPlate: CGFloat = 50
    static let iconSize: CGFloat = 26
    static let contentHeight: CGFloat = 124
}

private enum MoreGlyph {
    static func transcriberImage(strokeColor: UIColor = .white) -> UIImage {
        let size = CGSize(width: MoreStyle.iconSize, height: MoreStyle.iconSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let scale = size.width / 24
            ctx.cgContext.scaleBy(x: scale, y: scale)
            strokeColor.setStroke()
            let path = VoiceLoungeTranscriberGlyph.path()
            path.lineWidth = 1.8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
        return image
    }
}

private extension String {
    static var pauseLive: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.pause") }
    static var layoutSetting: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.layout_setting") }
    static var transcriber: String { LiveKitResources.localizedString("tuilivekit.voiceroom.caption.title") }
    static var comment: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.comment") }
}
