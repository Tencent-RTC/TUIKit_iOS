import AtomicXCore
import Combine
import SnapKit
import UIKit

final class VoiceLoungeStatusPanel: BottomSheetView {
    private enum Layout { static let designHeight: CGFloat = 460 }

    private let liveID: String
    private let clock: VoiceLoungeLiveClock
    private let summaryStore: LiveSummaryStore
    private let likeStore: LikeStore
    private var cancellables = Set<AnyCancellable>()
    private var durationTimer: Timer?
    private var summaryData = LiveSummaryData()
    private var onlineCount = 0
    private var likeCount = 0

    private let titleLabel = LiveText.voiceLounge(.pageTitle, text: .title)
    private let durationDot = UIView()
    private let durationLabel = UILabel()
    private let statisticsView = PusherLiveStatisticsView()

    override var sheetHeight: CGFloat {
        guard bounds.height > 0 else { return Layout.designHeight }
        return min(Layout.designHeight, bounds.height - safeAreaInsets.top)
    }

    init(liveID: String, clock: VoiceLoungeLiveClock) {
        self.liveID = liveID
        self.clock = clock
        summaryStore = LiveSummaryStore.create(liveID: liveID)
        likeStore = LikeStore.create(liveID: liveID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) override init(frame: CGRect) {
        fatalError("init(frame:) is unavailable; use init(liveID:clock:)")
    }

    func show() {
        present()
        startObserving()
    }

    private func setupViews() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(durationDot)
        contentView.addSubview(durationLabel)
        contentView.addSubview(statisticsView)
    }

    private func setupConstraints() {
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
        statisticsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.bottom.lessThanOrEqualToSuperview()
        }
    }

    private func setupStyles() {
        durationDot.backgroundColor = LiveTheme.Color.brandBlue
        durationDot.layer.cornerRadius = 3
        durationLabel.textColor = UIColor(white: 0.9, alpha: 1)
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        durationLabel.textAlignment = .center
        durationLabel.text = "00:00:00"
    }

    private func setupBindings() {}

    override func sheetWillDismiss() { stopObserving() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopObserving() }
    }

    private func startObserving() {
        refreshDuration()
        guard cancellables.isEmpty else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshDuration() }
        }
        RunLoop.main.add(timer, forMode: .common)
        durationTimer = timer

        summaryStore.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            self?.summaryData = state.summaryData
            self?.refreshStatistics()
        }.store(in: &cancellables)
        AtomicPusher.shared.state.subscribe().map { max(0, $0.totalViewerCount) }.removeDuplicates().receive(
            on: DispatchQueue.main
        ).sink { [weak self] count in
            self?.onlineCount = count
            self?.refreshStatistics()
        }.store(in: &cancellables)
        likeStore.state.subscribe().map { Int($0.totalLikeCount) }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.likeCount = count
                self?.refreshStatistics()
            }.store(in: &cancellables)
    }

    private func stopObserving() {
        cancellables.removeAll()
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func refreshDuration() { durationLabel.text = Self.formatDuration(clock.elapsedSeconds) }

    private func refreshStatistics() {
        guard !isHidden else { return }
        statisticsView.bind(summaryData, onlineCount: onlineCount, likeCount: likeCount)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
}

private extension String {
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.status.title") }
}
