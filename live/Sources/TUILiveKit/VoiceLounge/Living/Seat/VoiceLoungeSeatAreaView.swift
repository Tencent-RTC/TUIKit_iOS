import Combine
import SnapKit
import UIKit

final class VoiceLoungeSeatAreaView: UIView {
    var onSendGift: ((_ userID: String, _ name: String) -> Void)?

    var barrageTopAnchor: ConstraintItem { contentBottomMarker.snp.bottom }

    private let store: VoiceLoungeSeatStore
    private let tapHandler: VoiceLoungeSeatTapHandler
    private let livingActions: VoiceLoungeLivingActions
    private lazy var topicPanel: VoiceLoungeTopicPanel = {
        let panel = VoiceLoungeTopicPanel()
        panel.onConfirm = { [weak self] topic in self?.livingActions.changeTopic(topic) }
        return panel
    }()
    private var cancellables = Set<AnyCancellable>()
    private var layout: VoiceLoungeSeatLayout = .oneV8
    private var seats: [VoiceLoungeSeat] = []
    private var seatItems: [Int: VoiceLoungeSeatView] = [:]

    private let welcomeBar = UIView()
    private let welcomeLabel = LiveText.voiceLounge(.caption, tone: .secondary)
    private let transcriberView: VoiceLoungeAITranscriberView
    private let heartbeatView = HeartbeatView()
    private let contentBottomMarker = UIView()

    private static let columnAvatar: CGFloat = 40
    private static let columnWidth: CGFloat = 56
    private static let columnFocusTop: CGFloat = 100
    private static let duoTop: CGFloat = 36
    private static let duoAvatar: CGFloat = 72

    private let topRow = UIView()
    private let gridContainer = UIView()
    private let columnScrollView = UIScrollView()
    private let columnContentView = UIView()

    init(
        store: VoiceLoungeSeatStore, transcriberStore: VoiceLoungeAITranscriberStore, livingActions: VoiceLoungeLivingActions
    ) {
        self.store = store
        self.tapHandler = VoiceLoungeSeatTapHandler(store: store)
        self.livingActions = livingActions
        self.transcriberView = VoiceLoungeAITranscriberView(store: transcriberStore)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        render()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(topRow)
        addSubview(welcomeBar)
        welcomeBar.addSubview(welcomeLabel)
        addSubview(gridContainer)
        addSubview(columnScrollView)
        columnScrollView.addSubview(columnContentView)
        addSubview(heartbeatView)
        addSubview(contentBottomMarker)
    }

    private func setupConstraints() {}

    private func setupStyles() {
        heartbeatView.isHidden = true
        columnScrollView.isHidden = true
        columnScrollView.showsVerticalScrollIndicator = false
        contentBottomMarker.isUserInteractionEnabled = false
        welcomeBar.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        welcomeBar.layer.cornerRadius = 14
        welcomeBar.isUserInteractionEnabled = store.role == .host
        welcomeLabel.numberOfLines = 2
        welcomeLabel.lineBreakMode = .byTruncatingTail
        welcomeLabel.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        tapHandler.onSendGift = { [weak self] userID, name in self?.onSendGift?(userID, name) }
        welcomeBar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapWelcome)))
        store.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else {
            panels.forEach { $0.removeFromSuperview() }
            return
        }
        panels.forEach { panel in
            guard panel.superview !== window else { return }
            panel.removeFromSuperview()
            window.addSubview(panel)
            panel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }

    private var panels: [BottomSheetView] { (store.role == .host ? [topicPanel] : []) + tapHandler.panels }
    
    private func renderWelcome() {
        let topic = store.settings.topic
        welcomeLabel.text = topic.isEmpty ? String.welcome : String(format: .welcomeTopicFormat, topic)
    }

    private func render() {
        let layout = store.layout
        let needsRebuild = self.layout != layout || seatItems.isEmpty
        self.layout = layout
        self.seats = store.seats
        renderWelcome()

        if needsRebuild { rebuild() } else { updateSeatContents() }
        if layout == .duo { heartbeatView.ensureAnimating() }
    }

    private func rebuild() {
        seatItems.values.forEach { $0.removeFromSuperview() }
        seatItems.removeAll()
        topRow.subviews.forEach { $0.removeFromSuperview() }
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        columnContentView.subviews.forEach { $0.removeFromSuperview() }
        transcriberView.removeFromSuperview()
        heartbeatView.isHidden = true
        columnScrollView.isHidden = layout != .oneV8x
        columnScrollView.contentOffset = .zero
        if layout != .oneV8x { columnScrollView.snp.removeConstraints() }

        for seat in seats {
            let size: CGFloat = seatAvatarSize(for: seat.role, layout: layout)
            let isColumn = layout == .oneV8x && seat.role == .guest
            let item = VoiceLoungeSeatView(
                avatarSize: size, emptyTitle: emptyTitle(for: seat.role),
                nameGap: isColumn ? 0 : VoiceLoungeSeatView.defaultNameGap)
            item.onTap = { [weak self] index in
                guard let self else { return }
                self.tapHandler.handleTap(index)
            }
            seatItems[seat.index] = item
        }

        switch layout {
        case .oneV8: layoutOneV8()
        case .oneV8x: layoutOneV8x()
        case .twoV8: layoutTwoV8()
        case .duo: layoutDuo()
        }

        updateSeatContents()
    }

    private func updateSeatContents() { for seat in seats { seatItems[seat.index]?.configure(seat: seat) } }

    private func seatAvatarSize(for role: VoiceLoungeSeat.Role, layout: VoiceLoungeSeatLayout) -> CGFloat {
        switch (role, layout) {
        case (.host, .duo), (.guest, .duo): return Self.duoAvatar
        case (.guest, .oneV8x): return Self.columnAvatar
        case (.host, _), (.cohost, _): return VoiceLoungeSeatStyle.focusAvatar
        default: return VoiceLoungeSeatStyle.guestAvatar
        }
    }

    private func emptyTitle(for role: VoiceLoungeSeat.Role) -> String {
        switch role {
        case .host: return .host
        case .cohost: return .cohost
        case .guest: return store.role == .host ? .invite : .join
        }
    }

    private var focusWidth: CGFloat { VoiceLoungeSeatStyle.focusAvatar + 16 }

    private func layoutOneV8() {
        guard let focus = seatItems[0] else { return }
        topRow.addSubview(focus)
        topRow.addSubview(transcriberView)

        focus.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(focusWidth)
        }
        transcriberView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(focus.snp.trailing).offset(14)
            make.trailing.equalToSuperview().inset(6)
        }

        layoutTopRow(height: VoiceLoungeAITranscriberView.height)
        layoutGrid24(guestStartIndex: 1)
    }

    private func layoutOneV8x() {
        guard let focus = seatItems[0] else { return }
        welcomeBar.isHidden = true

        let cell = VoiceLoungeSeatView.height(avatarSize: Self.columnAvatar, nameGap: 0)
        var prev: UIView?
        for i in 1...8 {
            guard let item = seatItems[i] else { continue }
            columnContentView.addSubview(item)
            item.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(cell)
                if let prev { make.top.equalTo(prev.snp.bottom) } else { make.top.equalToSuperview() }
            }
            prev = item
        }
        columnContentView.snp.remakeConstraints { make in
            make.edges.equalTo(columnScrollView.contentLayoutGuide)
            make.width.equalTo(columnScrollView.frameLayoutGuide)
            make.height.equalTo(cell * 8)
        }
        columnScrollView.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview().offset(4)
            make.width.equalTo(Self.columnWidth)
            make.bottom.equalTo(topRow)
        }
        gridContainer.snp.remakeConstraints { make in
            make.top.leading.equalToSuperview()
            make.size.equalTo(0)
        }

        topRow.addSubview(focus)
        topRow.addSubview(transcriberView)
        focus.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.columnFocusTop)
            make.centerX.equalTo(transcriberView)
            make.width.equalTo(VoiceLoungeSeatStyle.focusAvatar + 40)
        }
        transcriberView.snp.makeConstraints { make in
            make.top.equalTo(focus.snp.bottom).offset(14)
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(14)
            make.height.equalTo(VoiceLoungeAITranscriberView.height)
            make.bottom.equalToSuperview()
        }

        topRow.snp.remakeConstraints { make in
            make.top.leading.equalToSuperview()
            make.trailing.equalTo(columnScrollView.snp.leading)
            make.bottom.equalToSuperview()
        }
        contentBottomMarker.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(transcriberView.snp.bottom)
            make.height.equalTo(0)
        }
    }

    private func layoutTwoV8() {
        guard let host = seatItems[0], let cohost = seatItems[1] else { return }
        topRow.addSubview(host)
        topRow.addSubview(cohost)
        topRow.addSubview(transcriberView)

        host.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.centerY.equalToSuperview()
            make.width.equalTo(focusWidth)
        }
        cohost.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(6)
            make.centerY.equalToSuperview()
            make.width.equalTo(focusWidth)
        }
        transcriberView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(host.snp.trailing).offset(8)
            make.trailing.equalTo(cohost.snp.leading).offset(-8)
        }

        layoutTopRow(height: VoiceLoungeAITranscriberView.height)
        layoutGrid24(guestStartIndex: 2)
    }

    private func layoutDuo() {
        guard let host = seatItems[0], let mate = seatItems[1] else { return }
        welcomeBar.isHidden = true
        topRow.addSubview(host)
        topRow.addSubview(mate)
        topRow.addSubview(heartbeatView)
        topRow.addSubview(transcriberView)
        heartbeatView.isHidden = false

        let avatar = Self.duoAvatar
        let itemWidth: CGFloat = 96
        let halfGap: CGFloat = 40
        host.snp.makeConstraints { make in
            make.trailing.equalTo(topRow.snp.centerX).offset(-halfGap)
            make.top.equalToSuperview()
            make.width.equalTo(itemWidth)
        }
        mate.snp.makeConstraints { make in
            make.leading.equalTo(topRow.snp.centerX).offset(halfGap)
            make.top.equalToSuperview()
            make.width.equalTo(itemWidth)
        }
        heartbeatView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(halfGap * 2 + (itemWidth - avatar) - 16)
            make.centerY.equalTo(host.snp.top).offset((avatar + 8) / 2)
            make.height.equalTo(26)
        }
        transcriberView.snp.makeConstraints { make in
            make.top.equalTo(host.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(6)
            make.height.equalTo(VoiceLoungeAITranscriberView.height)
            make.bottom.equalToSuperview()
        }

        topRow.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(Self.duoTop)
            make.bottom.equalToSuperview()
        }
        contentBottomMarker.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(topRow.snp.bottom)
            make.height.equalTo(0)
        }
    }

    private func layoutGrid24(guestStartIndex: Int) {
        welcomeBar.isHidden = false
        let rowHeight = VoiceLoungeSeatView.height(avatarSize: VoiceLoungeSeatStyle.guestAvatar)
        let rowGap: CGFloat = 10

        for row in 0..<2 {
            for col in 0..<4 {
                let seatIndex = guestStartIndex + row * 4 + col
                guard let item = seatItems[seatIndex] else { continue }
                gridContainer.addSubview(item)
                item.snp.makeConstraints { make in
                    make.width.equalToSuperview().multipliedBy(1.0 / 4)
                    make.height.equalTo(rowHeight)
                    make.leading.equalToSuperview().offset(CGFloat(col) * (UIScreen.main.bounds.width - 32) / 4)
                    make.top.equalToSuperview().offset(CGFloat(row) * (rowHeight + rowGap))
                }
            }
        }

        gridContainer.snp.remakeConstraints { make in
            make.top.equalTo(welcomeBar.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(rowHeight * 2 + rowGap)
            make.bottom.equalToSuperview()
        }
        contentBottomMarker.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(gridContainer.snp.bottom)
            make.height.equalTo(0)
        }
    }

    private func layoutTopRow(height: CGFloat) {
        topRow.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(height)
        }
        welcomeBar.snp.remakeConstraints { make in
            make.top.equalTo(topRow.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(30)
        }
        welcomeLabel.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.bottom.equalToSuperview().inset(7)
        }
    }
}

extension VoiceLoungeSeatAreaView {
    @objc private func tapWelcome() {
        guard store.role == .host else { return }
        topicPanel.show(current: store.settings.topic, skin: store.skin)
    }
}

private final class HeartbeatView: UIView {
    private static let points: [CGPoint] = [
        .init(x: 0, y: 13), .init(x: 16, y: 13), .init(x: 22, y: 2), .init(x: 28, y: 21), .init(x: 30.5, y: 17),
        .init(x: 31.5, y: 18), .init(x: 34, y: 10.5), .init(x: 36, y: 12.5), .init(x: 38, y: 12.5),
        .init(x: 39.5, y: 17.5), .init(x: 44, y: 5), .init(x: 47.5, y: 13), .init(x: 64, y: 13),
    ]
    private static let period: CFTimeInterval = 1.8
    private static let segment: CGFloat = 0.2

    private let dimLayer = CAShapeLayer()
    private let sweepLayer = CAShapeLayer()
    private let accentColor = LiveTheme.Color.brandCyan
    private var displayLink: CADisplayLink?
    private let startTime = CACurrentMediaTime()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        dimLayer.fillColor = UIColor.clear.cgColor
        dimLayer.strokeColor = accentColor.withAlphaComponent(0.28).cgColor
        dimLayer.lineWidth = 1.6
        dimLayer.lineCap = .round
        dimLayer.lineJoin = .round
        layer.addSublayer(dimLayer)

        sweepLayer.fillColor = UIColor.clear.cgColor
        sweepLayer.strokeColor = accentColor.cgColor
        sweepLayer.lineWidth = 2.2
        sweepLayer.lineCap = .round
        sweepLayer.lineJoin = .round
        sweepLayer.strokeStart = 0
        sweepLayer.strokeEnd = 0
        sweepLayer.shadowColor = accentColor.cgColor
        sweepLayer.shadowRadius = 4
        sweepLayer.shadowOpacity = 0.9
        sweepLayer.shadowOffset = .zero
        layer.addSublayer(sweepLayer)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    deinit { displayLink?.invalidate() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { ensureAnimating() } else { stopDisplayLink() }
    }

    func ensureAnimating() {
        guard window != nil else { return }
        if displayLink == nil {
            let link = CADisplayLink(target: WeakProxy(self), selector: #selector(WeakProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        displayLink?.isPaused = false
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let progress = CGFloat(elapsed.truncatingRemainder(dividingBy: Self.period) / Self.period)
        let head = progress * (1 + Self.segment)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sweepLayer.strokeStart = max(0, head - Self.segment)
        sweepLayer.strokeEnd = min(1, head)
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scaleX = bounds.width / 64
        let scaleY = bounds.height / 26
        let path = UIBezierPath()
        for (i, p) in Self.points.enumerated() {
            let point = CGPoint(x: p.x * scaleX, y: p.y * scaleY)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.frame = bounds
        sweepLayer.frame = bounds
        dimLayer.path = path.cgPath
        sweepLayer.path = path.cgPath
        CATransaction.commit()
        ensureAnimating()
    }
}

private final class WeakProxy: NSObject {
    private weak var target: HeartbeatView?

    init(_ target: HeartbeatView) { self.target = target }

    @objc func tick(_ link: CADisplayLink) {
        guard let target else {
            link.invalidate()
            return
        }
        target.tick()
    }
}

private extension String {
    static var welcome: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.welcome") }
    static var welcomeTopicFormat: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.room.welcome_topic_format")
    }
    static var cohost: String { LiveKitResources.localizedString("tuilivekit.voiceroom.layout.cohost") }
    static var host: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.host") }
    static var invite: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.invite") }
    static var join: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.join") }
}
