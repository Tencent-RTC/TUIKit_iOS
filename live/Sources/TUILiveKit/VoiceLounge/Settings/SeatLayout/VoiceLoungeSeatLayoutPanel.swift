import SnapKit
import UIKit

final class VoiceLoungeSeatLayoutPanel: BottomSheetView {
    var onConfirm: ((_ layout: VoiceLoungeSeatLayout, _ setAsDefault: Bool) -> Void)?

    private let confirmButton = UIButton(type: .system)
    private let cardRow = UIStackView()
    private let defaultCheckbox = CheckboxRow()

    private var layouts: [VoiceLoungeSeatLayout] = []
    private var cards: [VoiceLoungeSeatLayout: LayoutCard] = [:]
    private var selected: VoiceLoungeSeatLayout = .oneV8
    private var skin = VoiceLoungeSkin.defaultSkin

    override var sheetHeight: CGFloat { 278 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func show(selected: VoiceLoungeSeatLayout, setAsDefault: Bool, skin: VoiceLoungeSkin) {
        layouts = VoiceLoungeSeatLayout.allCases
        self.selected = layouts.contains(selected) ? selected : (layouts.first ?? .oneV8)
        self.skin = skin
        defaultCheckbox.isOn = setAsDefault
        defaultCheckbox.apply(skin: skin)
        rebuildCards()
        syncSelection()
        confirmButton.setTitleColor(Self.lighten(skin.mid), for: .normal)
        present()
    }

    private func setupViews() {
        contentView.addSubview(confirmButton)
        contentView.addSubview(cardRow)
        contentView.addSubview(defaultCheckbox)
    }

    private func setupConstraints() {
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(26)
            make.height.equalTo(28)
        }
        cardRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(confirmButton.snp.bottom).offset(14)
            make.height.equalTo(128)
        }
        defaultCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(18)
            make.top.equalTo(cardRow.snp.bottom).offset(14)
            make.trailing.lessThanOrEqualToSuperview().inset(18)
            make.height.equalTo(20)
        }
    }

    private func setupStyles() {
        sheetTitle = .title
        confirmButton.setTitle(.confirm, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmButton.setTitleColor(LiveTheme.Color.brandCyan, for: .normal)
        cardRow.axis = .horizontal
        cardRow.distribution = .fillEqually
        cardRow.spacing = 10
        defaultCheckbox.setTitle(.defaultHint)
    }

    private func setupBindings() { confirmButton.addTarget(self, action: #selector(tapConfirm), for: .touchUpInside) }

    private func rebuildCards() {
        cardRow.arrangedSubviews.forEach {
            cardRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        cards.removeAll()
        for layout in layouts {
            let card = LayoutCard(layout: layout)
            card.onTap = { [weak self] in self?.select($0) }
            cards[layout] = card
            cardRow.addArrangedSubview(card)
        }
    }

    private func select(_ layout: VoiceLoungeSeatLayout) {
        guard selected != layout else { return }
        selected = layout
        syncSelection()
    }

    private func syncSelection() {
        cards.forEach { layout, card in card.apply(isSelected: layout == selected, skin: skin) }
    }

    private static func lighten(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        return UIColor(hue: h, saturation: max(0, s - 0.3), brightness: min(1, b + 0.3), alpha: 1)
    }
}

extension VoiceLoungeSeatLayoutPanel {
    @objc private func tapConfirm() {
        onConfirm?(selected, defaultCheckbox.isOn)
        dismiss()
    }
}

private final class LayoutCard: UIControl {
    var onTap: ((VoiceLoungeSeatLayout) -> Void)?

    private let layout: VoiceLoungeSeatLayout
    private let previewView = LayoutPreviewView()
    private let titleLabel = LiveText.voiceLounge(.caption, tone: .secondary, alignment: .center, emphasized: true)

    init(layout: VoiceLoungeSeatLayout) {
        self.layout = layout
        super.init(frame: .zero)
        backgroundColor = VoiceLoungeColor.card
        layer.cornerRadius = 12
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.clear.cgColor

        previewView.layout = layout
        previewView.isUserInteractionEnabled = false
        addSubview(previewView)

        titleLabel.text = layout.displayName
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        previewView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(72)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(previewView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(4)
            make.bottom.lessThanOrEqualToSuperview().inset(10)
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func apply(isSelected: Bool, skin: VoiceLoungeSkin) {
        layer.borderColor = isSelected ? skin.mid.cgColor : UIColor.clear.cgColor
        titleLabel.tone = isSelected ? .primary : .secondary
        previewView.accentColor = skin.mid
        previewView.isSelected = isSelected
        previewView.setNeedsDisplay()
    }

    @objc private func tap() { onTap?(layout) }
}

private final class LayoutPreviewView: UIView {
    var layout: VoiceLoungeSeatLayout = .oneV8
    var accentColor: UIColor = LiveTheme.Color.brandCyan
    var isSelected: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let hostColor = isSelected ? accentColor : UIColor.white.withAlphaComponent(0.7)
        let guestColor = UIColor.white.withAlphaComponent(0.55)
        let r: CGFloat = 4

        func dot(_ x: CGFloat, _ y: CGFloat, _ color: UIColor) {
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r))
        }

        let w = rect.width, h = rect.height
        switch layout {
        case .oneV8:
            dot(w / 2, 10, hostColor)
            for row in 0..<2 {
                for col in 0..<4 {
                    let x = w / 2 - 18 + CGFloat(col) * 12
                    let y = 28 + CGFloat(row) * 12
                    dot(x, y, guestColor)
                }
            }
        case .oneV8x:
            dot(w * 0.25, h / 2, hostColor)
            for i in 0..<8 {
                let y = 8 + CGFloat(i) * (h - 16) / 7
                dot(w * 0.7, y, guestColor)
            }
        case .twoV8:
            dot(w / 2 - 6, 10, hostColor)
            dot(w / 2 + 6, 10, hostColor)
            for row in 0..<2 {
                for col in 0..<4 {
                    let x = w / 2 - 18 + CGFloat(col) * 12
                    let y = 28 + CGFloat(row) * 12
                    dot(x, y, guestColor)
                }
            }
        case .duo:
            dot(w * 0.22, h / 2, hostColor)
            dot(w * 0.78, h / 2, guestColor)
            ctx.setStrokeColor(hostColor.cgColor)
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)
            let mid = h / 2
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w * 0.3, y: mid))
            path.addLine(to: CGPoint(x: w * 0.4, y: mid))
            path.addLine(to: CGPoint(x: w * 0.45, y: mid - 6))
            path.addLine(to: CGPoint(x: w * 0.5, y: mid + 6))
            path.addLine(to: CGPoint(x: w * 0.55, y: mid - 4))
            path.addLine(to: CGPoint(x: w * 0.6, y: mid))
            path.addLine(to: CGPoint(x: w * 0.72, y: mid))
            path.stroke()
        }
    }
}

private final class CheckboxRow: UIControl {
    var isOn = true { didSet { applyColors() } }

    private let box = UIView()
    private let check = CAShapeLayer()
    private let titleLabel = LiveText.voiceLounge(.caption, tone: .tertiary)
    private var skinMid: UIColor = LiveTheme.Color.brandCyan

    override init(frame: CGRect) {
        super.init(frame: frame)
        box.layer.cornerRadius = 8
        box.isUserInteractionEnabled = false
        addSubview(box)

        check.fillColor = UIColor.clear.cgColor
        check.strokeColor = UIColor.white.cgColor
        check.lineWidth = 1.5
        check.lineCap = .round
        check.lineJoin = .round
        box.layer.addSublayer(check)

        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        box.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(box.snp.trailing).offset(8)
            make.centerY.trailing.equalToSuperview()
        }
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
        applyColors()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        check.frame = box.bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 4, y: 8))
        path.addLine(to: CGPoint(x: 7, y: 11))
        path.addLine(to: CGPoint(x: 12, y: 5))
        check.path = path.cgPath
    }

    func setTitle(_ text: String) { titleLabel.text = text }

    func apply(skin: VoiceLoungeSkin) {
        skinMid = skin.mid
        applyColors()
    }

    private func applyColors() {
        box.backgroundColor = isOn ? skinMid : VoiceLoungeColor.overlaySoft
        check.isHidden = !isOn
    }

    @objc private func toggle() { isOn.toggle() }
}

private extension String {
    static var confirm: String { LiveKitResources.localizedString("tuilivekit.voiceroom.layout.confirm") }
    static var defaultHint: String { LiveKitResources.localizedString("tuilivekit.voiceroom.layout.default_hint") }
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.layout.title") }
}
