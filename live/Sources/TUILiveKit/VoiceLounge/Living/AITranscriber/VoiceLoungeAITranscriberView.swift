import Combine
import SnapKit
import UIKit

final class VoiceLoungeAITranscriberView: UIView {
    static let height: CGFloat = 146

    private let store: VoiceLoungeAITranscriberStore
    private let textLabel = LiveText.voiceLounge(.caption, tone: .secondary)
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
        addSubview(textLabel)
        addSubview(dotsView)
    }

    private func setupConstraints() {
        textLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(14)
            make.bottom.lessThanOrEqualTo(dotsView.snp.top).offset(-8)
        }
        dotsView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(14)
        }
    }

    private func setupStyles() {
        backgroundColor = VoiceLoungeColor.card
        layer.cornerRadius = 16
        isUserInteractionEnabled = false
        textLabel.numberOfLines = 0
        textLabel.lineBreakMode = .byTruncatingHead
    }

    private func setupBindings() { store.changes.sink { [weak self] in self?.render() }.store(in: &cancellables) }

    private func render() {
        isHidden = !store.isEnabled
        guard store.isEnabled else { return }
        let lines = store.lines
        guard !lines.isEmpty else {
            textLabel.attributedText = nil
            textLabel.text = .transcriberWaiting
            return
        }
        let text = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: "\n")) }
            text.append(
                NSAttributedString(
                    string: "\(line.speaker)：",
                    attributes: [.font: textLabel.font as Any, .foregroundColor: LiveTheme.Color.nickname]))
            text.append(
                NSAttributedString(
                    string: line.text,
                    attributes: [.font: textLabel.font as Any, .foregroundColor: LiveTheme.Color.text(.primary)]))
        }
        textLabel.attributedText = text
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        for (i, dot) in dots.enumerated() {
            dot.layer.removeAnimation(forKey: "pulse")
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.3
            pulse.toValue = 1
            pulse.duration = 0.6
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.beginTime = CACurrentMediaTime() + Double(i) * 0.12
            pulse.isRemovedOnCompletion = false
            dot.layer.add(pulse, forKey: "pulse")
        }
    }
}

private extension String {
    static var transcriberWaiting: String { LiveKitResources.localizedString("tuilivekit.voiceroom.caption.waiting") }
}
