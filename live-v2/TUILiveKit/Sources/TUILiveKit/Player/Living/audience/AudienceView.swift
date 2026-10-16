import Kingfisher
import AtomicXCore
import Combine
import SnapKit
import UIKit

@MainActor
final class AudienceView: UIView {
    fileprivate static let maxShowAvatarCount = 3
    fileprivate static let avatarSize: CGFloat = 26
    fileprivate static let avatarStep: CGFloat = 17

    var onToast: ((String) -> Void)?
    var onAudience: (() -> Void)?
    var onAudienceEntered: ((AudienceWelcome) -> Void)?

    private let audienceCount = UIView()
    private let audienceCountLabel = UILabel()
    private let audienceList = AudienceAvatarStackView()

    private var liveID = ""
    private var cancellableSet = Set<AnyCancellable>()
    private var audienceListWidthConstraint: Constraint?
    private var lastTapTime: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        bindInteraction()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancellableSet.removeAll()
        } else if !liveID.isEmpty, cancellableSet.isEmpty {
            subscribeState()
            guard !liveID.isEmpty else { return }
            let audienceStore = LiveAudienceStore.create(liveID: liveID)
            audienceStore.fetchAudienceList(completion: nil)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ liveInfo: LiveInfo) {
        cancellableSet.removeAll()
        liveID = liveInfo.liveID
        renderAudienceCount(0)
        renderAudienceList([])
        guard !liveID.isEmpty else { return }

        let audienceStore = LiveAudienceStore.create(liveID: liveID)
        subscribeState()
        audienceStore.fetchAudienceList(completion: nil)
    }

    func unbind() {
        cancellableSet.removeAll()
        liveID = ""
        lastTapTime = 0
        renderAudienceCount(0)
        renderAudienceList([])
    }

    func setCleanScreenProgress(_ progress: CGFloat, travelDistance: CGFloat) {
        let clampedProgress = min(max(progress, 0), 1)
        transform = CGAffineTransform(
            translationX: travelDistance * clampedProgress,
            y: 0
        )
        alpha = 1 - clampedProgress
        isUserInteractionEnabled = clampedProgress == 0
        accessibilityElementsHidden = clampedProgress > 0
    }
}

extension AudienceView {
    private func setupViews() {
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button
        isUserInteractionEnabled = true

        audienceList.isUserInteractionEnabled = false

        audienceCount.backgroundColor = LiveVideoOverlayStyle.capsuleBackground
        audienceCount.layer.cornerRadius = 13
        audienceCount.layer.masksToBounds = true

        audienceCountLabel.textColor = .white
        audienceCountLabel.font = AudienceViewTypography.audienceCountFont
        audienceCountLabel.textAlignment = .center
        audienceCountLabel.adjustsFontSizeToFitWidth = true
        audienceCountLabel.minimumScaleFactor = 0.8

        addSubview(audienceList)
        addSubview(audienceCount)
        audienceCount.addSubview(audienceCountLabel)

        renderAudienceCount(0)
    }

    private func setupConstraints() {
        audienceList.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(AudienceView.avatarSize)
            audienceListWidthConstraint = make.width.equalTo(0).constraint
        }
        audienceCount.snp.makeConstraints { make in
            make.leading.equalTo(audienceList.snp.trailing).offset(4)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(26)
            make.width.greaterThanOrEqualTo(26)
        }
        audienceCountLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(8)
        }
        updateAudienceListWidth()
    }

    private func bindInteraction() {
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }
}

extension AudienceView {
    private func subscribeState() {
        guard !liveID.isEmpty else { return }
        let audienceStore = LiveAudienceStore.create(liveID: liveID)
        let subscribedLiveID = liveID

        audienceStore.state.subscribe()
            .map { $0.audienceCount }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self, self.liveID == subscribedLiveID else { return }
                renderAudienceCount(count)
            }
            .store(in: &cancellableSet)

        audienceStore.state.subscribe()
            .map { $0.audienceList }
            .removeDuplicates(by: { lhs, rhs in
                AudienceView.isSameAudienceList(lhs, rhs)
            })
            .receive(on: RunLoop.main)
            .sink { [weak self] audiences in
                guard let self, self.liveID == subscribedLiveID else { return }
                let items = self.makeAudienceItems(from: audiences)
                self.renderAudienceList(items)
            }
            .store(in: &cancellableSet)

        audienceStore.liveAudienceEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.liveID == subscribedLiveID else { return }
                switch event {
                case let .onAudienceMessageDisabled(audience, isDisable):
                    if audience.userID == LoginStore.shared.state.value.loginUserInfo?.userID {
                        let key = isDisable
                            ? "tuilivekit.player.audience.message_disabled"
                            : "tuilivekit.player.audience.message_enabled"
                        self.onToast?(LiveKitResources.localizedString(key))
                    }
                case let .onAudienceJoined(audience):
                    guard !audience.userID.isEmpty else { return }
                    self.onAudienceEntered?(AudienceWelcome(
                        userID: audience.userID,
                        userName: audience.userName.isEmpty ? audience.userID : audience.userName,
                        level: max(0, audience.level)
                    ))
                default:
                    break
                }
            }
            .store(in: &cancellableSet)
    }

    private static func isSameAudienceList(
        _ lhs: [LiveUserInfo],
        _ rhs: [LiveUserInfo]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in 0..<lhs.count {
            if lhs[index].userID != rhs[index].userID { return false }
            if lhs[index].avatarURL != rhs[index].avatarURL { return false }
        }
        return true
    }

    private func makeAudienceItems(
        from audiences: [LiveUserInfo]
    ) -> [AudienceAvatarItem] {
        let limit = AudienceView.maxShowAvatarCount
        var items: [AudienceAvatarItem] = []
        items.reserveCapacity(min(audiences.count, limit))
        for audience in audiences.prefix(limit) {
            let item = AudienceAvatarItem(
                id: audience.userID,
                avatarURL: audience.avatarURL
            )
            items.append(item)
        }
        return items
    }
}

extension AudienceView {
    private func renderAudienceCount(_ count: UInt) {
        audienceCountLabel.text = String(count)
        audienceCount.accessibilityLabel = String.localizedStringWithFormat(
            LiveKitResources.localizedString("tuilivekit.player.audience_count"),
            count
        )
        accessibilityLabel = audienceCount.accessibilityLabel
    }

    private func renderAudienceList(_ items: [AudienceAvatarItem]) {
        audienceList.setItems(items)
        updateAudienceListWidth()
    }

    private func updateAudienceListWidth() {
        let visibleCount = audienceList.visibleItemCount
        let width: CGFloat = visibleCount == 0
            ? 0
            : AudienceView.avatarSize + CGFloat(max(visibleCount - 1, 0)) * AudienceView.avatarStep
        audienceListWidthConstraint?.update(offset: width)
        audienceList.isHidden = visibleCount == 0
        setNeedsLayout()
    }

    @objc private func handleTap() {
        guard !liveID.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTapTime >= 1 else { return }
        lastTapTime = now
        onAudience?()
    }
}

struct AudienceAvatarItem: Equatable {
    let id: String
    let avatarURL: String
}

@MainActor
private final class AudienceAvatarStackView: UIView {
    private var items: [AudienceAvatarItem] = []
    private var avatarViews: [AudienceAvatarItemView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var visibleItemCount: Int {
        min(items.count, AudienceView.maxShowAvatarCount)
    }

    func setItems(_ items: [AudienceAvatarItem]) {
        self.items = items
        rebuildAvatars()
    }

    private func rebuildAvatars() {
        let visible = Array(items.prefix(AudienceView.maxShowAvatarCount))

        while avatarViews.count > visible.count {
            avatarViews.removeLast().removeFromSuperview()
        }
        while avatarViews.count < visible.count {
            let view = AudienceAvatarItemView()
            avatarViews.append(view)
            addSubview(view)
        }

        for (index, item) in visible.enumerated() {
            let view = avatarViews[index]
            view.frame = CGRect(
                x: CGFloat(index) * AudienceView.avatarStep,
                y: 0,
                width: AudienceView.avatarSize,
                height: AudienceView.avatarSize
            )
            view.layer.zPosition = CGFloat(visible.count - index)
            view.bind(item, showLeftCutout: index > 0)
        }
    }
}

@MainActor
private final class AudienceAvatarItemView: UIView {
    private let avatarView = UIImageView()
    private let cutoutLayer = CAShapeLayer()

    private var representedAvatarURL = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")

        addSubview(avatarView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarView.frame = bounds
        avatarView.layer.cornerRadius = bounds.width / 2
        updateMask()
    }

    func bind(_ item: AudienceAvatarItem, showLeftCutout: Bool) {
        if representedAvatarURL != item.avatarURL {
            avatarView.kf.cancelDownloadTask()
            representedAvatarURL = item.avatarURL
            avatarView.kf.setImage(with: URL(string: item.avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
        }
        applyCutout(enabled: showLeftCutout)
    }

    private func applyCutout(enabled: Bool) {
        if enabled {
            avatarView.layer.mask = cutoutLayer
        } else {
            avatarView.layer.mask = nil
        }
        updateMask()
    }

    private func updateMask() {
        guard avatarView.layer.mask === cutoutLayer else { return }
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let cutoutRadius = size.width / 2 + 1
        let neighborCenter = CGPoint(
            x: -AudienceView.avatarStep + size.width / 2,
            y: size.height / 2
        )

        let path = UIBezierPath(rect: bounds)
        let cutoutRect = CGRect(
            x: neighborCenter.x - cutoutRadius,
            y: neighborCenter.y - cutoutRadius,
            width: cutoutRadius * 2,
            height: cutoutRadius * 2
        )
        path.append(UIBezierPath(ovalIn: cutoutRect).reversing())

        cutoutLayer.frame = bounds
        cutoutLayer.path = path.cgPath
        cutoutLayer.fillRule = .evenOdd
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum AudienceViewTypography {
    static let audienceCountFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .medium)
}
