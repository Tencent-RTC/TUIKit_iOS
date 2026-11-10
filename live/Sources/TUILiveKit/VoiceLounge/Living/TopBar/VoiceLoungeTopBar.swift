import AtomicXCore
import Combine
import ImSDK_Plus
import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeTopBar: UIView {
    var onClose: (() -> Void)?

    private let role: VoiceLoungeRole
    private let liveID: String
    private let settings: VoiceLoungeSettings
    private let giftRankStore: VoiceLoungeGiftRankStore
    private let clock: VoiceLoungeLiveClock
    private lazy var giftRankPanel = VoiceLoungeGiftRankPanel(store: giftRankStore)
    private lazy var statusPanel = VoiceLoungeStatusPanel(liveID: liveID, clock: clock)
    private var settingsSubscription: AnyCancellable?
    private var countCancellables = Set<AnyCancellable>()
    private var likeCount = 0
    private var giftRankSubscription: AnyCancellable?

    private let hostCard = UIControl()
    private let hostAvatarView = UIImageView()
    private let roomNameLabel = LiveText.voiceLounge(.action, tone: .primary)
    private let statLabel = RollingStatLabel()
    private let hifiBadge = HifiBadgeLabel()
    private let audiencePresence = AudienceView()
    private let endButton = UIControl()
    private let endIconView = UIImageView()
    private let followButton = UIControl()
    private let followLabel = UILabel(font: VoiceLoungeTopBarStyle.followFont, alignment: .center)
    private var isFollowed = false
    private var followCheckedUserID = ""
    private var lastFollowTapTime: TimeInterval = 0

    private let giftRankPill = PillButton(title: .giftRank)
    private let plazaPill = PillButton(title: .plaza, showsChevron: true)
    private let spacer = UIView()
    private lazy var line2Stack = UIStackView([statLabel, hifiBadge], axis: .horizontal, spacing: 6, alignment: .center)
    private lazy var textStack = UIStackView(
        [roomNameLabel, line2Stack], axis: .vertical, spacing: 2, alignment: .leading, interactive: false)
    private lazy var cardStack = UIStackView(
        [hostAvatarView, textStack, followButton], axis: .horizontal, spacing: 7, alignment: .center)
    private lazy var subBar = UIStackView([giftRankPill, spacer, plazaPill], axis: .horizontal, spacing: 10, alignment: .center)

    private var skin = VoiceLoungeSkin.defaultSkin

    init(
        role: VoiceLoungeRole, liveID: String, settings: VoiceLoungeSettings,
        giftRankStore: VoiceLoungeGiftRankStore, clock: VoiceLoungeLiveClock
    ) {
        self.role = role
        self.liveID = liveID
        self.settings = settings
        self.giftRankStore = giftRankStore
        self.clock = clock
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        renderRoom()
        renderCounts()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(hostCard)
        hostCard.addSubview(cardStack)
        followButton.addSubview(followLabel)
        addSubview(audiencePresence)
        addSubview(endButton)
        endButton.addSubview(endIconView)
        addSubview(subBar)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func setupConstraints() {
        cardStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(4)
        }
        hostAvatarView.snp.makeConstraints { $0.size.equalTo(VoiceLoungeTopBarStyle.avatarSize) }
        followButton.snp.makeConstraints { make in
            make.height.equalTo(VoiceLoungeTopBarStyle.followHeight)
            make.width.greaterThanOrEqualTo(52)
        }
        followLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
        }
        endButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalTo(hostCard)
            make.size.equalTo(VoiceLoungeTopBarStyle.endSize)
        }
        endIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(16)
        }
        audiencePresence.snp.makeConstraints { make in
            make.trailing.equalTo(endButton.snp.leading).offset(-6)
            make.centerY.equalTo(endButton)
            make.height.equalTo(26)
        }
        hostCard.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.top.equalToSuperview()
            make.height.equalTo(VoiceLoungeTopBarStyle.cardHeight)
            make.trailing.lessThanOrEqualTo(audiencePresence.snp.leading).offset(-8)
        }
        subBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.top.equalTo(hostCard.snp.bottom).offset(10)
            make.height.equalTo(26)
            make.bottom.equalToSuperview()
        }
    }

    private func setupStyles() {
        hostCard.rounded(VoiceLoungeTopBarStyle.cardCorner, background: VoiceLoungeColor.card)
        endButton.rounded(VoiceLoungeTopBarStyle.endSize / 2, background: VoiceLoungeColor.card)
        followButton.rounded(VoiceLoungeTopBarStyle.followHeight / 2)
        hostAvatarView.rounded(VoiceLoungeTopBarStyle.avatarSize / 2, clips: true)
        hostAvatarView.contentMode = .scaleAspectFill
        roomNameLabel.font = VoiceLoungeTopBarStyle.roomNameFont
        endIconView.image = LiveKitResources.image(named: "livekit_voiceprepare_close")
        endIconView.contentMode = .scaleAspectFit
        followButton.isHidden = role != .audience
        plazaPill.isHidden = role != .host
        renderFollowButton()
    }

    private func setupBindings() {
        endButton.addTarget(self, action: #selector(tapEnd), for: .touchUpInside)
        followButton.addTarget(self, action: #selector(tapFollow), for: .touchUpInside)
        giftRankPill.onTap = { [weak self] in self?.showGiftRank() }
        plazaPill.onTap = { [weak self] in self?.showLiveStatus() }
        settingsSubscription = settings.changes.sink { [weak self] in self?.renderRoom() }
        giftRankSubscription = giftRankStore.changes.sink { [weak self] in self?.renderCounts() }
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

    private var panels: [BottomSheetView] { role == .host ? [giftRankPanel, statusPanel] : [giftRankPanel] }

    func activate() {
        guard countCancellables.isEmpty else { return }
        var liveInfo = LiveInfo()
        liveInfo.liveID = liveID
        audiencePresence.bind(liveInfo)
        LikeStore.create(liveID: liveID).state.subscribe().map { Int($0.totalLikeCount) }.removeDuplicates().receive(
            on: DispatchQueue.main
        ).sink { [weak self] count in
            self?.likeCount = count
            self?.renderCounts()
        }.store(in: &countCancellables)
    }

    func deactivate() {
        countCancellables.removeAll()
        audiencePresence.unbind()
        likeCount = 0
        renderCounts()
    }

    private func renderRoom() {
        roomNameLabel.text = settings.displayRoomName
        checkFollowIfNeeded()
        let avatarURL = settings.hostAvatarURL
        if avatarURL.isEmpty {
            hostAvatarView.image = nil
            hostAvatarView.backgroundColor = VoiceLoungeColor.avatarPlaceholders[0]
        } else {
            hostAvatarView.backgroundColor = .clear
            hostAvatarView.kf.setImage(
                with: URL(string: avatarURL),
                placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
        }
        skin = settings.skin
        hifiBadge.textColor = skin.light
        [giftRankPill, plazaPill].forEach { $0.applySkin(skin.mid) }
    }

    private func renderCounts() {
        statLabel.setItems([.likeStat("\(likeCount)"), .giftStat("\(giftRankStore.giftCount)")])
    }

    private func showGiftRank() { giftRankPanel.show() }

    private func showLiveStatus() {
        guard role == .host else { return }
        statusPanel.show()
    }

    private func renderFollowButton() {
        if isFollowed {
            followLabel.text = .followed
            followButton.backgroundColor = VoiceLoungeColor.overlayMarked
            followLabel.textColor = LiveTheme.Color.text(.secondary)
        } else {
            followLabel.text = .follow
            followButton.backgroundColor = VoiceLoungeTopBarStyle.followBackground
            followLabel.textColor = .white
        }
    }

    private func finishFollow(isFollowed: Bool, hostUserID: String) {
        followButton.isEnabled = true
        guard hostUserID == settings.hostUserID else { return }
        self.isFollowed = isFollowed
        renderFollowButton()
    }

    private func checkFollowIfNeeded() {
        let hostUserID = settings.hostUserID
        guard role == .audience, !hostUserID.isEmpty, hostUserID != followCheckedUserID else { return }
        followCheckedUserID = hostUserID
        isFollowed = false
        renderFollowButton()
        V2TIMManager.sharedInstance()?.checkFollowType(
            userIDList: [hostUserID],
            succ: { [weak self] results in
                DispatchQueue.main.async {
                    guard let self, hostUserID == self.settings.hostUserID, let type = results?.first?.followType else {
                        return
                    }
                    self.isFollowed =
                        type == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST || type == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST
                    self.renderFollowButton()
                }
            },
            fail: { code, message in
                LiveKitLog.error("[VoiceLounge] checkFollowType failed code=\(code) message=\(message ?? "")")
            })
    }
}

extension VoiceLoungeTopBar {
    @objc private func tapEnd() { onClose?() }
    @objc private func tapFollow() {
        let hostUserID = settings.hostUserID
        let now = ProcessInfo.processInfo.systemUptime
        guard !hostUserID.isEmpty, now - lastFollowTapTime >= 1 else { return }
        lastFollowTapTime = now
        followButton.isEnabled = false
        let target = !isFollowed
        let succ: V2TIMFollowOperationResultListSucc = { [weak self] _ in
            DispatchQueue.main.async { self?.finishFollow(isFollowed: target, hostUserID: hostUserID) }
        }
        let fail: V2TIMFail = { [weak self] code, message in
            LiveKitLog.error("[VoiceLounge] follow failed target=\(target) code=\(code) message=\(message ?? "")")
            DispatchQueue.main.async { self?.followButton.isEnabled = true }
        }
        if target {
            V2TIMManager.sharedInstance()?.followUser(userIDList: [hostUserID], succ: succ, fail: fail)
        } else {
            V2TIMManager.sharedInstance()?.unfollowUser(userIDList: [hostUserID], succ: succ, fail: fail)
        }
    }
}

private enum VoiceLoungeTopBarStyle {
    static let cardHeight: CGFloat = 46
    static let cardCorner: CGFloat = 23
    static let avatarSize: CGFloat = 38
    static let endSize: CGFloat = 36
    static let roomNameFont: UIFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
    static let followHeight: CGFloat = 28
    static let followFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
    static let followBackground: UIColor = VoiceLoungeColor.rose
}

private final class HifiBadgeLabel: UILabel {
    private let insets = UIEdgeInsets(top: 1, left: 5, bottom: 1, right: 5)

    override init(frame: CGRect) {
        super.init(frame: frame)
        text = "HiFi"
        font = .systemFont(ofSize: 11, weight: .semibold)
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        layer.cornerRadius = 7
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
}

private final class PillButton: UIControl {
    var onTap: (() -> Void)?

    private let titleLabel = LiveText.voiceLounge(.control, tone: .primary, emphasized: true)
    private let chevron = UIImageView()

    init(title: String, showsChevron: Bool = false) {
        super.init(frame: .zero)
        let stack = UIStackView([titleLabel, chevron], axis: .horizontal, spacing: 2, interactive: false)
        addSubview(stack)
        layer.cornerRadius = 13
        titleLabel.text = title
        chevron.image = LiveKitResources.image(named: "livekit_living_status_chevron")?.withRenderingMode(
            .alwaysTemplate)
        chevron.contentMode = .scaleAspectFit
        chevron.isHidden = !showsChevron
        chevron.snp.makeConstraints { $0.size.equalTo(CGSize(width: 5, height: 9)) }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        }
        snp.makeConstraints { $0.height.equalTo(26) }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applySkin(_ color: UIColor) {
        backgroundColor = color.withAlphaComponent(0.26)
        let text = Self.lighten(color)
        titleLabel.textColor = text
        chevron.tintColor = text
    }

    private static func lighten(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        return UIColor(hue: h, saturation: max(0, s - 0.3), brightness: min(1, b + 0.35), alpha: 1)
    }

    @objc private func tap() { onTap?() }
}

private final class RollingStatLabel: UIView {
    private static let interval: TimeInterval = 3
    private static let lineHeight: CGFloat = 17

    private let frontLabel = LiveText.voiceLounge(.metadata, tone: .secondary)
    private let backLabel = LiveText.voiceLounge(.metadata, tone: .secondary)
    private var items: [String] = []
    private var currentIndex = 0
    private var timer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(frontLabel)
        addSubview(backLabel)
        snp.makeConstraints { $0.height.equalTo(Self.lineHeight) }
        clipsToBounds = true
        isUserInteractionEnabled = false
        backLabel.alpha = 0
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setItems(_ items: [String]) {
        guard items != self.items else { return }
        let countChanged = items.count != self.items.count
        self.items = items
        if currentIndex >= items.count { currentIndex = 0 }
        frontLabel.text = items.isEmpty ? nil : items[currentIndex]
        invalidateIntrinsicContentSize()
        if countChanged { updateTimer() }
    }

    override var intrinsicContentSize: CGSize {
        let width =
            items.map { ($0 as NSString).size(withAttributes: [.font: frontLabel.font as Any]).width }.max() ?? 0
        return CGSize(width: ceil(width), height: Self.lineHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        frontLabel.frame = bounds
        backLabel.frame = bounds.offsetBy(dx: 0, dy: bounds.height)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateTimer()
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard window != nil, items.count > 1 else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func advance() {
        guard items.count > 1 else { return }
        currentIndex = (currentIndex + 1) % items.count
        backLabel.text = items[currentIndex]
        let height = bounds.height
        backLabel.frame = bounds.offsetBy(dx: 0, dy: height)
        backLabel.alpha = 1
        UIView.animate(
            withDuration: 0.35, delay: 0, options: [.curveEaseInOut],
            animations: {
                self.frontLabel.frame = self.bounds.offsetBy(dx: 0, dy: -height)
                self.frontLabel.alpha = 0
                self.backLabel.frame = self.bounds
            },
            completion: { [weak self] _ in
                guard let self else { return }
                self.frontLabel.text = self.items.isEmpty ? nil : self.items[self.currentIndex]
                self.frontLabel.frame = self.bounds
                self.frontLabel.alpha = 1
                self.backLabel.alpha = 0
                self.backLabel.frame = self.bounds.offsetBy(dx: 0, dy: height)
            })
    }
}

private extension String {
    static var follow: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.follow") }
    static var followed: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.followed") }
    static var giftRank: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.gift_rank") }
    static func giftStat(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.room.gift_stat", args)
    }
    static func likeStat(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.room.like_stat", args)
    }
    static var plaza: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.plaza") }
}

private extension UIView {
    func rounded(_ radius: CGFloat, background: UIColor? = nil, clips: Bool = false) {
        layer.cornerRadius = radius
        if let background { backgroundColor = background }
        if clips { clipsToBounds = true }
    }
}

private extension UILabel {
    convenience init(font: UIFont, alignment: NSTextAlignment = .natural) {
        self.init(frame: .zero)
        self.font = font
        textAlignment = alignment
    }
}

private extension UIStackView {
    convenience init(
        _ views: [UIView], axis: NSLayoutConstraint.Axis, spacing: CGFloat,
        alignment: UIStackView.Alignment = .fill, interactive: Bool = true
    ) {
        self.init(arrangedSubviews: views)
        self.axis = axis
        self.spacing = spacing
        self.alignment = alignment
        isUserInteractionEnabled = interactive
    }
}
