import AtomicXCore
import ImSDK_Plus
import SnapKit
import UIKit
import Kingfisher

@MainActor
final class HostInfoView: UIView {
    var onError: ((String) -> Void)?

    private let likeStore: LiveUIStore
    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let likeLabel = UILabel()
    private let followButton = UIButton(type: .custom)
    private var hostUserID = ""
    private var followingHostUserIDs: Set<String> = []
    private var friendshipListenerBridge: FriendshipListenerBridge?
    private var lastFollowTapTime: TimeInterval = 0
    private let capsuleGradient = CAGradientLayer()

    init(likeStore: LiveUIStore) {
        self.likeStore = likeStore
        super.init(frame: .zero)
        configureAppearance()
        configureSubviews()
        bindLikeStore()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            registerFriendshipListener()
        } else {
            unregisterFriendshipListener()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsuleGradient.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 36)
    }

    private func configureAppearance() {
        layer.cornerRadius = 18
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        capsuleGradient.colors = [
            UIColor(red: 0.039, green: 0.047, blue: 0.071, alpha: 0.22).cgColor,
            UIColor(red: 0.055, green: 0.063, blue: 0.11, alpha: 0.20).cgColor,
            UIColor(red: 0.482, green: 0.302, blue: 1, alpha: 0.18).cgColor,
            UIColor(red: 1, green: 0.357, blue: 0.478, alpha: 0.16).cgColor,
        ]
        capsuleGradient.locations = [0, 0.52, 0.82, 1]
        capsuleGradient.startPoint = CGPoint(x: 0, y: 0.5)
        capsuleGradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(capsuleGradient, at: 0)
    }

    private func configureSubviews() {
        avatarView.backgroundColor = UIColor(red: 0.141, green: 0.188, blue: 0.278, alpha: 1)
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 16

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.numberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        likeLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        likeLabel.font = .systemFont(ofSize: 10)
        likeLabel.lineBreakMode = .byClipping
        likeLabel.numberOfLines = 1
        likeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        likeLabel.setContentHuggingPriority(.required, for: .horizontal)

        followButton.setTitleColor(.white, for: .normal)
        followButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        followButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 9, bottom: 0, right: 9)
        followButton.layer.cornerRadius = 13.5
        followButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        followButton.setContentHuggingPriority(.required, for: .horizontal)
        followButton.addTarget(self, action: #selector(handleFollowTap), for: .touchUpInside)
        applyFollowButtonStyle()

        let avatarContainer = UIView()
        avatarContainer.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        avatarContainer.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }

        let textStack = UIStackView(arrangedSubviews: [titleLabel, likeLabel])
        textStack.axis = .vertical
        textStack.spacing = 0
        textStack.alignment = .leading
        textStack.distribution = .fillEqually
        titleLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(80)
        }

        followButton.snp.makeConstraints { make in
            make.height.equalTo(28)
            make.width.greaterThanOrEqualTo(44)
        }

        let contentStack = UIStackView(arrangedSubviews: [avatarContainer, textStack, followButton])
        contentStack.axis = .horizontal
        contentStack.spacing = 2
        contentStack.alignment = .center
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2)
        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(_ liveInfo: LiveInfo) {
        let ownerName = liveInfo.liveOwner.userName.isEmpty
            ? liveInfo.liveOwner.userID
            : liveInfo.liveOwner.userName
        titleLabel.text = ownerName.count > 7 ? String(ownerName.prefix(7)) + "…" : ownerName
        updateLikeCount(likeStore.state.likeCount)
        bindFollowState(ownerUserID: liveInfo.liveOwner.userID)
        let avatarURL = URL(string: liveInfo.liveOwner.avatarURL)
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: avatarURL, placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    func prepareForReuse() {
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: Optional<URL>.none)
        titleLabel.text = nil
        hostUserID = ""
        followingHostUserIDs.removeAll()
        lastFollowTapTime = 0
        setFollowButtonHidden(false)
        applyFollowButtonStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func bindLikeStore() {
        likeStore.onStateChanged = { [weak self] state in
            self?.updateLikeCount(state.likeCount)
        }
    }

    private func updateLikeCount(_ count: UInt) {
        likeLabel.text = String.localizedStringWithFormat(
            LiveKitResources.localizedString("tuilivekit.player.like_count"),
            count
        )
    }

    private func bindFollowState(ownerUserID: String) {
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        if ownerUserID.isEmpty || ownerUserID == selfID {
            hostUserID = ownerUserID
            setFollowButtonHidden(true)
            return
        }
        hostUserID = ownerUserID
        setFollowButtonHidden(false)
        applyFollowButtonStyle()
        checkFollowType(userID: ownerUserID)
    }

    private func setFollowButtonHidden(_ hidden: Bool) {
        followButton.isHidden = hidden
    }

    @objc private func handleFollowTap() {
        guard !hostUserID.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFollowTapTime >= 1 else { return }
        lastFollowTapTime = now
        let userID = hostUserID
        let isFollowing = followingHostUserIDs.contains(userID)
        updateFollowingSet(userID: userID, followed: !isFollowing)
        if isFollowing {
            unfollowUser(userID: userID)
        } else {
            followUser(userID: userID)
        }
    }

    private func checkFollowType(userID: String) {
        V2TIMManager.sharedInstance()?.checkFollowType(
            userIDList: [userID],
            succ: { [weak self] results in
                DispatchQueue.main.async {
                    guard let self, self.hostUserID == userID, let result = results?.first else { return }
                    let followed = HostInfoView.isFollowed(followType: result.followType)
                    self.updateFollowingSet(userID: result.userID, followed: followed)
                }
            },
            fail: { [weak self] _, message in
                DispatchQueue.main.async {
                    guard let self, self.hostUserID == userID else { return }
                    self.reportError(message)
                }
            }
        )
    }

    private func followUser(userID: String) {
        V2TIMManager.sharedInstance()?.followUser(
            userIDList: [userID],
            succ: nil,
            fail: { [weak self] _, message in
                DispatchQueue.main.async {
                    guard let self, self.hostUserID == userID else { return }
                    self.reportError(message)
                }
            }
        )
    }

    private func unfollowUser(userID: String) {
        V2TIMManager.sharedInstance()?.unfollowUser(
            userIDList: [userID],
            succ: nil,
            fail: { [weak self] _, message in
                DispatchQueue.main.async {
                    guard let self, self.hostUserID == userID else { return }
                    self.reportError(message)
                }
            }
        )
    }

    private func reportError(_ message: String?) {
        let fallback = LiveKitResources.localizedString("tuilivekit.player.operation_failed")
        onError?(message.flatMap { $0.isEmpty ? nil : $0 } ?? fallback)
    }

    fileprivate func updateFollowingSet(userID: String?, followed: Bool) {
        guard let userID, !userID.isEmpty else { return }
        let changed: Bool
        if followed {
            changed = followingHostUserIDs.insert(userID).inserted
        } else {
            changed = followingHostUserIDs.remove(userID) != nil
        }
        if changed && userID == hostUserID {
            applyFollowButtonStyle()
        }
    }

    fileprivate func handleFollowingListChanged(userIDs: [String]) {
        guard !userIDs.isEmpty else { return }
        V2TIMManager.sharedInstance()?.checkFollowType(
            userIDList: userIDs,
            succ: { [weak self] results in
                DispatchQueue.main.async {
                    guard let self, let results else { return }
                    for result in results {
                        let followed = HostInfoView.isFollowed(followType: result.followType)
                        self.updateFollowingSet(userID: result.userID, followed: followed)
                    }
                }
            },
            fail: { [weak self] _, message in
                DispatchQueue.main.async {
                    self?.reportError(message)
                }
            }
        )
    }

    private static func isFollowed(followType: V2TIMFollowType) -> Bool {
        return followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST
            || followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST
    }

    private func registerFriendshipListener() {
        guard friendshipListenerBridge == nil else { return }
        let bridge = FriendshipListenerBridge(owner: self)
        V2TIMManager.sharedInstance()?.addFriendListener(listener: bridge)
        friendshipListenerBridge = bridge
    }

    private func unregisterFriendshipListener() {
        guard let bridge = friendshipListenerBridge else { return }
        V2TIMManager.sharedInstance()?.removeFriendListener(listener: bridge)
        friendshipListenerBridge = nil
    }

    private func applyFollowButtonStyle() {
        let isFollowing = !hostUserID.isEmpty && followingHostUserIDs.contains(hostUserID)
        followButton.setTitleColor(.white, for: .normal)
        followButton.layer.shadowOpacity = 0
        if isFollowing {
            followButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.unfollow"), for: .normal)
            followButton.backgroundColor = UIColor(red: 0.996, green: 0.157, blue: 0.463, alpha: 0.25)
            followButton.layer.borderWidth = 1
            followButton.layer.borderColor = UIColor(red: 0.996, green: 0.157, blue: 0.463, alpha: 0.38).cgColor
        } else {
            followButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.follow"), for: .normal)
            followButton.backgroundColor = UIColor(red: 0.996, green: 0.157, blue: 0.463, alpha: 1)
            followButton.layer.borderWidth = 0
            followButton.layer.borderColor = UIColor.clear.cgColor
        }
    }
}

private final class FriendshipListenerBridge: NSObject, V2TIMFriendshipListener {
    private weak var owner: HostInfoView?

    init(owner: HostInfoView) {
        self.owner = owner
        super.init()
    }

    func onMyFollowingListChanged(userInfoList: [V2TIMUserFullInfo]!, isAdd: Bool) {
        let userIDs: [String] = (userInfoList ?? []).compactMap { info in
            let id = info.userID ?? ""
            return id.isEmpty ? nil : id
        }
        guard !userIDs.isEmpty else { return }
        let owner = self.owner
        DispatchQueue.main.async {
            owner?.handleFollowingListChanged(userIDs: userIDs)
        }
    }
}
