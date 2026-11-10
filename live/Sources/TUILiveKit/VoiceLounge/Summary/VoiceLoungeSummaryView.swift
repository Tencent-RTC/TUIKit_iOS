import SnapKit
import UIKit

struct VoiceLoungeSummaryData: Equatable {
    var startTime: Date?
    var endTime: Date = Date()
    var giftCount: Int = 0
    var newFollowers: Int = 0
    var viewers: Int = 0
    var fanViewers: Int = 0
    var gifters: Int = 0
    var likes: Int = 0
}

final class VoiceLoungeSummaryView: UIView {
    var onExit: (() -> Void)?

    private let backgroundView = UIImageView()
    private let scrollView = UIScrollView()
    private let timeRangeLabel = LiveText.voiceLounge(.control, tone: .tertiary, alignment: .center)
    private let durationLabel = UILabel()

    private let statCards: [SummaryStatCard]
    private lazy var scrollContentView = UIView()
    private lazy var header = makeHeader()
    private lazy var hero = makeHeroCard()
    private lazy var sectionTitle: UILabel = {
        let label = LiveText.voiceLounge(.prominent, tone: .primary)
        label.text = .section
        return label
    }()
    private lazy var statGrid = makeStatGrid()
    private lazy var note: UILabel = {
        let label = LiveText.voiceLounge(.metadata, tone: .tertiary, alignment: .center)
        label.text = .note
        return label
    }()

    override init(frame: CGRect) {
        statCards = [
            SummaryStatCard(
                titleKey: "tuilivekit.voiceroom.summary.gift", unitKey: "tuilivekit.voiceroom.summary.unit_items",
                accent: SummaryStyle.giftAccent),
            SummaryStatCard(
                titleKey: "tuilivekit.voiceroom.summary.followers", unitKey: "tuilivekit.voiceroom.summary.unit_people",
                accent: SummaryStyle.followersAccent),
            SummaryStatCard(
                titleKey: "tuilivekit.voiceroom.summary.viewers", unitKey: "tuilivekit.voiceroom.summary.unit_people",
                accent: SummaryStyle.viewersAccent),
            SummaryStatCard(
                titleKey: "tuilivekit.voiceroom.summary.fan_viewers",
                unitKey: "tuilivekit.voiceroom.summary.unit_people", accent: SummaryStyle.fanAccent),
            SummaryStatCard(
                titleKey: "tuilivekit.voiceroom.summary.gifters", unitKey: "tuilivekit.voiceroom.summary.unit_people",
                accent: SummaryStyle.giftersAccent),
            SummaryStatCard(
                titleKey: "tuilivekit.voiceroom.summary.likes", unitKey: "tuilivekit.voiceroom.summary.unit_times",
                accent: SummaryStyle.likesAccent),
        ]
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(backgroundView)
        addSubview(scrollView)
        scrollView.addSubview(scrollContentView)
        [header, hero, sectionTitle, statGrid, note].forEach(scrollContentView.addSubview)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollContentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        header.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(8)
            make.height.equalTo(44)
        }
        hero.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(header.snp.bottom).offset(10)
            make.height.equalTo(210)
        }
        sectionTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(19)
            make.top.equalTo(hero.snp.bottom).offset(20)
        }
        statGrid.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sectionTitle.snp.bottom).offset(10)
            make.height.equalTo(252)
        }
        note.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(statGrid.snp.bottom).offset(16)
            make.bottom.equalToSuperview().inset(24)
        }
    }

    private func setupStyles() {
        backgroundColor = LiveTheme.Color.canvasBackground
        backgroundView.image = LiveKitResources.image(named: "livekit_summary_bg")
        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        scrollView.showsVerticalScrollIndicator = false
    }

    private func setupBindings() {}

    func bind(_ input: VoiceLoungeSummaryData) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = input.startTime.map(formatter.string) ?? "--:--"
        let end = formatter.string(from: input.endTime)
        timeRangeLabel.text = "\(start) ~ \(end)"
        let duration = input.startTime.map { max(0, Int(input.endTime.timeIntervalSince($0))) } ?? 0
        durationLabel.text = Self.formatDuration(duration)

        let values = [input.giftCount, input.newFollowers, input.viewers, input.fanViewers, input.gifters, input.likes]
        zip(statCards, values).forEach { $0.bind(value: $1) }
    }

    private func makeHeader() -> UIView {
        let container = UIView()
        let back = UIButton(type: .custom)
        back.setImage(LiveKitResources.image(named: "livekit_summary_back"), for: .normal)
        back.imageView?.contentMode = .scaleAspectFit
        back.addTarget(self, action: #selector(exit), for: .touchUpInside)
        container.addSubview(back)

        let title = LiveText.voiceLounge(.sheetTitle, tone: .primary, alignment: .center)
        title.text = .title
        container.addSubview(title)

        back.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(34)
        }
        title.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(back.snp.trailing)
        }
        return container
    }

    private func makeHeroCard() -> UIView {
        let card = SummaryCard(style: .hero)

        let ring = UIView()
        ring.backgroundColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.1)
        ring.layer.cornerRadius = 26
        card.addSubview(ring)

        let mark = UIView()
        mark.backgroundColor = SummaryStyle.markBackground
        mark.layer.cornerRadius = 21
        mark.layer.borderWidth = 1
        mark.layer.borderColor = LiveTheme.Color.brandBlue.cgColor
        card.addSubview(mark)

        let check = UIImageView(image: LiveKitResources.image(named: "livekit_summary_done"))
        check.contentMode = .scaleAspectFit
        mark.addSubview(check)

        let ended = UILabel()
        ended.text = .ended
        ended.textColor = UIColor.white.withAlphaComponent(0.95)
        ended.font = .systemFont(ofSize: 20, weight: .bold)
        ended.textAlignment = .center
        card.addSubview(ended)

        card.addSubview(timeRangeLabel)

        let durationTitle = UILabel()
        durationTitle.text = .duration
        durationTitle.textColor = UIColor.white.withAlphaComponent(0.48)
        durationTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        durationTitle.textAlignment = .center
        card.addSubview(durationTitle)

        durationLabel.textColor = SummaryStyle.durationForeground
        durationLabel.font = .systemFont(ofSize: 31, weight: .bold)
        durationLabel.textAlignment = .center
        card.addSubview(durationLabel)

        ring.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.size.equalTo(52)
        }
        mark.snp.makeConstraints { make in
            make.center.equalTo(ring)
            make.size.equalTo(42)
        }
        check.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 16))
        }
        ended.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(30)
            make.top.equalTo(ring.snp.bottom).offset(12)
        }
        timeRangeLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(30)
            make.top.equalTo(ended.snp.bottom).offset(6)
        }
        durationTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(30)
            make.top.equalTo(timeRangeLabel.snp.bottom).offset(14)
        }
        durationLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(30)
            make.top.equalTo(durationTitle.snp.bottom).offset(4)
        }
        return card
    }

    private func makeStatGrid() -> UIStackView {
        let rows = stride(from: 0, to: statCards.count, by: 2).map { index -> UIStackView in
            let row = UIStackView(arrangedSubviews: Array(statCards[index...index + 1]))
            row.distribution = .fillEqually
            row.spacing = 10
            return row
        }
        let grid = UIStackView(arrangedSubviews: rows)
        grid.axis = .vertical
        grid.distribution = .fillEqually
        grid.spacing = 10
        return grid
    }

    private static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }

}

extension VoiceLoungeSummaryView { @objc private func exit() { onExit?() } }

private final class SummaryStatCard: SummaryCard {
    private let valueLabel = UILabel()

    init(titleKey: String, unitKey: String, accent: UIColor) {
        super.init(style: .stat(accent))

        let accentBar = UIView()
        accentBar.backgroundColor = accent
        accentBar.layer.cornerRadius = 2
        addSubview(accentBar)

        let titleLabel = LiveText.voiceLounge(.metadata, tone: .tertiary, emphasized: true)
        titleLabel.text = LiveKitResources.localizedString(titleKey)
        addSubview(titleLabel)

        valueLabel.textColor = UIColor.white.withAlphaComponent(0.94)
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5

        let unitLabel = LiveText.voiceLounge(.metadata, tone: .disabled)
        unitLabel.text = LiveKitResources.localizedString(unitKey)
        unitLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueStack = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        valueStack.axis = .horizontal
        valueStack.alignment = .lastBaseline
        valueStack.spacing = 5
        addSubview(valueStack)

        accentBar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(13)
            make.top.equalToSuperview().offset(14)
            make.size.equalTo(CGSize(width: 16, height: 4))
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(13)
            make.top.equalToSuperview().offset(27)
        }
        valueStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(13)
            make.trailing.lessThanOrEqualToSuperview().inset(13)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(value: Int) { valueLabel.text = String(max(0, value)) }
}

private class SummaryCard: UIView {
    enum Style {
        case hero
        case stat(UIColor)
    }

    private let baseGradient = CAGradientLayer()
    private let accentGradient = CAGradientLayer()

    init(style: Style) {
        super.init(frame: .zero)
        let radius: CGFloat
        switch style {
        case .hero:
            radius = 22
            baseGradient.colors = [
                UIColor.white.withAlphaComponent(0.065).cgColor, UIColor.white.withAlphaComponent(0.025).cgColor,
            ]
            baseGradient.startPoint = CGPoint(x: 0.5, y: 0)
            baseGradient.endPoint = CGPoint(x: 0.5, y: 1)
            accentGradient.colors = [
                LiveTheme.Color.brandBlue.withAlphaComponent(0.13).cgColor,
                LiveTheme.Color.brandBlue.withAlphaComponent(0).cgColor,
            ]
            accentGradient.startPoint = CGPoint(x: 0.5, y: 0)
            accentGradient.endPoint = CGPoint(x: 0.5, y: 1)
            layer.borderColor = UIColor.white.withAlphaComponent(0.085).cgColor
        case .stat(let color):
            radius = 16
            baseGradient.colors = [
                UIColor.white.withAlphaComponent(0.055).cgColor, UIColor.white.withAlphaComponent(0.022).cgColor,
            ]
            baseGradient.startPoint = CGPoint(x: 0, y: 0.5)
            baseGradient.endPoint = CGPoint(x: 1, y: 0.5)
            accentGradient.colors = [color.withAlphaComponent(0).cgColor, color.withAlphaComponent(0.085).cgColor]
            accentGradient.startPoint = CGPoint(x: 0, y: 0.5)
            accentGradient.endPoint = CGPoint(x: 1, y: 0.5)
            layer.borderColor = UIColor.white.withAlphaComponent(0.065).cgColor
        }
        layer.cornerRadius = radius
        layer.borderWidth = 1
        baseGradient.cornerRadius = radius
        accentGradient.cornerRadius = radius
        layer.insertSublayer(baseGradient, at: 0)
        layer.insertSublayer(accentGradient, at: 1)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseGradient.frame = bounds
        accentGradient.frame = bounds
    }
}

private enum SummaryStyle {
    static let giftAccent = UIColor(red: 0.941, green: 0.737, blue: 0.373, alpha: 1)
    static let followersAccent = UIColor(red: 1, green: 0.431, blue: 0.616, alpha: 1)
    static let viewersAccent = UIColor(red: 0.412, green: 0.659, blue: 1, alpha: 1)
    static let fanAccent = UIColor(red: 0.745, green: 0.514, blue: 1, alpha: 1)
    static let giftersAccent = UIColor(red: 0.341, green: 0.835, blue: 0.749, alpha: 1)
    static let likesAccent = UIColor(red: 1, green: 0.482, blue: 0.447, alpha: 1)
    static let markBackground = UIColor(red: 0.098, green: 0.243, blue: 0.42, alpha: 1)
    static let durationForeground = VoiceLoungeColor.statHighlight
}

private extension String {
    static var duration: String { LiveKitResources.localizedString("tuilivekit.voiceroom.summary.duration") }
    static var ended: String { LiveKitResources.localizedString("tuilivekit.voiceroom.summary.ended") }
    static var note: String { LiveKitResources.localizedString("tuilivekit.voiceroom.summary.note") }
    static var section: String { LiveKitResources.localizedString("tuilivekit.voiceroom.summary.section") }
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.summary.title") }
}
