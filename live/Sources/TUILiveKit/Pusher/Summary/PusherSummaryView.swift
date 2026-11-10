import UIKit
import AtomicXCore
import SnapKit

struct PusherSummaryContext {
    let startTime: Date?
    let endTime: Date
    let pausedSeconds: Int
    let interruptionMessage: String?
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
    private let timeLabel = PusherSummaryStyle.label(size: 14, color: PusherSummaryStyle.secondaryText)
    private let pauseLabel = PusherSummaryStyle.label(size: 14, color: PusherSummaryStyle.secondaryText)
    private let interruptionLabel = PusherSummaryStyle.label(size: 14, color: PusherSummaryStyle.secondaryText)
    private let income = SummaryMetricView("gift_value", unit: "coins", style: .income)
    private let gifts = SummaryMetricView("gifts_received", unit: "items", style: .gift)
    private let senders = SummaryMetricView("gift_senders", unit: "people", style: .gift)
    private let viewers = SummaryMetricView("viewers", style: .interaction)
    private let comments = SummaryMetricView("comments", style: .interaction)
    private let likes = SummaryMetricView("likes", style: .interaction)

    init() {
        super.init(frame: .zero)
        configureUI()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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

    deinit { restoreInteractiveReturn() }

    // MARK: - Presentation

    private func render() {
        guard let context else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = context.startTime.map(formatter.string) ?? "--:--"
        let end = formatter.string(from: context.endTime)
        let duration = summary.map { Self.durationText($0.liveDuration) } ?? "--"
        let total = LiveKitResources.localizedFormat("tuilivekit.pusher.summary.total_duration", duration)
        setInformationText("\(start) – \(end)  ·  \(total)", on: timeLabel)
        let pause =
            context.pausedSeconds > 0
            ? LiveKitResources.localizedFormat(
                "tuilivekit.pusher.summary.pause_details", Self.durationText(context.pausedSeconds)) : nil
        setInformationText(pause, on: pauseLabel)
        setInformationText(context.interruptionMessage, on: interruptionLabel)

        income.bind(value: summary?.totalGiftCoins)
        gifts.bind(value: summary?.totalGiftsSent)
        senders.bind(value: summary?.totalUniqueGiftSenders)
        viewers.bind(value: summary?.totalViewers)
        comments.bind(value: summary?.totalMessageCount)
        likes.bind(value: summary?.totalLikesReceived)
    }

    private static func durationText(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        var parts: [String] = []
        for (amount, unit) in [(seconds / 3600, "hours"), (seconds / 60 % 60, "minutes"), (seconds % 60, "seconds")] {
            if amount > 0 || (unit == "seconds" && parts.isEmpty) {
                parts.append(LiveKitResources.localizedFormat("tuilivekit.pusher.summary.duration.\(unit)", amount))
            }
        }
        return parts.joined()
    }

    private func setInformationText(_ text: String?, on label: UILabel) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22
        paragraph.maximumLineHeight = 22
        label.attributedText = text.map {
            NSAttributedString(
                string: $0,
                attributes: [
                    .font: label.font as Any, .foregroundColor: label.textColor as Any, .paragraphStyle: paragraph,
                ])
        }
        label.isHidden = text?.isEmpty != false
    }

    // MARK: - Layout

    private func configureUI() {
        backgroundColor = PusherSummaryStyle.background
        let header = makeHeaderView()
        addSubview(header)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)
        let content = UIStackView(arrangedSubviews: [makeInformationView(), makeIncomeCard(), makeInteractionCard()])
        content.axis = .vertical
        content.spacing = 24
        scrollView.addSubview(content)

        header.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(20)
            make.top.equalTo(safeAreaLayoutGuide).offset(8)
            make.height.equalTo(44)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalTo(safeAreaLayoutGuide)
        }
        content.snp.makeConstraints { make in
            make.top.equalTo(scrollView.contentLayoutGuide)
            make.leading.trailing.equalTo(scrollView.contentLayoutGuide).inset(20)
            make.bottom.equalTo(scrollView.contentLayoutGuide).inset(24)
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-40)
        }
    }

    private func makeHeaderView() -> UIView {
        let header = UIView()
        let backButton = UIButton(type: .custom)
        backButton.setImage(LiveKitResources.image(named: "livekit_summary_back"), for: .normal)
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.pusher.summary.back")
        backButton.addTarget(self, action: #selector(exitSummary), for: .touchUpInside)
        let title = PusherSummaryStyle.label(size: 24, weight: .semibold, color: PusherSummaryStyle.primaryText)
        title.text = LiveKitResources.localizedString("tuilivekit.pusher.summary.ended")
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.75
        header.addSubview(backButton)
        header.addSubview(title)
        backButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(44)
        }
        title.snp.makeConstraints { make in
            make.leading.equalTo(backButton.snp.trailing)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        return header
    }

    private func makeInformationView() -> UIView {
        [timeLabel, pauseLabel, interruptionLabel].forEach { $0.numberOfLines = 0 }
        let information = UIStackView(arrangedSubviews: [timeLabel, pauseLabel, interruptionLabel])
        information.axis = .vertical
        information.spacing = 4
        information.isLayoutMarginsRelativeArrangement = true
        information.insetsLayoutMarginsFromSafeArea = false
        information.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 0)
        return information
    }

    private func makeIncomeCard() -> UIView {
        let card = SummaryIncomeCardView()
        let divider = UIView()
        divider.backgroundColor = PusherSummaryStyle.divider
        let giftRow = UIStackView(arrangedSubviews: [gifts, senders])
        giftRow.distribution = .fillEqually
        giftRow.spacing = 16
        let content = UIStackView(arrangedSubviews: [income, divider, giftRow])
        content.axis = .vertical
        content.distribution = .equalSpacing
        card.addSubview(content)
        card.snp.makeConstraints { $0.height.equalTo(280) }
        content.snp.makeConstraints { $0.edges.equalToSuperview().inset(24) }
        divider.snp.makeConstraints { $0.height.equalTo(1) }
        return card
    }

    private func makeInteractionCard() -> UIView {
        let card = UIView()
        card.backgroundColor = PusherSummaryStyle.interactionBackground
        card.layer.cornerRadius = 20
        let title = PusherSummaryStyle.label(size: 15, weight: .semibold, color: PusherSummaryStyle.primaryText)
        title.text = LiveKitResources.localizedString("tuilivekit.pusher.summary.interaction_data")
        let row = UIStackView(arrangedSubviews: [viewers, comments, likes])
        row.distribution = .fillEqually
        row.spacing = 10
        let content = UIStackView(arrangedSubviews: [title, row])
        content.axis = .vertical
        content.spacing = 20
        card.addSubview(content)
        content.snp.makeConstraints { $0.edges.equalToSuperview().inset(24) }
        title.snp.makeConstraints { $0.height.equalTo(22) }
        return card
    }

    // MARK: - Interactive Return

    private func hostingController() -> UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    private func enableInteractiveReturn() {
        guard popGesture == nil, let controller = hostingController(), let navigation = controller.navigationController,
            navigation.topViewController === controller, navigation.viewControllers.count > 1,
            let gesture = navigation.interactivePopGestureRecognizer
        else { return }
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
        guard context != nil, !isHidden, !didRequestExit, let controller = hostingController(),
            let navigation = controller.navigationController
        else { return false }
        return navigation.topViewController === controller && navigation.viewControllers.count > 1
            && navigation.transitionCoordinator == nil
    }

    @objc private func exitSummary() {
        guard context != nil, window != nil, !isHidden, !didRequestExit else { return }
        didRequestExit = true
        onExit?()
    }
}

private final class SummaryMetricView: UIStackView {
    enum Style {
        case income
        case gift
        case interaction

        var appearance: (valueSize: CGFloat, valueHeight: CGFloat) {
            switch self {
            case .income: return (48, 62)
            case .gift: return (32, 40)
            case .interaction: return (26, 38)
            }
        }
    }

    private let valueLabel = UILabel()
    private var displayOptions: [(text: String, minimumWidth: CGFloat)] = []
    private static let numberFormatter = makeFormatter(style: .decimal, fractionDigits: 0)
    private static let scientificFormatter = makeFormatter(style: .scientific, fractionDigits: 2)

    init(_ key: String, unit: String? = nil, style: Style) {
        super.init(frame: .zero)
        var title = LiveKitResources.localizedString("tuilivekit.pusher.summary.\(key)")
        if let unit {
            title = LiveKitResources.localizedFormat(
                "tuilivekit.pusher.summary.metric_with_unit", title,
                LiveKitResources.localizedString("tuilivekit.pusher.summary.unit.\(unit)"))
        }
        let isIncome = style == .income
        let appearance = style.appearance
        let titleLabel = PusherSummaryStyle.label(size: isIncome ? 14 : 13, color: PusherSummaryStyle.secondaryText)
        titleLabel.text = title
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        valueLabel.font = .monospacedDigitSystemFont(ofSize: appearance.valueSize, weight: .semibold)
        valueLabel.textColor = isIncome ? PusherSummaryStyle.incomeValue : PusherSummaryStyle.primaryText
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5
        axis = .vertical
        spacing = isIncome ? 12 : 8
        (isIncome ? [titleLabel, valueLabel] : [valueLabel, titleLabel]).forEach(addArrangedSubview)
        titleLabel.snp.makeConstraints { $0.height.equalTo(isIncome ? 20 : 24) }
        valueLabel.snp.makeConstraints { $0.height.equalTo(appearance.valueHeight) }
        isAccessibilityElement = true
        accessibilityLabel = title
        bind(value: nil)
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(value: Int?) {
        let value = value.map { max(0, $0) }
        let fullText = value.map { Self.numberFormatter.string(from: NSNumber(value: $0)) ?? String($0) } ?? "--"
        var texts = [fullText]
        if let value {
            if #available(iOS 15.0, *) {
                texts.append(
                    Double(value).formatted(
                        .number.notation(.compactName).precision(.significantDigits(3)).locale(Locale.current)))
            }
            if let scientific = Self.scientificFormatter.string(from: NSNumber(value: value)) {
                texts.append(scientific)
            }
        }
        displayOptions = texts.map {
            let width = ($0 as NSString).size(withAttributes: [.font: valueLabel.font as Any]).width
            return ($0, width * valueLabel.minimumScaleFactor)
        }
        accessibilityValue = fullText
        updateValueText()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateValueText()
    }

    private func updateValueText() {
        let option =
            bounds.width > 0
            ? displayOptions.first(where: { $0.minimumWidth <= bounds.width }) ?? displayOptions.last
            : displayOptions.first
        if let text = option?.text, valueLabel.text != text { valueLabel.text = text }
    }

    private static func makeFormatter(style: NumberFormatter.Style, fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }
}

private final class SummaryIncomeCardView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    init() {
        super.init(frame: .zero)
        layer.cornerRadius = 20
        clipsToBounds = true
        let gradient = layer as! CAGradientLayer
        gradient.colors = [
            UIColor(red: 0.15, green: 0.21, blue: 0.30, alpha: 1).cgColor,
            UIColor(red: 0.10, green: 0.15, blue: 0.23, alpha: 1).cgColor,
        ]
        gradient.startPoint = .zero
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private enum PusherSummaryStyle {
    static let primaryText = UIColor(red: 0xF5 / 255, green: 0xF7 / 255, blue: 0xFA / 255, alpha: 1)
    static let secondaryText = UIColor(red: 0xA9 / 255, green: 0xB7 / 255, blue: 0xCB / 255, alpha: 1)
    static let background = UIColor(red: 0x12 / 255, green: 0x16 / 255, blue: 0x1F / 255, alpha: 1)
    static let interactionBackground = UIColor(red: 0x1A / 255, green: 0x22 / 255, blue: 0x30 / 255, alpha: 1)
    static let incomeValue = UIColor(red: 0xF9 / 255, green: 0xD4 / 255, blue: 0x97 / 255, alpha: 1)
    static let divider = UIColor(red: 0x35 / 255, green: 0x42 / 255, blue: 0x55 / 255, alpha: 1)

    static func label(size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }
}
