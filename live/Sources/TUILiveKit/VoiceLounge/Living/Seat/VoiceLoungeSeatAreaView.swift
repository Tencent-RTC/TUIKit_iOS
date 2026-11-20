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
    private let ecgLineView = VoiceLoungeECGLineView()
    private let hostHalo = VoiceLoungeHaloEmitterView()
    private let cohostHalo = VoiceLoungeHaloEmitterView()
    private let contentBottomMarker = UIView()

    private static let columnAvatar: CGFloat = 40
    private static let columnWidth: CGFloat = 64
    private static let columnFocusTop: CGFloat = 100
    private static let duoTop: CGFloat = 36
    private static let duoAvatar: CGFloat = 72
    private static let duoLineGap: CGFloat = 10

    private let topRow = UIView()
    private let gridContainer = UIView()
    private let columnScrollView = UIScrollView()
    private let columnContentView = UIView()
    private var columnHeightConstraint: Constraint?
    private var columnMaxHeight: CGFloat = .greatestFiniteMagnitude

    init(
        store: VoiceLoungeSeatStore, transcriberStore: VoiceLoungeAITranscriberStore,
        livingActions: VoiceLoungeLivingActions
    ) {
        self.store = store
        self.tapHandler = VoiceLoungeSeatTapHandler(store: store)
        self.livingActions = livingActions
        self.transcriberStore = transcriberStore
        self.transcriberView = VoiceLoungeAITranscriberView(store: transcriberStore)
        self.lastTranscriberVisible = transcriberStore.isVisible
        super.init(frame: .zero)
        transcriberView.onTap = { [weak livingActions] in livingActions?.showTranscriberPanel() }
        setupViews()
        setupStyles()
        setupBindings()
        render()
    }

    private let transcriberStore: VoiceLoungeAITranscriberStore
    private var lastTranscriberVisible: Bool

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(topRow)
        addSubview(welcomeBar)
        welcomeBar.addSubview(welcomeLabel)
        addSubview(gridContainer)
        addSubview(columnScrollView)
        columnScrollView.addSubview(columnContentView)
        addSubview(ecgLineView)
        addSubview(contentBottomMarker)
    }

    private func setupStyles() {
        ecgLineView.isHidden = true
        hostHalo.isHidden = true
        cohostHalo.isHidden = true
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
        tapHandler.onConfirm = { [weak self] title, message, confirmTitle, action in
            self?.livingActions.confirm(title, message, confirmTitle, action)
        }
        welcomeBar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapWelcome)))
        store.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        transcriberStore.changes.sink { [weak self] in self?.handleTranscriberVisibilityChange() }.store(
            in: &cancellables)
    }

    private func handleTranscriberVisibilityChange() {
        let nowVisible = transcriberStore.isVisible
        guard nowVisible != lastTranscriberVisible else { return }
        lastTranscriberVisible = nowVisible
        if layout == .oneV8 { rebuild() } else { render() }
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
        if topic.isEmpty {
            welcomeLabel.text = .welcome
        } else {
            welcomeLabel.text =
                topic == VoiceLoungeConfig.defaultTopic ? topic : String(format: .welcomeTopicFormat, topic)
        }
    }

    private func render() {
        let layout = store.layout
        let needsRebuild = self.layout != layout || seatItems.isEmpty
        self.layout = layout
        self.seats = store.seats
        renderWelcome()

        if needsRebuild { rebuild() } else { updateSeatContents() }
        ecgLineView.setActive(layout == .duo)
        updateHaloActivities()
    }

    private func haloActivity(seatIndex: Int) -> VoiceLoungeHaloEmitterView.Activity {
        guard let seat = seats.first(where: { $0.index == seatIndex }), seat.state == .occupied else { return .none }
        return seat.isSpeaking ? .speaking : .none
    }

    private func hasHalo(seatIndex: Int) -> Bool {
        guard layout == .duo else { return false }
        return seatIndex == 0 || seatIndex == 1
    }

    private func updateHaloActivities() {
        hostHalo.setActivity(hasHalo(seatIndex: 0) ? haloActivity(seatIndex: 0) : .none)
        cohostHalo.setActivity(hasHalo(seatIndex: 1) ? haloActivity(seatIndex: 1) : .none)
    }

    private func attachHalo(_ halo: VoiceLoungeHaloEmitterView, around seat: VoiceLoungeSeatView, avatarRadius: CGFloat)
    {
        halo.removeFromSuperview()
        guard let parent = seat.superview else { return }
        parent.insertSubview(halo, belowSubview: seat)
        halo.setAvatarRadius(avatarRadius)
        halo.snp.remakeConstraints { make in
            make.center.equalTo(seat.avatarAnchor)
            make.size.equalTo((avatarRadius + VoiceLoungeHaloEmitterView.maxSpread) * 2)
        }
        halo.isHidden = false
    }

    private func detachHalo(_ halo: VoiceLoungeHaloEmitterView) {
        halo.setActivity(.none)
        halo.isHidden = true
        halo.removeFromSuperview()
    }

    private func rebuild() {
        seatItems.values.forEach { $0.removeFromSuperview() }
        seatItems.removeAll()
        detachHalo(hostHalo)
        detachHalo(cohostHalo)
        topRow.subviews.forEach { $0.removeFromSuperview() }
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        columnContentView.subviews.forEach { $0.removeFromSuperview() }
        transcriberView.removeFromSuperview()
        ecgLineView.isHidden = true
        columnScrollView.isHidden = layout != .oneV8x
        columnScrollView.contentOffset = .zero
        if layout != .oneV8x { columnScrollView.snp.removeConstraints() }

        for seat in seats {
            let size: CGFloat = seatAvatarSize(for: seat.role, layout: layout)
            let isColumn = layout == .oneV8x && seat.role == .guest
            let item = VoiceLoungeSeatView(
                avatarSize: size, emptyTitle: emptyTitle(for: seat.role),
                nameGap: isColumn ? 0 : VoiceLoungeSeatView.defaultNameGap, isCompact: isColumn,
                showsWave: !hasHalo(seatIndex: seat.index))
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

        attachHalos()
        updateSeatContents()
    }

    private func attachHalos() {
        for seat in seats where hasHalo(seatIndex: seat.index) {
            guard let item = seatItems[seat.index] else { continue }
            let radius = seatAvatarSize(for: seat.role, layout: layout) / 2
            attachHalo(seat.index == 0 ? hostHalo : cohostHalo, around: item, avatarRadius: radius)
        }
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
        transcriberView.fitsContent = false
        topRow.addSubview(focus)
        let transcriberVisible = transcriberStore.isVisible
        if transcriberVisible {
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
        } else {
            focus.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(focusWidth)
            }
        }

        layoutTopRow(height: VoiceLoungeAITranscriberView.height)
        layoutGrid24(guestStartIndex: 1)
    }

    private func layoutOneV8x() {
        guard let focus = seatItems[0] else { return }
        welcomeBar.isHidden = true
        transcriberView.fitsContent = true

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
            make.height.greaterThanOrEqualTo(topRow)
            columnHeightConstraint = make.height.equalTo(columnFullHeight).priority(.high).constraint
        }
        applyColumnLimit()
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

    private var columnFullHeight: CGFloat { VoiceLoungeSeatView.height(avatarSize: Self.columnAvatar, nameGap: 0) * 8 }

    func updateColumnLimit(maxHeight: CGFloat) {
        guard abs(maxHeight - columnMaxHeight) > 0.5 else { return }
        columnMaxHeight = maxHeight
        applyColumnLimit()
    }

    private func applyColumnLimit() {
        guard layout == .oneV8x else { return }
        let full = columnFullHeight
        let height = min(full, max(columnMaxHeight, 0))
        columnHeightConstraint?.update(offset: height)
        columnScrollView.isScrollEnabled = height + 0.5 < full
        columnScrollView.alwaysBounceVertical = false
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) { return true }
        return !columnScrollView.isHidden && columnScrollView.frame.contains(point)
    }

    private func layoutTwoV8() {
        guard let host = seatItems[0], let cohost = seatItems[1] else { return }
        transcriberView.fitsContent = false
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
        transcriberView.fitsContent = false
        welcomeBar.isHidden = true
        topRow.addSubview(ecgLineView)
        topRow.addSubview(host)
        topRow.addSubview(mate)
        topRow.addSubview(transcriberView)
        ecgLineView.isHidden = false

        let avatar = Self.duoAvatar
        let itemWidth: CGFloat = 96
        let halfGap: CGFloat = 62
        let avatarOffset = halfGap + itemWidth / 2
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
        ecgLineView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(topRow)
            make.centerY.equalTo(host.snp.top).offset((avatar + 8) / 2)
            make.height.equalTo(VoiceLoungeECGLineView.height)
        }
        ecgLineView.setGeometry(avatarOffset: avatarOffset, avatarRadius: avatar / 2, lineGap: Self.duoLineGap)
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

private final class VoiceLoungeECGLineView: UIView {
    static let height: CGFloat = 160

    private static let speed: CGFloat = 120
    private static let trailRatio: CGFloat = 0.3
    private static let trailPieces = 24
    private static let amplitude: CGFloat = 24
    private static let lightStops: [(CGFloat, CGFloat, CGFloat)] = [(1.0, 0.525, 0.827), (0.663, 0.545, 1.0)]
    private static let coreLift: CGFloat = 0.5
    private static let glowLayers: [(width: CGFloat, alphaScale: CGFloat)] = [(6.0, 0.10), (4.2, 0.20), (2.8, 0.45)]
    private static let trailWidth: CGFloat = 2
    private static let coreWidth: CGFloat = 0.9
    private static let baseLineRGB: (CGFloat, CGFloat, CGFloat) = (0.80, 0.63, 0.95)

    private static let vertices: [(CGFloat, CGFloat)] = [
        (0, 0), (0.15, 0), (0.18, -0.15), (0.22, 0), (0.30, 0), (0.315, 0.14), (0.389, -1), (0.438, 0.72), (0.475, 0),
        (0.61, 0), (0.655, -0.19), (0.70, 0), (0.855, -0.22), (0.89, 0), (1, 0),
    ]

    private var avatarOffset: CGFloat = 110
    private var avatarRadius: CGFloat = 36
    private var lineGap: CGFloat = 10
    private var pathPoints: [CGPoint] = []
    private var pathLengths: [CGFloat] = []
    private var displayLink: CADisplayLink?
    private let startTime = CACurrentMediaTime()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    deinit { displayLink?.invalidate() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !isHidden { ensureAnimating() } else { stopDisplayLink() }
    }

    func setGeometry(avatarOffset: CGFloat, avatarRadius: CGFloat, lineGap: CGFloat) {
        self.avatarOffset = avatarOffset
        self.avatarRadius = avatarRadius
        self.lineGap = lineGap
        rebuildPath()
        setNeedsDisplay()
    }

    func setActive(_ active: Bool) { if active { ensureAnimating() } else { stopDisplayLink() } }

    func ensureAnimating() {
        guard window != nil, !isHidden else { return }
        if displayLink == nil {
            let link = CADisplayLink(target: ECGProxy(self), selector: #selector(ECGProxy.tick(_:)))
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
        guard !isHidden, let total = pathLengths.last, total > 0 else { return }
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildPath()
        ensureAnimating()
    }

    private func rebuildPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let cx = bounds.width / 2, cy = bounds.height / 2
        let xA = cx - avatarOffset + avatarRadius + lineGap, xB = cx + avatarOffset - avatarRadius - lineGap
        let points = Self.vertices.map { CGPoint(x: xA + (xB - xA) * $0.0, y: cy + $0.1 * Self.amplitude) }
        var lengths: [CGFloat] = [0]
        for i in 1..<points.count { lengths.append(lengths[i - 1] + Self.distance(points[i - 1], points[i])) }
        pathPoints = points
        pathLengths = lengths
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    private func segmentIndex(at s: CGFloat) -> Int {
        var low = 0, high = pathLengths.count - 2
        while low < high {
            let mid = (low + high + 1) / 2
            if pathLengths[mid] <= s { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private func point(at s: CGFloat) -> CGPoint {
        let i = segmentIndex(at: s)
        let span = pathLengths[i + 1] - pathLengths[i]
        let f = span > 0 ? (s - pathLengths[i]) / span : 0
        let a = pathPoints[i], b = pathPoints[i + 1]
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    private func addSubpath(_ ctx: CGContext, from s0: CGFloat, to s1: CGFloat) {
        ctx.move(to: point(at: s0))
        var i = segmentIndex(at: s0) + 1
        while i < pathLengths.count, pathLengths[i] < s1 {
            ctx.addLine(to: pathPoints[i])
            i += 1
        }
        ctx.addLine(to: point(at: s1))
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), pathPoints.count > 2, let total = pathLengths.last, total > 0
        else { return }

        let base = Self.baseLineRGB
        ctx.setLineWidth(1.7)
        ctx.setStrokeColor(CGColor(red: base.0, green: base.1, blue: base.2, alpha: 0.5))
        ctx.setLineJoin(.miter)
        ctx.beginPath()
        for (i, point) in pathPoints.enumerated() { if i == 0 { ctx.move(to: point) } else { ctx.addLine(to: point) } }
        ctx.strokePath()

        let t = CGFloat(CACurrentMediaTime() - startTime)
        let head = (t * Self.speed).truncatingRemainder(dividingBy: total)
        let piece = total * Self.trailRatio / CGFloat(Self.trailPieces)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for k in 0..<Self.trailPieces {
            var s0 = head - piece * CGFloat(Self.trailPieces - k)
            if s0 < 0 { s0 += total }
            let s1 = s0 + piece
            let alpha = min(1, CGFloat(k + 1) / (CGFloat(Self.trailPieces) * 0.4))
            let rgb = Self.gradientRGB(at: (s0 + piece / 2).truncatingRemainder(dividingBy: total) / total)
            let trail = CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            let core = CGColor(
                red: rgb.0 + (1 - rgb.0) * Self.coreLift, green: rgb.1 + (1 - rgb.1) * Self.coreLift,
                blue: rgb.2 + (1 - rgb.2) * Self.coreLift, alpha: 1)
            var strokes: [(CGFloat, CGColor, CGFloat)] = Self.glowLayers.map { ($0.width, trail, $0.alphaScale) }
            strokes.append((Self.trailWidth, trail, 1.0))
            strokes.append((Self.coreWidth, core, 1.0))
            for (width, color, scale) in strokes {
                ctx.setLineWidth(width)
                ctx.setStrokeColor(color.copy(alpha: alpha * scale) ?? color)
                ctx.beginPath()
                if s1 <= total {
                    addSubpath(ctx, from: s0, to: s1)
                } else {
                    addSubpath(ctx, from: s0, to: total)
                    addSubpath(ctx, from: 0, to: s1 - total)
                }
                ctx.strokePath()
            }
        }
    }

    private static func gradientRGB(at f: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let stops = lightStops
        let x = min(max(f, 0), 1) * CGFloat(stops.count - 1)
        let i = min(Int(x), stops.count - 2)
        let m = x - CGFloat(i)
        let a = stops[i], b = stops[i + 1]
        return (a.0 + (b.0 - a.0) * m, a.1 + (b.1 - a.1) * m, a.2 + (b.2 - a.2) * m)
    }
}

private final class ECGProxy: NSObject {
    private weak var target: VoiceLoungeECGLineView?

    init(_ target: VoiceLoungeECGLineView) { self.target = target }

    @objc func tick(_ link: CADisplayLink) {
        guard let target else {
            link.invalidate()
            return
        }
        target.tick()
    }
}

private final class VoiceLoungeHaloEmitterView: UIView {
    enum Activity { case none, speaking }

    static let maxSpread: CGFloat = 26

    private struct EmitStyle {
        let rate: CGFloat
        let size: ClosedRange<CGFloat>
        let alpha: ClosedRange<CGFloat>
        let speed: ClosedRange<CGFloat>
        let life: ClosedRange<CGFloat>
        let spread: CGFloat
    }

    private static let speakingStyle = EmitStyle(
        rate: 28, size: 2.4...3.8, alpha: 0.85...1, speed: 14...22, life: 1.1...1.6, spread: maxSpread)
    private static let emitInset: ClosedRange<CGFloat> = 3...6
    private static let particlePink: (CGFloat, CGFloat, CGFloat) = (1, 0.525, 0.827)
    private static let particlePurple: (CGFloat, CGFloat, CGFloat) = (0.663, 0.545, 1)

    private struct Particle {
        var angle: CGFloat
        let startRadius: CGFloat
        var radius: CGFloat
        let spread: CGFloat
        let speed: CGFloat
        let drift: CGFloat
        var age: CGFloat
        let life: CGFloat
        let size: CGFloat
        let color: CGColor
    }

    private var avatarRadius: CGFloat = 36
    private var activity: Activity = .none
    private var emitCarry: CGFloat = 0
    private var particles: [Particle] = []
    private var lastTick: CFTimeInterval = 0
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    deinit { displayLink?.invalidate() }

    func setAvatarRadius(_ r: CGFloat) {
        guard abs(r - avatarRadius) > 0.5 else { return }
        avatarRadius = r
    }

    func setActivity(_ a: Activity) {
        guard activity != a else { return }
        activity = a
        if a == .none { emitCarry = 0 }
        ensureAnimating()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !isHidden { ensureAnimating() } else { stopDisplayLink() }
    }

    private func ensureAnimating() {
        guard window != nil, !isHidden, activity != .none || !particles.isEmpty else {
            stopDisplayLink()
            return
        }
        if displayLink == nil {
            let link = CADisplayLink(target: HaloProxy(self), selector: #selector(HaloProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTick = 0
        }
        displayLink?.isPaused = false
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func tick() {
        guard !isHidden else { return }
        let now = CACurrentMediaTime()
        let dt = lastTick > 0 ? CGFloat(min(now - lastTick, 0.05)) : 0
        lastTick = now
        update(dt: dt)
        setNeedsDisplay()
        if activity == .none, particles.isEmpty { stopDisplayLink() }
    }

    private func update(dt: CGFloat) {
        guard dt > 0 else { return }
        particles = particles.compactMap { particle in
            var p = particle
            p.age += dt
            guard p.age < p.life else { return nil }
            p.radius += p.speed * dt
            p.angle += p.drift * dt
            guard p.radius - p.startRadius < p.spread else { return nil }
            return p
        }
        guard activity == .speaking, !UIAccessibility.isReduceMotionEnabled else { return }
        emitCarry += dt * Self.speakingStyle.rate
        while emitCarry >= 1 {
            emitCarry -= 1
            particles.append(makeParticle(style: Self.speakingStyle))
        }
    }

    private func makeParticle(style: EmitStyle) -> Particle {
        let mix = CGFloat.random(in: 0...1)
        let pink = Self.particlePink, purple = Self.particlePurple
        let color = CGColor(
            red: pink.0 + (purple.0 - pink.0) * mix, green: pink.1 + (purple.1 - pink.1) * mix,
            blue: pink.2 + (purple.2 - pink.2) * mix, alpha: .random(in: style.alpha))
        let start = avatarRadius + .random(in: Self.emitInset)
        return Particle(
            angle: .random(in: 0..<(2 * .pi)), startRadius: start, radius: start, spread: style.spread,
            speed: .random(in: style.speed), drift: .random(in: -0.175...0.175), age: 0, life: .random(in: style.life),
            size: .random(in: style.size), color: color)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let cx = bounds.width / 2, cy = bounds.height / 2
        for p in particles {
            let k = max(p.age / p.life, (p.radius - p.startRadius) / p.spread)
            let fade = k < 0.18 ? k / 0.18 : 1 - (k - 0.18) / 0.82
            let x = cx + cos(p.angle) * p.radius
            let y = cy + sin(p.angle) * p.radius
            ctx.setFillColor(p.color.copy(alpha: p.color.alpha * max(0, fade)) ?? p.color)
            ctx.fillEllipse(in: CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size))
        }
    }
}

private final class HaloProxy: NSObject {
    private weak var target: VoiceLoungeHaloEmitterView?

    init(_ target: VoiceLoungeHaloEmitterView) { self.target = target }

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
