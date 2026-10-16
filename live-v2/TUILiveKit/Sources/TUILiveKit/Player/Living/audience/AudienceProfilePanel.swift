import Kingfisher
import ImSDK_Plus
import SnapKit
import UIKit

@MainActor
final class AudienceProfilePanel: BottomSheetView {
    override var sheetHeight: CGFloat { 212 + safeAreaInsets.bottom }

    private let userID: String
    private let userName: String
    private let avatarURL: String
    private let avatarBorderView = AudienceProfileGradientBorderView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let followButton = AudienceProfileFollowButton(type: .custom)
    private var isFollowing = false
    private var lastFollowTapTime: TimeInterval = 0

    init(userID: String, userName: String, avatarURL: String) {
        self.userID = userID
        self.userName = userName
        self.avatarURL = avatarURL
        super.init(frame: .zero)
        configureUI()
        bindUser()
        checkFollowType()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Task { @MainActor [avatarView] in
            avatarView.kf.cancelDownloadTask()
        }
    }

    override func sheetDidDismiss() {
        removeFromSuperview()
    }

    private func configureUI() {
        contentView.addSubview(avatarBorderView)
        avatarBorderView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(58)
        }

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 27
        avatarView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        avatarBorderView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(54)
        }

        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarBorderView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        followButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        followButton.layer.cornerRadius = 11
        followButton.addTarget(self, action: #selector(toggleFollow), for: .touchUpInside)
        contentView.addSubview(followButton)
        followButton.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(40)
        }
        applyFollowStyle()
    }

    private func bindUser() {
        let rawName = userName.isEmpty ? userID : userName
        nameLabel.text = rawName.count > 15 ? String(rawName.prefix(15)) + "…" : rawName
        guard !avatarURL.isEmpty else { return }
        avatarView.kf.setImage(with: URL(string: avatarURL), placeholder: avatarView.image)
    }

    @objc private func toggleFollow() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFollowTapTime >= 1 else { return }
        lastFollowTapTime = now
        followButton.isEnabled = false
        if isFollowing {
            unfollowUser()
        } else {
            followUser()
        }
    }

    private func checkFollowType() {
        V2TIMManager.sharedInstance()?.checkFollowType(
            userIDList: [userID],
            succ: { [weak self] results in
                DispatchQueue.main.async {
                    guard let self, let result = results?.first else { return }
                    self.isFollowing = Self.isFollowed(result.followType)
                    self.applyFollowStyle()
                }
            },
            fail: nil
        )
    }

    private func followUser() {
        V2TIMManager.sharedInstance()?.followUser(
            userIDList: [userID],
            succ: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isFollowing = true
                    self?.followButton.isEnabled = true
                    self?.applyFollowStyle()
                }
            },
            fail: { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.followButton.isEnabled = true
                }
            }
        )
    }

    private func unfollowUser() {
        V2TIMManager.sharedInstance()?.unfollowUser(
            userIDList: [userID],
            succ: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isFollowing = false
                    self?.followButton.isEnabled = true
                    self?.applyFollowStyle()
                }
            },
            fail: { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.followButton.isEnabled = true
                }
            }
        )
    }

    private func applyFollowStyle() {
        followButton.setTitle(
            LiveKitResources.localizedString(
                isFollowing ? "tuilivekit.player.unfollow" : "tuilivekit.player.follow"
            ),
            for: .normal
        )
        followButton.setTitleColor(
            isFollowing ? UIColor.white.withAlphaComponent(0.72) : .white,
            for: .normal
        )
        followButton.setFollowing(isFollowing)
    }

    private static func isFollowed(_ followType: V2TIMFollowType) -> Bool {
        followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST
            || followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST
    }
}

private final class AudienceProfileGradientBorderView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor(red: 0, green: 0.322, blue: 0.851, alpha: 1).cgColor,
            UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.494, green: 0.91, blue: 1, alpha: 1).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 12
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.height / 2
    }
}

private final class AudienceProfileFollowButton: UIButton {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor(red: 0.055, green: 0.282, blue: 0.725, alpha: 1).cgColor,
            UIColor(red: 0.224, green: 0.463, blue: 0.741, alpha: 1).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = 11
    }

    func setFollowing(_ following: Bool) {
        gradientLayer.isHidden = following
        backgroundColor = following ? UIColor.white.withAlphaComponent(0.07) : .clear
        layer.borderWidth = 1
        layer.borderColor = following
            ? UIColor.white.withAlphaComponent(0.1).cgColor
            : UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 0.35).cgColor
        layer.shadowColor = UIColor(red: 0, green: 0.322, blue: 0.851, alpha: 1).cgColor
        layer.shadowOpacity = following ? 0 : 0.2
        layer.shadowOffset = CGSize(width: 0, height: 7)
        layer.shadowRadius = 9
    }
}
