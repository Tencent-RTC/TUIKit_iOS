import UIKit
import AtomicXCore
import SnapKit

struct PusherSummaryContext: Equatable {
    let startTime: Date?
    let endTime: Date
    let pausedSeconds: Int
    var interruptionMessage: String? = nil
}

final class PusherSummaryView: UIView, UIGestureRecognizerDelegate {
    var onExit: (() -> Void)?

    private let scrollView = UIScrollView()
    private weak var popGesture: UIGestureRecognizer?
    private weak var previousPopDelegate: UIGestureRecognizerDelegate?
    private var previousPopEnabled = false
    private var didRequestExit = false
    private var context: PusherSummaryContext?
    private var summary: PusherEvent.PusherSummary?
    private let backgroundView: UIImageView = {
        let imageView = UIImageView(image: LiveKitResources.image(named: "livekit_summary_bg"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    private let interruptionLabel = UILabel()
    private let timeRangeLabel = LiveText(.control, tone: .tertiary, alignment: .center)
    private let durationLabel = UILabel()
    private let pauseCapsule = UIView()
    private let pauseDurationLabel = LiveText(.metadata, tone: .secondary, alignment: .right, emphasized: true)
    private let statCards: [SummaryStatCardView] = [
        SummaryStatCardView(title: LiveKitResources.localizedString("tuilivekit.pusher.summary.gifts_received"), unit: LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.items"), accentColor: PusherSummaryStyle.giftsAccent),
        SummaryStatCardView(title: LiveKitResources.localizedString("tuilivekit.pusher.summary.gift_value"), unit: LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.coins"), accentColor: PusherSummaryStyle.giftValueAccent),
        SummaryStatCardView(title: LiveKitResources.localizedString("tuilivekit.pusher.summary.viewers"), unit: LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.people"), accentColor: PusherSummaryStyle.viewersAccent),
        SummaryStatCardView(title: LiveKitResources.localizedString("tuilivekit.pusher.summary.comments"), unit: LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.messages"), accentColor: PusherSummaryStyle.commentsAccent),
        SummaryStatCardView(title: LiveKitResources.localizedString("tuilivekit.pusher.summary.gift_senders"), unit: LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.people"), accentColor: PusherSummaryStyle.sendersAccent),
        SummaryStatCardView(title: LiveKitResources.localizedString("tuilivekit.pusher.summary.likes"), unit: LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.times"), accentColor: PusherSummaryStyle.likesAccent),
    ]

    init() {
        super.init(frame: .zero)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(context: PusherSummaryContext) {
        self.context = context
        didRequestExit = false
        enableInteractiveReturn()
        render()
    }

    func updateSummary(_ summary: PusherEvent.PusherSummary?) {
        self.summary = summary
        render()
    }

    func hide() {
        context = nil
        restoreInteractiveReturn()
    }

    deinit {
        restoreInteractiveReturn()
    }

    private func render() {
        guard let context else { return }
        interruptionLabel.text = context.interruptionMessage
            ?? LiveKitResources.localizedString("tuilivekit.pusher.summary.statistics")
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = context.startTime.map(formatter.string) ?? "--:--"
        let end = formatter.string(from: context.endTime)
        timeRangeLabel.text = "\(start) ~ \(end)"
        var data = LiveSummaryData()
        if let summary {
            data.totalGiftsSent = UInt(max(0, summary.totalGiftsSent))
            data.totalGiftCoins = UInt(max(0, summary.totalGiftCoins))
            data.totalViewers = UInt(max(0, summary.totalViewers))
            data.totalMessageSent = UInt(max(0, summary.totalMessageCount))
            data.totalGiftUniqueSenders = UInt(max(0, summary.totalUniqueGiftSenders))
            data.totalLikesReceived = UInt(max(0, summary.totalLikesReceived))
        }
        durationLabel.text = summary.map { Self.formatDuration(max(0, $0.liveDuration)) } ?? "--"

        pauseCapsule.isHidden = context.pausedSeconds == 0
        pauseDurationLabel.text = Self.formatDuration(context.pausedSeconds)

        let values = [
            Self.clamped(data.totalGiftsSent),
            Self.clamped(data.totalGiftCoins),
            Self.clamped(data.totalViewers),
            Self.clamped(data.totalMessageSent),
            Self.clamped(data.totalGiftUniqueSenders),
            Self.clamped(data.totalLikesReceived),
        ]
        zip(statCards, values).forEach { $0.bind(value: summary == nil ? nil : $1) }
    }

    private static func clamped(_ value: UInt) -> Int {
        Int(min(value, UInt(Int.max)))
    }

    private func configureUI() {
        backgroundColor = .clear
        addSubview(backgroundView)

        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        let contentView = UIView()
        scrollView.addSubview(contentView)

        let headerView = makeHeaderView()
        let heroCard = makeHeroCard()
        let sectionTitle = makeSummaryLabel("session_data", size: 15, weight: .semibold, alpha: 0.9, alignment: .left)
        let statGrid = makeStatGrid()

        [headerView, heroCard, sectionTitle, statGrid].forEach(contentView.addSubview)

        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        headerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(34)
            make.height.equalTo(58)
        }
        heroCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(headerView.snp.bottom).offset(10)
            make.height.equalTo(250)
        }
        sectionTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(19)
            make.top.equalTo(heroCard.snp.bottom).offset(20)
            make.size.equalTo(CGSize(width: 170, height: 21))
        }
        statGrid.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sectionTitle.snp.bottom).offset(6)
            make.height.equalTo(284)
            make.bottom.equalToSuperview().inset(20)
        }
    }

    private func makeStatGrid() -> UIStackView {
        let rows = stride(from: 0, to: statCards.count, by: 2).map { index -> UIStackView in
            let row = UIStackView(arrangedSubviews: Array(statCards[index ... index + 1]))
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

    private func makeHeaderView() -> UIView {
        let container = UIView()
        let backButton = UIButton(type: .custom)
        backButton.setImage(LiveKitResources.image(named: "livekit_summary_back"), for: .normal)
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.addTarget(self, action: #selector(exitSummary), for: .touchUpInside)
        container.addSubview(backButton)

        let title = interruptionLabel
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = UIColor.white.withAlphaComponent(0.9)
        title.textAlignment = .center
        title.numberOfLines = 2
        container.addSubview(title)

        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(14)
            make.size.equalTo(38)
        }
        title.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(80)
            make.centerY.equalTo(backButton)
            make.height.lessThanOrEqualTo(42)
        }
        return container
    }

    private func makeHeroCard() -> UIView {
        let card = SummaryGradientCardView(style: .hero)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.22
        card.layer.shadowOffset = CGSize(width: 0, height: 18)
        card.layer.shadowRadius = 42

        let outerRing = UIView()
        outerRing.backgroundColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.08)
        outerRing.layer.cornerRadius = 30
        card.addSubview(outerRing)

        let mark = UIView()
        mark.backgroundColor = PusherSummaryStyle.markBackground
        mark.layer.cornerRadius = 24
        mark.layer.borderWidth = 1
        mark.layer.borderColor = LiveTheme.Color.brandBlue.cgColor
        mark.layer.shadowColor = LiveTheme.Color.brandBlue.cgColor
        mark.layer.shadowOpacity = 0.22
        mark.layer.shadowOffset = CGSize(width: 0, height: 8)
        mark.layer.shadowRadius = 22
        card.addSubview(mark)

        let check = UIImageView(image: LiveKitResources.image(named: "livekit_summary_done"))
        check.contentMode = .scaleAspectFit
        mark.addSubview(check)

        let endedLabel = makeSummaryLabel("ended", size: 19, weight: .bold, alpha: 0.95)
        card.addSubview(endedLabel)
        card.addSubview(timeRangeLabel)

        let durationTitle = makeSummaryLabel("duration", size: 10, weight: .semibold, alpha: 0.48)
        card.addSubview(durationTitle)

        durationLabel.textColor = PusherSummaryStyle.durationForeground
        durationLabel.font = PusherSummaryViewTypography.durationFont
        durationLabel.textAlignment = .center
        durationLabel.layer.shadowColor = LiveTheme.Color.brandBlue.cgColor
        durationLabel.layer.shadowOpacity = 0.34
        durationLabel.layer.shadowRadius = 20
        card.addSubview(durationLabel)

        pauseCapsule.backgroundColor = PusherSummaryStyle.pauseBackground
        pauseCapsule.layer.cornerRadius = 13.5
        pauseCapsule.layer.borderWidth = 1
        pauseCapsule.layer.borderColor = PusherSummaryStyle.pauseBorder.cgColor
        card.addSubview(pauseCapsule)

        let pauseTitle = makeSummaryLabel("paused_duration", size: 10, alpha: 0.48, alignment: .left)
        pauseCapsule.addSubview(pauseTitle)
        pauseCapsule.addSubview(pauseDurationLabel)

        constrainCentered(outerRing, top: 13, size: CGSize(width: 60, height: 60))
        constrainCentered(mark, top: 19, size: CGSize(width: 48, height: 48))
        check.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(1)
            make.size.equalTo(CGSize(width: 22, height: 18))
        }
        constrainHeroLabel(endedLabel, top: 80, height: 27)
        constrainHeroLabel(timeRangeLabel, top: 111, height: 16)
        constrainHeroLabel(durationTitle, top: 146, height: 14)
        constrainHeroLabel(durationLabel, top: 165, height: 40)
        let pauseTitleWidth = max(54, ceil(pauseTitle.intrinsicContentSize.width))
        constrainCentered(pauseCapsule, top: 211, size: CGSize(width: pauseTitleWidth + 84, height: 27))
        pauseTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(11)
            make.top.equalToSuperview().offset(7)
            make.size.equalTo(CGSize(width: pauseTitleWidth, height: 14))
        }
        pauseDurationLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(11)
            make.top.equalToSuperview().offset(7)
            make.size.equalTo(CGSize(width: 55, height: 14))
        }
        return card
    }

    private func constrainCentered(_ view: UIView, top: CGFloat, size: CGSize) {
        view.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(top)
            make.size.equalTo(size)
        }
    }

    private func constrainHeroLabel(_ label: UIView, top: CGFloat, height: CGFloat) {
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(40)
            make.top.equalToSuperview().offset(top)
            make.height.equalTo(height)
        }
    }

    private func makeSummaryLabel(
        _ key: String,
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        alpha: CGFloat,
        alignment: NSTextAlignment = .center
    ) -> UILabel {
        let label = UILabel()
        label.text = LiveKitResources.localizedString("tuilivekit.pusher.summary.\(key)")
        label.textColor = UIColor.white.withAlphaComponent(alpha)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textAlignment = alignment
        return label
    }

    private static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }

    private func hostingController() -> UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    private func enableInteractiveReturn() {
        guard popGesture == nil,
              let controller = hostingController(),
              let navigation = controller.navigationController,
              navigation.topViewController === controller,
              navigation.viewControllers.count > 1,
              let gesture = navigation.interactivePopGestureRecognizer else { return }
        previousPopDelegate = gesture.delegate
        previousPopEnabled = gesture.isEnabled
        popGesture = gesture
        // Keep UIKit's target/action so dragging drives the native interactive transition.
        gesture.delegate = self
        gesture.isEnabled = true
        scrollView.panGestureRecognizer.require(toFail: gesture)
    }

    private func restoreInteractiveReturn() {
        if let gesture = popGesture, gesture.delegate === self {
            gesture.delegate = previousPopDelegate
            gesture.isEnabled = previousPopEnabled
        }
        popGesture = nil
        previousPopDelegate = nil
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === popGesture else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        guard context != nil, !isHidden, !didRequestExit,
              let controller = hostingController(),
              let navigation = controller.navigationController else { return false }
        return navigation.topViewController === controller &&
            navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
    }

    @objc private func exitSummary() {
        guard context != nil, window != nil, !isHidden, !didRequestExit else { return }
        didRequestExit = true
        onExit?()
    }
}

private final class SummaryStatCardView: SummaryGradientCardView {
    private let valueLabel = UILabel()

    init(title: String, unit: String, accentColor: UIColor) {
        super.init(style: .stat(accentColor))

        let accent = UIView()
        accent.backgroundColor = accentColor
        accent.layer.cornerRadius = 2
        accent.layer.shadowColor = accentColor.cgColor
        accent.layer.shadowOpacity = 0.58
        accent.layer.shadowRadius = 9
        addSubview(accent)

        let titleLabel = LiveText(.metadata, tone: .tertiary, emphasized: true)
        titleLabel.text = title
        addSubview(titleLabel)

        valueLabel.textColor = PusherSummaryStyle.valueForeground
        valueLabel.font = SummaryStatCardViewTypography.valueFont
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5

        let unitLabel = LiveText(.metadata, tone: .disabled)
        unitLabel.text = unit
        unitLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueStack = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        valueStack.axis = .horizontal
        valueStack.alignment = .lastBaseline
        valueStack.spacing = 5
        addSubview(valueStack)

        accent.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(13)
            make.top.equalToSuperview().offset(13)
            make.size.equalTo(CGSize(width: 16, height: 4))
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(13)
            make.top.equalToSuperview().offset(26)
            make.height.equalTo(14)
        }
        valueStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(13)
            make.trailing.lessThanOrEqualToSuperview().inset(13)
            make.top.equalToSuperview().offset(45)
            make.height.equalTo(31)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(value: Int?) {
        valueLabel.text = value.map { String(max(0, $0)) } ?? "--"
    }
}

private class SummaryGradientCardView: UIView {
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
                UIColor.white.withAlphaComponent(0.065).cgColor,
                UIColor.white.withAlphaComponent(0.025).cgColor,
            ]
            baseGradient.startPoint = CGPoint(x: 0.5, y: 0)
            baseGradient.endPoint = CGPoint(x: 0.5, y: 1)
            accentGradient.colors = [
                LiveTheme.Color.brandBlue.withAlphaComponent(0.13).cgColor,
                LiveTheme.Color.brandBlue.withAlphaComponent(0.035).cgColor,
                LiveTheme.Color.brandBlue.withAlphaComponent(0).cgColor,
            ]
            accentGradient.locations = [0, 0.38, 0.75]
            accentGradient.startPoint = CGPoint(x: 0.5, y: 0)
            accentGradient.endPoint = CGPoint(x: 0.5, y: 1)
            layer.borderColor = UIColor.white.withAlphaComponent(0.085).cgColor
        case .stat(let color):
            radius = 16
            baseGradient.colors = [
                UIColor.white.withAlphaComponent(0.055).cgColor,
                UIColor.white.withAlphaComponent(0.022).cgColor,
            ]
            baseGradient.startPoint = CGPoint(x: 0, y: 0.5)
            baseGradient.endPoint = CGPoint(x: 1, y: 0.5)
            accentGradient.colors = [
                color.withAlphaComponent(0).cgColor,
                color.withAlphaComponent(0).cgColor,
                color.withAlphaComponent(0.085).cgColor,
            ]
            accentGradient.locations = [0, 0.28, 1]
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseGradient.frame = bounds
        accentGradient.frame = bounds
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherSummaryStyle {
    static let giftsAccent: UIColor = UIColor(red: 0.941, green: 0.737, blue: 0.373, alpha: 1)
    static let giftValueAccent: UIColor = UIColor(red: 1, green: 0.431, blue: 0.616, alpha: 1)
    static let viewersAccent: UIColor = UIColor(red: 0.412, green: 0.659, blue: 1, alpha: 1)
    static let commentsAccent: UIColor = UIColor(red: 0.745, green: 0.514, blue: 1, alpha: 1)
    static let sendersAccent: UIColor = UIColor(red: 0.341, green: 0.835, blue: 0.749, alpha: 1)
    static let likesAccent: UIColor = UIColor(red: 1, green: 0.482, blue: 0.447, alpha: 1)
    static let markBackground: UIColor = UIColor(red: 0.098, green: 0.243, blue: 0.42, alpha: 1)
    static let durationForeground: UIColor = UIColor(red: 0.557, green: 0.812, blue: 1, alpha: 1)
    static let pauseBackground: UIColor = UIColor.white.withAlphaComponent(0.045)
    static let pauseBorder: UIColor = UIColor.white.withAlphaComponent(0.07)
    static let valueForeground: UIColor = UIColor.white.withAlphaComponent(0.94)
}

private enum PusherSummaryViewTypography {
    static let durationFont: UIFont = UIFont.systemFont(ofSize: 30, weight: .bold)
}

private enum SummaryStatCardViewTypography {
    static let valueFont: UIFont = UIFont.systemFont(ofSize: 23, weight: .bold)
}
