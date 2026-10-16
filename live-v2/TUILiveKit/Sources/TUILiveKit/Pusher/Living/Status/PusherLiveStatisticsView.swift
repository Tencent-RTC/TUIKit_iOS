import UIKit
import AtomicXCore

final class PusherLiveStatisticsView: UIView {
    private let statisticsCard = UIView()
    private let cardTitle = LiveText(.prominent, text: LiveKitResources.localizedString("tuilivekit.pusher.status.realtime"))
    private let cumulativeLabel = LiveText(.control, text: LiveKitResources.localizedString("tuilivekit.pusher.status.cumulative"), tone: .disabled, alignment: .right)
    private let separator = UIView()
    private let updateStatusCard = UIView()
    private let updateIcon = UIImageView()
    private let updateTitle = LiveText(.action, text: LiveKitResources.localizedString("tuilivekit.pusher.status.updating"), tone: .secondary)
    private let updateDetail = LiveText(.control, text: LiveKitResources.localizedString("tuilivekit.pusher.status.update_detail"), tone: .disabled)
    private var valueViews: [StatisticValueView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        statisticsCard.frame = CGRect(x: 18, y: 0, width: bounds.width - 36, height: 232)
        cardTitle.frame = CGRect(x: 16, y: 18, width: 110, height: 23)
        let cumulativeWidth = ceil(cumulativeLabel.intrinsicContentSize.width)
        cumulativeLabel.frame = CGRect(x: statisticsCard.bounds.width - cumulativeWidth - 16, y: 21, width: cumulativeWidth, height: 15)
        separator.frame = CGRect(x: 16, y: 125, width: statisticsCard.bounds.width - 32, height: 1 / UIScreen.main.scale)
        let columnWidth = (statisticsCard.bounds.width - 42) / 3
        for (index, view) in valueViews.enumerated() {
            let row = index / 3
            let column = index % 3
            view.frame = CGRect(x: 21 + CGFloat(column) * columnWidth, y: 55 + CGFloat(row) * 84, width: columnWidth, height: 68)
        }
        updateStatusCard.frame = CGRect(x: 18, y: 244, width: bounds.width - 36, height: 90)
        updateIcon.frame = CGRect(x: 15, y: 15, width: 34, height: 34)
        updateTitle.frame = CGRect(x: 61, y: 13, width: updateStatusCard.bounds.width - 76, height: 18)
        updateDetail.frame = CGRect(x: 61, y: 36, width: updateStatusCard.bounds.width - 76, height: 45)
    }

    func bind(_ data: LiveSummaryData, onlineCount: Int, likeCount: Int) {
        let values: [UInt] = [
            data.totalGiftCoins,
            data.totalGiftUniqueSenders,
            data.totalGiftsSent,
            UInt(max(0, onlineCount)),
            UInt(max(0, likeCount)),
            data.totalMessageSent,
        ]
        zip(valueViews, values).forEach { $0.0.setValue($0.1) }
    }

    private func configureUI() {
        PusherLiveStatusContentStyle.applyCardStyle(statisticsCard, radius: 18)
        addSubview(statisticsCard)

        statisticsCard.addSubview(cardTitle)

        statisticsCard.addSubview(cumulativeLabel)

        separator.backgroundColor = PusherLiveStatusContentStyle.separator
        statisticsCard.addSubview(separator)

        let statisticDescriptors = [
            ("tuilivekit.pusher.status.metric.gift_score", "tuilivekit.pusher.status.unit.points"),
            ("tuilivekit.pusher.status.metric.gift_senders", "tuilivekit.pusher.status.unit.people"),
            ("tuilivekit.pusher.status.metric.gifts", "tuilivekit.pusher.status.unit.count"),
            ("tuilivekit.pusher.status.metric.online", "tuilivekit.pusher.status.unit.people"),
            ("tuilivekit.pusher.status.metric.likes", "tuilivekit.pusher.status.unit.times"),
            ("tuilivekit.pusher.status.metric.messages", "tuilivekit.pusher.status.unit.messages"),
        ]
        .map { (LiveKitResources.localizedString($0.0), LiveKitResources.localizedString($0.1)) }
        valueViews = statisticDescriptors.map { StatisticValueView(title: $0.0, unit: $0.1) }
        valueViews.forEach(statisticsCard.addSubview)

        PusherLiveStatusContentStyle.applyCardStyle(updateStatusCard, radius: 15)
        addSubview(updateStatusCard)
        updateIcon.image = LiveKitResources.image(named: "livekit_status_realtime")
        updateStatusCard.addSubview(updateIcon)
        updateStatusCard.addSubview(updateTitle)
        updateDetail.numberOfLines = 0
        updateStatusCard.addSubview(updateDetail)
    }
}

private final class StatisticValueView: UIView {
    private let titleLabel: LiveText
    private let valueLabel = UILabel()
    private let unitLabel: LiveText

    init(title: String, unit: String) {
        titleLabel = LiveText(.caption, text: title, tone: .tertiary)
        unitLabel = LiveText(.metadata, text: unit, tone: .disabled)
        super.init(frame: .zero)
        titleLabel.numberOfLines = 2
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5
        addSubview(titleLabel)
        valueLabel.textColor = StatisticsStyle.statValue
        valueLabel.font = StatisticValueViewTypography.valueFont
        addSubview(valueLabel)
        addSubview(unitLabel)
        setValue(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = CGRect(x: 0, y: 0, width: bounds.width - 4, height: 32)
        let unitWidth = ceil(unitLabel.intrinsicContentSize.width)
        let valueWidth = min(ceil(valueLabel.intrinsicContentSize.width), max(0, bounds.width - unitWidth - 9))
        valueLabel.frame = CGRect(x: 0, y: 35, width: valueWidth, height: 28)
        unitLabel.frame = CGRect(x: valueWidth + 5, y: 47, width: unitWidth, height: 13)
    }

    func setValue(_ value: UInt) {
        valueLabel.text = String(value)
        setNeedsLayout()
    }
}

private enum StatisticsStyle {
    static let statValue: UIColor = UIColor.white.withAlphaComponent(0.96)
}

private enum StatisticValueViewTypography {
    static let valueFont: UIFont = UIFont.systemFont(ofSize: 24, weight: .semibold)
}
