import AtomicXCore
import Combine
import SnapKit
import UIKit

final class VoiceLoungeAITranscriberView: UIView {
    static let height: CGFloat = 146
    static let collapsedHeight: CGFloat = 48

    var onTap: (() -> Void)?

    var fitsContent = false {
        didSet {
            guard fitsContent != oldValue else { return }
            rebuildCardConstraints()
        }
    }
    private var cardHeightConstraint: Constraint?
    private var appliedCardHeight: CGFloat = -1

    private static let paddingV: CGFloat = 12
    private static let paddingH: CGFloat = 14

    private let store: VoiceLoungeAITranscriberStore
    private let cardView = UIView()
    private let linesStack = UIStackView()
    private let hintLabel = LiveText.voiceLounge(.caption, tone: .secondary, alignment: .center)
    private let dotsView = TranscriberDotsView()
    private var cancellables = Set<AnyCancellable>()

    init(store: VoiceLoungeAITranscriberStore) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        render()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(cardView)
        cardView.addSubview(linesStack)
        cardView.addSubview(hintLabel)
        cardView.addSubview(dotsView)
    }

    private func setupConstraints() {
        rebuildCardConstraints()
        linesStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.paddingH)
            make.trailing.equalToSuperview().inset(Self.paddingH)
            make.top.equalToSuperview().offset(Self.paddingV)
            make.bottom.lessThanOrEqualToSuperview().inset(Self.paddingV)
        }
        hintLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.paddingH)
            make.trailing.equalToSuperview().inset(Self.paddingH)
            make.center.equalToSuperview()
        }
        dotsView.snp.makeConstraints { make in make.center.equalToSuperview() }
    }

    private func setupStyles() {
        backgroundColor = .clear
        cardView.backgroundColor = VoiceLoungeColor.transcriberCard
        cardView.layer.cornerRadius = 16
        cardView.isUserInteractionEnabled = false
        isUserInteractionEnabled = true
        linesStack.axis = .vertical
        linesStack.spacing = 6
        linesStack.alignment = .fill
        hintLabel.text = .transcriberHintTap
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() { onTap?() }

    private func setupBindings() {
        store.changes.sink { [weak self] in
            self?.render()
            self?.setNeedsLayout()
        }.store(in: &cancellables)
    }

    private func rebuildCardConstraints() {
        cardView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            if fitsContent {
                make.bottom.lessThanOrEqualToSuperview()
                cardHeightConstraint = make.height.equalTo(Self.height).constraint
            } else {
                cardHeightConstraint = nil
                make.bottom.equalToSuperview()
            }
        }
        appliedCardHeight = -1
        updateCardHeight()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardHeight()
    }

    private func updateCardHeight() {
        guard fitsContent, let cardHeightConstraint else { return }
        let target = measuredContentHeight()
        guard abs(target - appliedCardHeight) > 0.5 else { return }
        appliedCardHeight = target
        cardHeightConstraint.update(offset: target)
    }

    private func measuredContentHeight() -> CGFloat {
        let maxHeight = Self.height
        guard store.isEnabled else { return maxHeight }
        if store.lines.isEmpty { return min(maxHeight, Self.collapsedHeight) }
        let fallbackWidth = UIScreen.main.bounds.width - 2 * Self.paddingH
        let contentWidth = (bounds.width > 0 ? bounds.width : fallbackWidth) - 2 * Self.paddingH
        guard contentWidth > 0 else { return maxHeight }
        let fitting = linesStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: 0), withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)
        return min(maxHeight, ceil(fitting.height) + 2 * Self.paddingV)
    }

    private func render() {
        let lines = store.lines
        isHidden = !store.isEnabled
        guard store.isEnabled else { return }
        let textFontSize = max(1, store.scale.fontSize - 2)
        let nameFontSize = max(1, textFontSize - 1)

        if lines.isEmpty {
            linesStack.isHidden = true
            clearBlocks()
            if store.isHintActive {
                hintLabel.isHidden = false
                dotsView.isHidden = true
            } else {
                hintLabel.isHidden = true
                dotsView.isHidden = false
            }
            return
        }

        hintLabel.isHidden = true
        dotsView.isHidden = true
        linesStack.isHidden = false
        rebuildBlocks(count: lines.count)
        for (index, line) in lines.enumerated() {
            guard let block = linesStack.arrangedSubviews[index] as? SpeakerBlock else { continue }
            let primary = line.translated.isEmpty ? line.source : line.translated
            let original = store.showOriginal && !line.translated.isEmpty && !line.source.isEmpty ? line.source : nil
            block.configure(
                name: line.speaker, text: primary, original: original, nameFontSize: nameFontSize,
                textFontSize: textFontSize)
        }
        updateCardHeight()
    }

    private func clearBlocks() {
        linesStack.arrangedSubviews.forEach {
            linesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func rebuildBlocks(count: Int) {
        while linesStack.arrangedSubviews.count > count {
            guard let last = linesStack.arrangedSubviews.last else { break }
            linesStack.removeArrangedSubview(last)
            last.removeFromSuperview()
        }
        while linesStack.arrangedSubviews.count < count { linesStack.addArrangedSubview(SpeakerBlock()) }
    }
}

private final class SpeakerBlock: UIView {
    private let nameLabel = GradientTextLabel()
    private let textLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.gradientColors = VoiceLoungeColor.transcriberNameGradient
        textLabel.numberOfLines = 0
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.textColor = LiveTheme.Color.text(.primary)
        addSubview(nameLabel)
        addSubview(textLabel)
        nameLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        textLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(name: String, text: String, original: String?, nameFontSize: CGFloat, textFontSize: CGFloat) {
        nameLabel.font = UIFont.systemFont(ofSize: nameFontSize, weight: .medium)
        nameLabel.text = name
        textLabel.font = UIFont.systemFont(ofSize: textFontSize)
        if let original {
            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: textFontSize), .foregroundColor: LiveTheme.Color.text(.primary),
                ])
            attributed.append(NSAttributedString(string: "\n"))
            attributed.append(
                NSAttributedString(
                    string: original,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: max(1, textFontSize * 0.9)),
                        .foregroundColor: LiveTheme.Color.text(.tertiary),
                    ]))
            textLabel.attributedText = attributed
        } else {
            textLabel.attributedText = nil
            textLabel.text = text
        }
    }
}

private final class GradientTextLabel: UILabel {
    var gradientColors: [UIColor] = [] { didSet { setNeedsDisplay() } }

    override func drawText(in rect: CGRect) {
        guard gradientColors.count >= 2, let context = UIGraphicsGetCurrentContext() else {
            super.drawText(in: rect)
            return
        }
        let maskImage = UIGraphicsImageRenderer(bounds: bounds).image { _ in super.drawText(in: rect) }
        guard let mask = maskImage.cgImage else {
            super.drawText(in: rect)
            return
        }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: bounds, mask: mask)
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors.map { $0.cgColor } as CFArray,
            locations: [0, 1])
        if let gradient {
            context.drawLinearGradient(
                gradient, start: CGPoint(x: bounds.minX, y: bounds.midY), end: CGPoint(x: bounds.maxX, y: bounds.midY),
                options: [])
        }
        context.restoreGState()
    }
}

private final class TranscriberDotsView: UIView {
    private let sizes: [CGFloat] = [3, 4, 5, 5, 4, 3]
    private var dots: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        for size in sizes {
            let dot = UIView()
            dot.backgroundColor = UIColor.white.withAlphaComponent(0.55)
            dot.layer.cornerRadius = size / 2
            dot.snp.makeConstraints { $0.size.equalTo(size) }
            stack.addArrangedSubview(dot)
            dots.append(dot)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private extension String {
    static var transcriberHintTap: String { LiveKitResources.localizedString("tuilivekit.voiceroom.caption.hint_tap") }
}
