import UIKit
import SnapKit
import AtomicXCore
import ImSDK_Plus

private let joinCallGroupAttributeKey = "inner_attr_kit_info"

private let joinCallAvatarSize: CGFloat = 52
private let joinCallAvatarSpacing: CGFloat = 14
private let joinCallMaxVisibleAvatarCount = 4
private let joinCallCardCornerRadius: CGFloat = 12
private let joinCallExpandDuration: TimeInterval = 0.22

// MARK: - State（对齐 Android MessageListJoinCallBannerState）

struct JoinCallBannerUser {
    let id: String
    var displayName: String
    var avatarURL: String?
}

struct JoinCallBannerState {
    let callID: String
    let mediaType: String
    var users: [JoinCallBannerUser]
    let isCurrentUserJoined: Bool

    var shouldShowJoinButton: Bool { !isCurrentUserJoined }
}

// MARK: - Parser（对齐 Android MessageListJoinCallBannerStateParser）

enum JoinCallBannerStateParser {
    private static let keyBusinessType = "business_type"
    private static let keyCallID = "call_id"
    private static let keyCallMediaType = "call_media_type"
    private static let keyUserList = "user_list"
    private static let keyUserID = "userid"
    private static let keyUserIDAlt = "userID"
    private static let keyNickname = "nickname"
    private static let keyName = "name"
    private static let keyAvatarURL = "avatar_url"
    private static let keyFaceURL = "faceUrl"
    private static let valueBusinessType = "callkit"

    static func parse(raw: String?, currentUserID: String?) -> JoinCallBannerState? {
        guard let raw = raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let businessType = map[keyBusinessType] as? String
        let callID = map[keyCallID] as? String
        let mediaType = map[keyCallMediaType] as? String
        let users = parseUsers(map[keyUserList])
        guard businessType == valueBusinessType,
              let callID = callID, !callID.isEmpty,
              let mediaType = mediaType, !mediaType.isEmpty,
              users.count > 1 else {
            return nil
        }

        let isCurrentUserJoined = currentUserID != nil && users.contains { $0.id == currentUserID }
        return JoinCallBannerState(
            callID: callID,
            mediaType: mediaType,
            users: users,
            isCurrentUserJoined: isCurrentUserJoined
        )
    }

    private static func parseUsers(_ value: Any?) -> [JoinCallBannerUser] {
        guard let list = value as? [Any] else { return [] }
        return list.compactMap { item in
            guard let userMap = item as? [String: Any] else { return nil }
            let userID = (userMap[keyUserID] as? String) ?? (userMap[keyUserIDAlt] as? String)
            guard let id = userID, !id.isEmpty else { return nil }
            let displayName = (userMap[keyNickname] as? String) ?? (userMap[keyName] as? String) ?? id
            let avatarURL = (userMap[keyAvatarURL] as? String) ?? (userMap[keyFaceURL] as? String)
            return JoinCallBannerUser(id: id, displayName: displayName, avatarURL: avatarURL)
        }
    }
}

// MARK: - Controller（对齐 Android MessageListJoinCallBannerController）

final class MessageListJoinCallBannerController: NSObject {
    private let container: UIView
    private var containerHeightConstraint: Constraint?

    private var currentGroupID: String?
    private var currentCallID: String?
    private var bannerView: MessageListJoinCallBannerView?

    init(container: UIView) {
        self.container = container
        super.init()
        container.isHidden = true
        container.clipsToBounds = true
        container.snp.makeConstraints { make in
            containerHeightConstraint = make.height.equalTo(0).constraint
        }
    }

    func bind(conversationID: String) {
        let groupID = Self.groupID(from: conversationID)
        if groupID == currentGroupID { return }
        release()
        guard let groupID = groupID else {
            hide()
            return
        }
        currentGroupID = groupID
        V2TIMManager.sharedInstance().addGroupListener(listener: self)
        V2TIMManager.sharedInstance().getGroupAttributes(groupID, keys: [joinCallGroupAttributeKey], succ: { [weak self] attributes in
            guard let self = self, groupID == self.currentGroupID else { return }
            DispatchQueue.main.async {
                self.render(attributes: attributes as? [String: String])
            }
        }, fail: { [weak self] _, _ in
            guard let self = self, groupID == self.currentGroupID else { return }
            DispatchQueue.main.async {
                self.hide()
            }
        })
    }

    func release() {
        V2TIMManager.sharedInstance().removeGroupListener(listener: self)
        currentGroupID = nil
        hide()
    }

    // MARK: - Private

    private static func groupID(from conversationID: String) -> String? {
        let prefix = "group_"
        guard conversationID.hasPrefix(prefix) else { return nil }
        let groupID = String(conversationID.dropFirst(prefix.count))
        return groupID.isEmpty ? nil : groupID
    }

    private func render(attributes: [String: String]?) {
        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID
        let state = JoinCallBannerStateParser.parse(raw: attributes?[joinCallGroupAttributeKey], currentUserID: currentUserID)
        guard let state = state, !state.callID.isEmpty else {
            hide()
            return
        }
        currentCallID = state.callID
        let view = bannerView ?? MessageListJoinCallBannerView()
        if bannerView == nil {
            bannerView = view
            container.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        view.bind(state: state)
        show()
        fetchUserProfiles(state: state, view: view)
    }

    private func show() {
        container.isHidden = false
        containerHeightConstraint?.deactivate()
        container.superview?.layoutIfNeeded()
    }

    private func hide() {
        currentCallID = nil
        container.isHidden = true
        containerHeightConstraint?.activate()
        bannerView?.bind(state: nil)
        container.superview?.layoutIfNeeded()
    }

    private func fetchUserProfiles(state: JoinCallBannerState, view: MessageListJoinCallBannerView) {
        let userIDs = state.users.map { $0.id }.filter { !$0.isEmpty }
        guard !userIDs.isEmpty else { return }
        V2TIMManager.sharedInstance().getUsersInfo(userIDs, succ: { [weak self] profiles in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.currentCallID == state.callID,
                      !self.container.isHidden,
                      self.bannerView === view,
                      let profiles = profiles else { return }
                var profileByUserID: [String: V2TIMUserFullInfo] = [:]
                for profile in profiles {
                    if let userID = profile.userID {
                        profileByUserID[userID] = profile
                    }
                }
                guard !profileByUserID.isEmpty else { return }
                var enriched = state
                enriched.users = state.users.map { user in
                    guard let profile = profileByUserID[user.id] else { return user }
                    var updated = user
                    if let nickName = profile.nickName, !nickName.isEmpty {
                        updated.displayName = nickName
                    }
                    if let faceURL = profile.faceURL, !faceURL.isEmpty {
                        updated.avatarURL = faceURL
                    }
                    return updated
                }
                view.bind(state: enriched)
            }
        }, fail: nil)
    }
}

// MARK: - V2TIMGroupListener

extension MessageListJoinCallBannerController: V2TIMGroupListener {
    func onGroupAttributeChanged(_ groupID: String!, attributes: NSMutableDictionary!) {
        guard let groupID = groupID, !groupID.isEmpty, groupID == currentGroupID else { return }
        render(attributes: attributes as? [String: String])
    }
}

// MARK: - View（对齐 Android MessageListJoinCallBannerView）

private final class MessageListJoinCallBannerView: UIView {
    private let card = UIView()
    private let cardContent = UIView()
    private let headerRow = UIView()
    private let callIconImageView = UIImageView()
    private let hintLabel = UILabel()
    private let chevronView = JoinCallChevronView()
    private let expandedContent = UIView()
    private let avatarScrollView = UIScrollView()
    private let avatarStackView = UIStackView()
    private let divider = UIView()
    private let joinButton = UIButton(type: .system)

    private var expandedHeightConstraint: Constraint?
    private var boundCallID: String?
    private var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        addSubview(card)
        card.addSubview(cardContent)
        cardContent.addSubview(headerRow)
        headerRow.addSubview(callIconImageView)
        headerRow.addSubview(hintLabel)
        headerRow.addSubview(chevronView)
        cardContent.addSubview(expandedContent)
        expandedContent.addSubview(avatarScrollView)
        avatarScrollView.addSubview(avatarStackView)
        expandedContent.addSubview(divider)
        expandedContent.addSubview(joinButton)
    }

    private func activateConstraints() {
        // 对齐 Android：卡片外边距 10/6/10/8
        card.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-8)
        }
        cardContent.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        headerRow.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        callIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
            make.width.height.equalTo(22)
        }
        hintLabel.snp.makeConstraints { make in
            make.leading.equalTo(callIconImageView.snp.trailing).offset(12)
            make.centerY.equalTo(callIconImageView)
        }
        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalTo(callIconImageView)
            make.width.height.equalTo(20)
            make.leading.greaterThanOrEqualTo(hintLabel.snp.trailing).offset(12)
        }
        expandedContent.snp.makeConstraints { make in
            make.top.equalTo(headerRow.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        expandedHeightConstraint = expandedContent.snp.prepareConstraints { make in
            make.height.equalTo(0)
        }.first
        expandedHeightConstraint?.activate()

        let avatarViewportWidth = joinCallAvatarSize * CGFloat(joinCallMaxVisibleAvatarCount)
            + joinCallAvatarSpacing * CGFloat(joinCallMaxVisibleAvatarCount - 1)
        avatarScrollView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            // 对齐 Android MaxWidthRecyclerView：宽度由内容撑开，上限为 4 个头像的视口宽
            make.width.equalTo(avatarStackView).priority(.high)
            make.width.lessThanOrEqualTo(avatarViewportWidth)
            make.height.equalTo(joinCallAvatarSize)
        }
        avatarStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(joinCallAvatarSize)
        }
        divider.snp.makeConstraints { make in
            make.top.equalTo(avatarScrollView.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        joinButton.snp.makeConstraints { make in
            make.top.equalTo(divider.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(48)
        }
    }

    private func setupViewStyle() {
        // 对齐 Android CardView：elevation 4dp 阴影 + 12 圆角
        // card 负责阴影（masksToBounds = false），cardContent 负责圆角裁剪内容
        card.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        card.layer.cornerRadius = joinCallCardCornerRadius
        card.layer.masksToBounds = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius = 4
        card.layer.shadowOffset = CGSize(width: 0, height: 2)

        cardContent.layer.cornerRadius = joinCallCardCornerRadius
        cardContent.layer.masksToBounds = true

        callIconImageView.contentMode = .scaleAspectFit
        callIconImageView.tintColor = TUIChatKitTheme.colors.buttonColorPrimaryDefault

        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textColor = TUIChatKitTheme.colors.textColorPrimary

        chevronView.strokeColor = TUIChatKitTheme.colors.textColorSecondary

        expandedContent.clipsToBounds = true

        avatarScrollView.showsHorizontalScrollIndicator = false
        avatarScrollView.alwaysBounceHorizontal = false
        avatarStackView.axis = .horizontal
        avatarStackView.spacing = joinCallAvatarSpacing
        avatarStackView.alignment = .center

        divider.backgroundColor = TUIChatKitTheme.colors.strokeColorSecondary

        joinButton.setTitleColor(TUIChatKitTheme.colors.textColorPrimary, for: .normal)
        joinButton.titleLabel?.font = .systemFont(ofSize: 16)
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleHeaderTap))
        headerRow.addGestureRecognizer(tap)
        joinButton.addTarget(self, action: #selector(handleJoinTap), for: .touchUpInside)
    }

    // MARK: - Bind

    func bind(state: JoinCallBannerState?) {
        guard let state = state else {
            boundCallID = nil
            setExpanded(false, animated: false)
            updateAvatars(users: [])
            currentJoinCallID = nil
            return
        }
        let isNewCall = state.callID != boundCallID
        if isNewCall {
            boundCallID = state.callID
            setExpanded(false, animated: false)
        }

        callIconImageView.image = callIcon(for: state.mediaType)
        hintLabel.text = String(format: LocalizedChatString("MessageListJoinGroupCallUsers"), state.users.count)
        updateAvatars(users: state.users)

        joinButton.setTitle(LocalizedChatString("MessageListJoinGroupCall"), for: .normal)
        joinButton.isHidden = !state.shouldShowJoinButton
        divider.isHidden = !state.shouldShowJoinButton
        currentJoinCallID = state.callID
    }

    private var currentJoinCallID: String?

    private func callIcon(for mediaType: String) -> UIImage? {
        let lowercased = mediaType.lowercased()
        let iconName = (lowercased.contains("audio") || lowercased.contains("voice"))
            ? "message_call_audio"
            : "message_call_video"
        return AtomicXChatResources.image(named: iconName)?.withRenderingMode(.alwaysTemplate)
    }

    private func updateAvatars(users: [JoinCallBannerUser]) {
        avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for user in users {
            let avatar = ChatAvatarView(cornerRadius: joinCallAvatarSize / 2, fontSize: 20)
            avatar.snp.makeConstraints { make in
                make.width.height.equalTo(joinCallAvatarSize)
            }
            avatar.configure(avatarURL: user.avatarURL, fallbackName: user.displayName)
            avatarStackView.addArrangedSubview(avatar)
        }
    }

    // MARK: - Actions

    @objc private func handleHeaderTap() {
        setExpanded(!isExpanded, animated: true)
    }

    @objc private func handleJoinTap() {
        guard let callID = currentJoinCallID, !callID.isEmpty else { return }
        ChatCallEventPublisher.publishStartJoin(callID: callID)
    }

    // MARK: - Expand / Collapse

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        guard isExpanded != expanded || !animated else { return }
        isExpanded = expanded
        chevronView.setExpanded(expanded, animated: animated)

        let applyState = {
            if expanded {
                self.expandedHeightConstraint?.deactivate()
            } else {
                self.expandedHeightConstraint?.activate()
            }
        }
        guard animated, window != nil else {
            applyState()
            expandedContent.alpha = expanded ? 1 : 0
            superview?.layoutIfNeeded()
            return
        }
        expandedContent.alpha = expanded ? 0 : 1
        UIView.animate(withDuration: joinCallExpandDuration, delay: 0, options: .curveEaseOut) {
            applyState()
            self.expandedContent.alpha = expanded ? 1 : 0
            self.superview?.layoutIfNeeded()
        }
    }
}

// MARK: - Chevron（对齐 Android ChevronView）

private final class JoinCallChevronView: UIView {
    var strokeColor: UIColor = .gray {
        didSet { shapeLayer.strokeColor = strokeColor.cgColor }
    }

    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let height = bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: width * 0.25, y: height * 0.38))
        path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.62))
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.38))
        shapeLayer.path = path.cgPath
        shapeLayer.frame = bounds
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        let rotation: CGFloat = expanded ? .pi : 0
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
                self.transform = CGAffineTransform(rotationAngle: rotation)
            }
        } else {
            transform = CGAffineTransform(rotationAngle: rotation)
        }
    }
}
