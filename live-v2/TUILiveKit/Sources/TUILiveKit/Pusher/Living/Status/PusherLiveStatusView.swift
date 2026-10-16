import UIKit
import AtomicXCore
import Combine
import SnapKit

final class PusherLiveStatusView: BottomSheetView {
    var onSetCaptureVolume: ((Int) -> Void)?

    private enum ContentCategory {
        case realtimeStatistics
        case deviceStatus
    }

    private enum Layout {
        static let designHeight: CGFloat = 656
    }

    private let summaryStore: LiveSummaryStore
    private var summarySubscription: AnyCancellable?
    private var summaryData = LiveSummaryData()
    private var elapsedSeconds = 0
    private var onlineCount = 0
    private var likeCount = 0
    private var devicePresentation: PusherDeviceStatusView.Presentation?
    private var renderedDevicePresentation: PusherDeviceStatusView.Presentation?
    private let titleLabel = LiveText(.pageTitle, text: LiveKitResources.localizedString("tuilivekit.pusher.status.title"))
    private let durationDot = UIView()
    private let durationLabel = UILabel()
    private let categorySelectorView = StatusCategorySelectorView()
    private let contentScrollView = UIScrollView()
    private let scrollContentView = UIView()
    private var scrollContentHeightConstraint: Constraint?
    private let realtimeStatisticsView = PusherLiveStatisticsView()
    private let deviceStatusView = PusherDeviceStatusView()

    /// Caps the panel at the design height while keeping the top safe area clear
    /// on shorter devices.
    override var sheetHeight: CGFloat {
        guard bounds.height > 0 else { return Layout.designHeight }
        return min(Layout.designHeight, bounds.height - safeAreaInsets.top)
    }

    init(liveID: String) {
        summaryStore = LiveSummaryStore.create(liveID: liveID)
        super.init(frame: .zero)
        configureUI()
    }

    @available(*, unavailable)
    override init(frame: CGRect) {
        fatalError("init(frame:) is unavailable; use init(liveID:)")
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSheetHeight(animated: false)
    }

    func updateElapsedSeconds(_ seconds: Int) {
        guard elapsedSeconds != seconds else { return }
        elapsedSeconds = seconds
        if !isHidden {
            durationLabel.text = Self.formatDuration(seconds)
        }
    }

    func updateOnlineCount(_ count: Int) {
        guard onlineCount != count else { return }
        onlineCount = count
        refreshStatistics()
    }

    func updateLikeCount(_ count: Int) {
        guard likeCount != count else { return }
        likeCount = count
        refreshStatistics()
    }

    func updateDeviceStatus(
        _ status: PusherDeviceStatusState,
        videoQuality: PusherVideoQualitySetting,
        isMuted: Bool,
        captureVolume: Int
    ) {
        devicePresentation = PusherDeviceStatusView.Presentation(
            videoQuality: videoQuality,
            isMuted: isMuted,
            captureVolume: captureVolume,
            status: status
        )
        renderDeviceStatusIfNeeded()
    }

    func show() {
        showCategory(.realtimeStatistics)
        present()
        durationLabel.text = Self.formatDuration(elapsedSeconds)
        renderDeviceStatusIfNeeded()
        startObservingStatistics()
    }

    override func sheetWillDismiss() {
        stopObservingStatistics()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopObservingStatistics()
        }
    }

    private func configureUI() {
        contentView.addSubview(titleLabel)

        durationDot.backgroundColor = LiveTheme.Color.brandBlue
        durationDot.layer.cornerRadius = 3
        contentView.addSubview(durationDot)

        durationLabel.textColor = LiveStatusStyle.durationForeground
        durationLabel.font = PusherLiveStatusViewTypography.durationFont
        durationLabel.textAlignment = .center
        contentView.addSubview(durationLabel)

        categorySelectorView.onSelectStatistics = { [weak self] in
            self?.showCategory(.realtimeStatistics)
        }
        categorySelectorView.onSelectDeviceStatus = { [weak self] in
            self?.showCategory(.deviceStatus)
        }
        deviceStatusView.onContentHeightChanged = { [weak self] height in
            self?.scrollContentHeightConstraint?.update(offset: max(515, height))
        }
        deviceStatusView.onSetCaptureVolume = { [weak self] in self?.onSetCaptureVolume?($0) }
        contentView.addSubview(categorySelectorView)

        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.alwaysBounceVertical = false
        // Device content already reserves the bottom safe area.
        contentScrollView.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(contentScrollView)
        contentScrollView.addSubview(scrollContentView)
        [realtimeStatisticsView, deviceStatusView].forEach(scrollContentView.addSubview)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(26)
            make.top.equalToSuperview().offset(40)
            make.height.equalTo(28)
        }
        durationLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(41)
            make.size.equalTo(CGSize(width: 79, height: 24))
        }
        durationDot.snp.makeConstraints { make in
            make.leading.equalTo(durationLabel.snp.leading).offset(-3)
            make.centerY.equalTo(durationLabel)
            make.size.equalTo(6)
        }
        categorySelectorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(18)
            make.top.equalToSuperview().offset(81)
            make.height.equalTo(46)
        }
        contentScrollView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(141)
        }
        scrollContentView.snp.makeConstraints { make in
            make.edges.equalTo(contentScrollView.contentLayoutGuide)
            make.width.equalTo(contentScrollView.frameLayoutGuide)
            scrollContentHeightConstraint = make.height.equalTo(515).constraint
        }
        [realtimeStatisticsView, deviceStatusView].forEach {
            $0.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        showCategory(.realtimeStatistics)
    }

    private func showCategory(_ category: ContentCategory) {
        categorySelectorView.setStatisticsSelected(category == .realtimeStatistics)
        realtimeStatisticsView.isHidden = category != .realtimeStatistics
        deviceStatusView.isHidden = category != .deviceStatus
    }

    private func startObservingStatistics() {
        summaryData = summaryStore.state.value.summaryData
        refreshStatistics()
        guard summarySubscription == nil else { return }
        summarySubscription = summaryStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.summaryData = state.summaryData
                self?.refreshStatistics()
            }
    }

    private func stopObservingStatistics() {
        summarySubscription?.cancel()
        summarySubscription = nil
    }

    func refreshStatistics() {
        guard !isHidden else { return }
        let data = summaryData
        realtimeStatisticsView.bind(
            data,
            onlineCount: onlineCount,
            likeCount: likeCount
        )
    }

    private func renderDeviceStatusIfNeeded() {
        guard !isHidden, let devicePresentation,
              renderedDevicePresentation != devicePresentation else { return }
        renderedDevicePresentation = devicePresentation
        deviceStatusView.bind(devicePresentation)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
}

private final class StatusCategorySelectorView: UIView {
    var onSelectStatistics: (() -> Void)?
    var onSelectDeviceStatus: (() -> Void)?

    private let selectionView = UIView()
    private let statisticsButton = UIButton(type: .custom)
    private let deviceStatusButton = UIButton(type: .custom)
    private var isStatisticsSelected = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = LiveStatusStyle.tabsBackground
        layer.cornerRadius = 14

        selectionView.backgroundColor = LiveStatusStyle.selectedTabBackground
        selectionView.layer.cornerRadius = 11
        selectionView.layer.borderWidth = 1
        selectionView.layer.borderColor = LiveStatusStyle.selectedTabBorder.cgColor
        addSubview(selectionView)

        configure(statisticsButton, title: LiveKitResources.localizedString("tuilivekit.pusher.status.realtime"), action: #selector(selectStatistics))
        configure(deviceStatusButton, title: LiveKitResources.localizedString("tuilivekit.pusher.status.device"), action: #selector(selectDeviceStatus))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let itemWidth = (bounds.width - 12) / 2
        selectionView.frame = CGRect(x: isStatisticsSelected ? 4 : itemWidth + 8, y: 4, width: itemWidth, height: 38)
        statisticsButton.frame = CGRect(x: 4, y: 4, width: itemWidth, height: 38)
        deviceStatusButton.frame = CGRect(x: itemWidth + 8, y: 4, width: itemWidth, height: 38)
    }

    func setStatisticsSelected(_ selected: Bool) {
        isStatisticsSelected = selected
        statisticsButton.setTitleColor(UIColor.white.withAlphaComponent(selected ? 1 : 0.5), for: .normal)
        deviceStatusButton.setTitleColor(UIColor.white.withAlphaComponent(selected ? 0.5 : 1), for: .normal)
        setNeedsLayout()
    }

    private func configure(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = StatusCategorySelectorViewTypography.buttonFont
        button.addTarget(self, action: action, for: .touchUpInside)
        addSubview(button)
    }

    @objc private func selectStatistics() { onSelectStatistics?() }
    @objc private func selectDeviceStatus() { onSelectDeviceStatus?() }
}

private enum LiveStatusStyle {
    static let durationForeground: UIColor = UIColor(white: 0.9, alpha: 1)
    static let tabsBackground: UIColor = UIColor.white.withAlphaComponent(0.06)
    static let selectedTabBackground: UIColor = UIColor(red: 0.413, green: 0.686, blue: 1, alpha: 0.303)
    static let selectedTabBorder: UIColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.35)
}

// Shared only by the two content pages in this status sheet.
enum PusherLiveStatusContentStyle {
    static let separator: UIColor = UIColor.white.withAlphaComponent(0.065)
    private static let cardBackground: UIColor = UIColor.white.withAlphaComponent(0.02)
    private static let cardBorder: UIColor = UIColor.white.withAlphaComponent(0.07)

    static func applyCardStyle(_ view: UIView, radius: CGFloat) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = radius
        view.layer.borderWidth = 1
        view.layer.borderColor = cardBorder.cgColor
    }
}

private enum PusherLiveStatusViewTypography {
    static let durationFont: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
}

private enum StatusCategorySelectorViewTypography {
    static let buttonFont: UIFont = UIFont.systemFont(ofSize: 14)
}
