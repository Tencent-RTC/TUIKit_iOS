import AtomicXCore
import Combine
import SnapKit
import UIKit

@MainActor final class VoiceLoungeMusicView: BottomSheetView {
    private let musicStore: MusicStore
    private let tracks = MusicTrack.all
    private let volumeLabel = UILabel()
    private let volumeSlider = UISlider()
    private let modeButton = MusicModeButton()
    private let prevButton = MusicControlButton(assetName: "livekit_voicebgm_prev")
    private let nextButton = MusicControlButton(assetName: "livekit_voicebgm_next")
    private let rowsStack = UIStackView()
    private var rows: [MusicTrackRow] = []

    private var currentIndex = 0
    private var volume = 100
    private var mode = MusicPlayMode.order
    private var history: [Int] = []
    private var playURL: String?
    private var playStatus: MusicPlayStatus = .idle
    private var cancellables = Set<AnyCancellable>()
    private var isActive = false
    private var isSuspended = false
    private var resumeURL: String?
    private var skin = VoiceLoungeSkin.defaultSkin

    override var sheetHeight: CGFloat {
        let rowsHeight = CGFloat(tracks.count) * (MusicStyle.rowHeight + MusicStyle.rowSpacing)
        return MusicStyle.listTop + rowsHeight + MusicStyle.bottomInset + safeAreaInsets.bottom
    }

    init(liveID: String) {
        musicStore = MusicStore.create(liveID: liveID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        render()
    }

    @available(*, unavailable) override init(frame: CGRect) {
        fatalError("init(frame:) is unavailable; use init(liveID:)")
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        updateState(musicStore.state.value)
        musicStore.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] musicState in
            self?.updateState(musicState)
        }.store(in: &cancellables)
        musicStore.musicEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in
            guard case .playCompleted(let url) = event else { return }
            self?.handlePlayCompleted(url)
        }.store(in: &cancellables)
    }

    func deactivate() {
        isSuspended = false
        resumeURL = nil
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        musicStore.stopPlay()
        playURL = nil
        playStatus = .idle
        currentIndex = 0
        history.removeAll()
        render()
    }

    func setSuspended(_ suspended: Bool) {
        guard isSuspended != suspended else { return }
        isSuspended = suspended
        guard isActive else { return }
        let current = musicStore.state.value
        if suspended {
            resumeURL = current.playStatus == .playing || current.playStatus == .loading ? current.playURL : nil
            if resumeURL != nil { musicStore.pausePlay() }
        } else {
            let shouldResume = resumeURL != nil && resumeURL == current.playURL && current.playStatus == .paused
            resumeURL = nil
            if shouldResume { musicStore.resumePlay() }
        }
    }

    func applySkin(_ skin: VoiceLoungeSkin) {
        guard self.skin != skin else { return }
        self.skin = skin
        modeButton.applySkin(skin)
        volumeSlider.minimumTrackTintColor = skin.mid
        volumeSlider.thumbTintColor = skin.mid
        rows.forEach { $0.applySkin(skin) }
    }

    func show() {
        render()
        present()
    }

    private var isPlaying: Bool {
        playURL == tracks[currentIndex].url && (playStatus == .playing || playStatus == .loading)
    }

    private func setupViews() {
        [volumeLabel, volumeSlider, modeButton, prevButton, nextButton, rowsStack].forEach(contentView.addSubview)
        rows = tracks.enumerated().map { index, track in
            let row = MusicTrackRow(index: index, track: track)
            row.onTap = { [weak self] in self?.toggleOrSelect(index) }
            rowsStack.addArrangedSubview(row)
            return row
        }
    }

    private func setupConstraints() {
        nextButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(MusicStyle.horizontalInset + 4)
            make.top.equalToSuperview().offset(MusicStyle.toolbarTop + 2)
            make.size.equalTo(MusicStyle.controlSize)
        }
        prevButton.snp.makeConstraints { make in
            make.trailing.equalTo(nextButton.snp.leading).offset(-6)
            make.centerY.size.equalTo(nextButton)
        }
        modeButton.snp.makeConstraints { make in
            make.trailing.equalTo(prevButton.snp.leading).offset(-6)
            make.centerY.equalTo(nextButton)
            make.height.equalTo(24)
        }
        volumeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(MusicStyle.horizontalInset + 4)
            make.centerY.equalTo(nextButton)
        }
        volumeSlider.snp.makeConstraints { make in
            make.leading.equalTo(volumeLabel.snp.trailing).offset(8)
            make.trailing.equalTo(modeButton.snp.leading).offset(-10)
            make.centerY.equalTo(nextButton)
        }
        rowsStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MusicStyle.horizontalInset)
            make.top.equalToSuperview().offset(MusicStyle.listTop)
        }
    }

    private func setupStyles() {
        sheetTitle = .title
        volumeLabel.text = .volume
        volumeLabel.font = .systemFont(ofSize: VoiceLoungeFont.size(11))
        volumeLabel.textColor = MusicStyle.ink2
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 100
        volumeSlider.value = Float(volume)
        volumeSlider.minimumTrackTintColor = skin.mid
        volumeSlider.thumbTintColor = skin.mid
        rowsStack.axis = .vertical
        rowsStack.spacing = MusicStyle.rowSpacing
        modeButton.applySkin(skin)
        rows.forEach { $0.applySkin(skin) }
        prevButton.accessibilityLabel = .previous
        nextButton.accessibilityLabel = .next
        volumeSlider.accessibilityLabel = .volume
    }

    private func setupBindings() {
        modeButton.addTarget(self, action: #selector(switchMode), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(playPrevious), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(playNext), for: .touchUpInside)
        volumeSlider.addTarget(self, action: #selector(handleVolumeChanged), for: .valueChanged)
    }

    private func render() {
        let playing = isPlaying
        rows.enumerated().forEach { index, row in
            row.bind(isCurrent: index == currentIndex, isPlaying: playing && index == currentIndex)
        }
        modeButton.bind(mode)
    }

    private func updateState(_ musicState: MusicState) {
        guard isActive else { return }
        let status: MusicPlayStatus
        switch musicState.playStatus {
        case .idle, .loading, .playing, .paused: status = musicState.playStatus
        @unknown default: status = .idle
        }
        guard playURL != musicState.playURL || playStatus != status else { return }
        playURL = musicState.playURL
        playStatus = status
        if let url = playURL, status != .idle, let index = tracks.firstIndex(where: { $0.url == url }) {
            currentIndex = index
        }
        render()
        if isSuspended, status == .playing { musicStore.pausePlay() }
    }

    private func toggleOrSelect(_ index: Int) { if index == currentIndex { togglePlay() } else { select(index) } }

    private func togglePlay() {
        guard isActive, !isSuspended else { return }
        let url = tracks[currentIndex].url
        guard playURL == url else {
            start(url)
            return
        }
        switch playStatus {
        case .playing, .loading: musicStore.pausePlay()
        case .paused: musicStore.resumePlay()
        case .idle: start(url)
        @unknown default: start(url)
        }
    }

    private func select(_ index: Int, remember: Bool = true) {
        guard isActive, !isSuspended, tracks.indices.contains(index) else { return }
        if remember, index != currentIndex { history.append(currentIndex) }
        currentIndex = index
        render()
        start(tracks[index].url)
    }

    private func start(_ url: String) {
        if playURL != nil, playStatus != .idle { musicStore.stopPlay() }
        musicStore.setPitch(0)
        musicStore.setMusicVolume(volume)
        musicStore.startPlay(url: url, completion: nil)
    }

    private func step(_ direction: Int) {
        guard !tracks.isEmpty else { return }
        if mode == .shuffle {
            if direction < 0, let previous = history.popLast() {
                select(previous, remember: false)
                return
            }
            let candidates = tracks.indices.filter { tracks.count == 1 || $0 != currentIndex }
            select(candidates.randomElement() ?? currentIndex)
            return
        }
        select((currentIndex + direction + tracks.count) % tracks.count)
    }

    private func handlePlayCompleted(_ url: String) {
        guard isActive, !isSuspended, url == tracks[currentIndex].url else { return }
        if mode == .single { start(url) } else { step(1) }
    }
}

extension VoiceLoungeMusicView {
    @objc private func switchMode() {
        mode = mode.next
        modeButton.bind(mode)
    }

    @objc private func playPrevious() { step(-1) }

    @objc private func playNext() { step(1) }

    @objc private func handleVolumeChanged() {
        volume = Int(volumeSlider.value.rounded())
        musicStore.setMusicVolume(volume)
    }
}

private struct MusicTrack {
    let title: String
    let artist: String
    let url: String
    let duration: String
    let coverName: String

    static var all: [MusicTrack] {
        var tracks = [
            MusicTrack(
                title: LiveKitResources.localizedString("tuilivekit.pusher.music.happy"), artist: "TUIKit",
                url: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/PositiveHappyAdvertising.mp3",
                duration: "5:45", coverName: "livekit_voicefx_r_loud"),
            MusicTrack(
                title: LiveKitResources.localizedString("tuilivekit.pusher.music.sad"), artist: "TUIKit",
                url: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/SadCinematicPiano.mp3", duration: "6:06",
                coverName: "livekit_voicefx_r_deep"),
            MusicTrack(
                title: LiveKitResources.localizedString("tuilivekit.pusher.music.wonder_world"), artist: "TUIKit",
                url: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/WonderWorld.mp3", duration: "2:05",
                coverName: "livekit_voicefx_r_ktv"),
        ]
        if let rainPath = LiveKitResources.bundle.url(forResource: "livekit_voicebgm_rain", withExtension: "mp3")?.path
        {
            tracks.append(
                MusicTrack(
                    title: LiveKitResources.localizedString("tuilivekit.pusher.music.rain"), artist: "TUIKit",
                    url: rainPath, duration: "5:15", coverName: "livekit_voicebgm_cover_rain"))
        }
        return tracks
    }
}

private enum MusicPlayMode: CaseIterable {
    case order
    case single
    case shuffle

    var next: MusicPlayMode {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }

    var title: String {
        switch self {
        case .order: return .modeOrder
        case .single: return .modeSingle
        case .shuffle: return .modeShuffle
        }
    }

    var assetName: String {
        switch self {
        case .order: return "livekit_voicebgm_order"
        case .single: return "livekit_voicebgm_single"
        case .shuffle: return "livekit_voicebgm_shuffle"
        }
    }
}

private final class MusicModeButton: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    private func setupViews() { [iconView, titleLabel].forEach(addSubview) }

    private func setupConstraints() {
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(12)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(4)
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
        }
    }

    private func setupStyles() {
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = MusicStyle.glassLine.cgColor
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        titleLabel.font = .systemFont(ofSize: VoiceLoungeFont.size(11))
        titleLabel.isUserInteractionEnabled = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ mode: MusicPlayMode) {
        iconView.image = LiveKitResources.image(named: mode.assetName)?.withRenderingMode(.alwaysTemplate)
        titleLabel.text = mode.title
        accessibilityLabel = .modeTip(mode.title)
    }

    func applySkin(_ skin: VoiceLoungeSkin) {
        backgroundColor = skin.mid.withAlphaComponent(0.12)
        titleLabel.textColor = skin.textSoft
        iconView.tintColor = skin.textSoft
    }
}

private final class MusicControlButton: UIControl {
    private let iconView = UIImageView()

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    init(assetName: String) {
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        iconView.image = LiveKitResources.image(named: assetName)?.withRenderingMode(.alwaysTemplate)
    }

    private func setupViews() { addSubview(iconView) }

    private func setupConstraints() {
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(13)
        }
    }

    private func setupStyles() {
        backgroundColor = MusicStyle.glassFill
        layer.cornerRadius = MusicStyle.controlSize / 2
        layer.borderWidth = 1
        layer.borderColor = MusicStyle.glassLine.cgColor
        iconView.tintColor = MusicStyle.ink2
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class MusicTrackRow: UIControl {
    var onTap: (() -> Void)?

    private let indexLabel = UILabel()
    private let equalizerView = MusicEqualizerView()
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let durationLabel = UILabel()
    private let playButton = UIControl()
    private let playGradient = CAGradientLayer()
    private let playIconView = UIImageView()
    private let title: String
    private var isCurrent = false
    private var isPlaying = false
    private var skin = VoiceLoungeSkin.defaultSkin

    init(index: Int, track: MusicTrack) {
        title = track.title
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        indexLabel.text = String(format: "%02d", index + 1)
        coverView.image = LiveKitResources.image(named: track.coverName)
        titleLabel.text = track.title
        durationLabel.text = track.duration
        applySkin(skin)
        bind(isCurrent: false, isPlaying: false)
    }

    private func setupViews() {
        playButton.layer.insertSublayer(playGradient, at: 0)
        playButton.addSubview(playIconView)
        [indexLabel, equalizerView, coverView, titleLabel, durationLabel, playButton].forEach { addSubview($0) }
    }

    private func setupStyles() {
        layer.cornerRadius = 12
        layer.borderWidth = 1
        let subviews: [UIView] = [indexLabel, equalizerView, coverView, titleLabel, durationLabel, playButton]
        subviews.forEach { $0.isUserInteractionEnabled = $0 === playButton }
        isAccessibilityElement = true
        accessibilityTraits = .button
        indexLabel.font = .monospacedDigitSystemFont(ofSize: VoiceLoungeFont.size(11), weight: .regular)
        indexLabel.textColor = MusicStyle.ink3
        indexLabel.textAlignment = .center

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 10
        coverView.layer.borderWidth = 1
        coverView.layer.borderColor = MusicStyle.glassLine.cgColor

        titleLabel.font = .systemFont(ofSize: VoiceLoungeFont.size(14), weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: VoiceLoungeFont.size(11), weight: .regular)
        durationLabel.textColor = MusicStyle.ink3
        durationLabel.textAlignment = .right

        playGradient.startPoint = CGPoint(x: 0, y: 0)
        playGradient.endPoint = CGPoint(x: 1, y: 1)
        playGradient.cornerRadius = MusicStyle.playSize / 2
        playButton.layer.shadowOpacity = 1
        playButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        playButton.layer.shadowRadius = 6
        playIconView.tintColor = .white
        playIconView.contentMode = .scaleAspectFit
        playIconView.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        addTarget(self, action: #selector(tap), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(isCurrent: Bool, isPlaying: Bool) {
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        indexLabel.isHidden = isCurrent
        equalizerView.isHidden = !isCurrent
        equalizerView.setPlaying(isPlaying)
        durationLabel.isHidden = isCurrent
        playButton.isHidden = !isCurrent
        let iconName = isPlaying ? "livekit_voicebgm_pause" : "livekit_voicebgm_play"
        playIconView.image = LiveKitResources.image(named: iconName)?.withRenderingMode(.alwaysTemplate)
        accessibilityLabel = (isPlaying ? String.pause : String.play) + " " + title
        updateColors()
    }

    func applySkin(_ skin: VoiceLoungeSkin) {
        self.skin = skin
        playGradient.colors = [skin.mid.cgColor, skin.deep.cgColor]
        playButton.layer.shadowColor = skin.mid.withAlphaComponent(0.4).cgColor
        equalizerView.tint = skin.mid
        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playGradient.frame = playButton.bounds
    }

    private func updateColors() {
        backgroundColor = isCurrent ? skin.mid.withAlphaComponent(0.12) : .clear
        layer.borderColor = (isCurrent ? skin.mid.withAlphaComponent(0.32) : .clear).cgColor
        titleLabel.textColor = isCurrent ? skin.textSoft : .white
    }

    private func setupConstraints() {
        snp.makeConstraints { make in make.height.equalTo(MusicStyle.rowHeight) }
        indexLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.centerY.equalToSuperview()
            make.width.equalTo(22)
        }
        equalizerView.snp.makeConstraints { make in
            make.center.equalTo(indexLabel)
            make.width.equalTo(14)
            make.height.equalTo(16)
        }
        coverView.snp.makeConstraints { make in
            make.leading.equalTo(indexLabel.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(durationLabel.snp.leading).offset(-8)
        }
        durationLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(4)
            make.centerY.equalToSuperview()
            make.width.equalTo(44)
        }
        playButton.snp.makeConstraints { make in
            make.center.equalTo(durationLabel)
            make.size.equalTo(MusicStyle.playSize)
        }
        playIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(16)
        }
    }

    @objc private func tap() { onTap?() }
}

private final class MusicEqualizerView: UIView {
    private static let maxHeight: CGFloat = 15
    private static let restHeights: [CGFloat] = [6, 11, 8]
    private let bars = (0..<3).map { _ in CALayer() }
    private var isPlaying = false

    var tint: UIColor = VoiceLoungeSkin.defaultSkin.mid {
        didSet {
            bars.forEach { bar in
                bar.backgroundColor = tint.cgColor
                bar.shadowColor = tint.withAlphaComponent(0.4).cgColor
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        bars.forEach { bar in
            bar.cornerRadius = 1.5
            bar.anchorPoint = CGPoint(x: 0.5, y: 1)
            bar.shadowOpacity = 1
            bar.shadowRadius = 3
            bar.shadowOffset = .zero
            layer.addSublayer(bar)
        }
        tint = VoiceLoungeSkin.defaultSkin.mid
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let totalWidth = 3 * 3 + 2 * 2.5
        var x = (bounds.width - totalWidth) / 2
        bars.enumerated().forEach { index, bar in
            bar.bounds = CGRect(x: 0, y: 0, width: 3, height: Self.maxHeight)
            bar.position = CGPoint(x: x + 1.5, y: bounds.height)
            bar.transform = CATransform3DMakeScale(1, Self.restHeights[index] / Self.maxHeight, 1)
            x += 3 + 2.5
        }
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateAnimation()
    }

    func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        updateAnimation()
    }

    private func updateAnimation() {
        bars.forEach { $0.removeAnimation(forKey: "equalizer") }
        guard isPlaying, window != nil else { return }
        let now = CACurrentMediaTime()
        bars.enumerated().forEach { index, bar in
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 5 / Self.maxHeight
            animation.toValue = 1
            animation.duration = 0.4
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = now + 0.15 * Double(index)
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .backwards
            animation.isRemovedOnCompletion = false
            bar.add(animation, forKey: "equalizer")
        }
    }
}

private enum MusicStyle {
    static let horizontalInset: CGFloat = 16
    static let toolbarTop: CGFloat = 58
    static let listTop: CGFloat = 104
    static let bottomInset: CGFloat = 44
    static let rowHeight: CGFloat = 52
    static let rowSpacing: CGFloat = 2
    static let controlSize: CGFloat = 26
    static let playSize: CGFloat = 36
    static let ink2 = UIColor.white.withAlphaComponent(0.72)
    static let ink3 = UIColor.white.withAlphaComponent(0.45)
    static let glassLine = UIColor.white.withAlphaComponent(0.08)
    static let glassFill = UIColor.white.withAlphaComponent(0.05)
}

private extension String {
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.bgm") }
    static var previous: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.prev") }
    static var next: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.next") }
    static var volume: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.volume") }
    static var play: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.play") }
    static var pause: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.pause") }
    static var modeOrder: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.mode_order") }
    static var modeSingle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.mode_single") }
    static var modeShuffle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.bgm.mode_shuffle") }
    static func modeTip(_ mode: String) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.bgm.mode_tip", mode)
    }
}
