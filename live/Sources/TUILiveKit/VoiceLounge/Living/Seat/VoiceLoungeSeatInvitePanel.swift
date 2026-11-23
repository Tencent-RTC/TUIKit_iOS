import AtomicXCore
import Combine
import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeSeatInvitePanel: BottomSheetView {
    private let liveID: String
    private let coGuest: VoiceLoungeCoGuestStore

    private let profileCard = UIView()
    private let profileIconBackground = UIView()
    private let profileMicIcon = UIImageView()
    private let profileLockIcon = SeatLockIconView()
    private let profileTitle = LiveText.voiceLounge(.action, tone: .primary)
    private let profileMeta = LiveText.voiceLounge(.caption, tone: .tertiary)
    private let lockCard = UIView()
    private let lockLabel = LiveText.voiceLounge(.body, tone: .secondary)
    private let lockSwitch = UISwitch()
    private let card = UIView()
    private let cardTitle = LiveText.voiceLounge(.action, tone: .primary)
    private let divider = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = LiveText.voiceLounge(.body, tone: .tertiary, alignment: .center)

    private var seatIndex = -1
    private var audienceList: [LiveUserInfo] = []
    private var seatList: [SeatInfo] = []
    private var rows: [LiveUserInfo] = []
    private var pendingLock: Bool?
    private var tappedLocked = false
    private var skin = VoiceLoungeSkin.defaultSkin
    private var cancellables = Set<AnyCancellable>()

    override var sheetHeight: CGFloat {
        guard isLocked else { return InviteStyle.unlockedHeight }
        let bottomInset = window?.safeAreaInsets.bottom ?? 0
        return InviteStyle.contentTop + InviteStyle.profileHeight + InviteStyle.cardGap + InviteStyle.lockHeight
            + InviteStyle.lockedBottomPadding + bottomInset
    }

    init(liveID: String, coGuest: VoiceLoungeCoGuestStore) {
        self.liveID = liveID
        self.coGuest = coGuest
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        contentView.addSubview(profileCard)
        profileCard.addSubview(profileIconBackground)
        profileIconBackground.addSubview(profileMicIcon)
        profileIconBackground.addSubview(profileLockIcon)
        profileCard.addSubview(profileTitle)
        profileCard.addSubview(profileMeta)
        contentView.addSubview(lockCard)
        lockCard.addSubview(lockLabel)
        lockCard.addSubview(lockSwitch)
        contentView.addSubview(card)
        card.addSubview(cardTitle)
        card.addSubview(divider)
        card.addSubview(tableView)
        card.addSubview(emptyLabel)
    }

    private func setupConstraints() {
        profileCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(InviteStyle.horizontalInset)
            make.top.equalToSuperview().offset(InviteStyle.contentTop)
            make.height.equalTo(InviteStyle.profileHeight)
        }
        profileIconBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(InviteStyle.profileIconSize)
        }
        profileMicIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(26)
        }
        profileLockIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(26)
        }
        profileTitle.snp.makeConstraints { make in
            make.leading.equalTo(profileIconBackground.snp.trailing).offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            make.bottom.equalTo(profileCard.snp.centerY).offset(-2)
        }
        profileMeta.snp.makeConstraints { make in
            make.leading.equalTo(profileTitle)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            make.top.equalTo(profileCard.snp.centerY).offset(4)
        }
        lockCard.snp.makeConstraints { make in
            make.leading.trailing.equalTo(profileCard)
            make.top.equalTo(profileCard.snp.bottom).offset(InviteStyle.cardGap)
            make.height.equalTo(InviteStyle.lockHeight)
        }
        lockLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        lockSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        card.snp.makeConstraints { make in
            make.leading.trailing.equalTo(profileCard)
            make.top.equalTo(lockCard.snp.bottom).offset(InviteStyle.cardGap)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
        cardTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
        }
        divider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(cardTitle.snp.bottom).offset(12)
            make.height.equalTo(1)
        }
        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(divider.snp.bottom).offset(4)
        }
        emptyLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(divider.snp.bottom).offset(40)
        }
    }

    private func setupStyles() {
        sheetTitle = .sheetTitle
        lockLabel.text = .lockToggle
        [profileCard, lockCard, card].forEach { view in
            view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
            view.layer.cornerRadius = 16
            view.layer.borderWidth = 1
            view.layer.borderColor = VoiceLoungeColor.overlayHair.cgColor
        }
        profileIconBackground.backgroundColor = VoiceLoungeColor.overlaySoft
        profileIconBackground.layer.cornerRadius = InviteStyle.profileIconSize / 2
        profileMicIcon.image = LiveKitResources.image(named: "livekit_coguest_seat_mic")?.withRenderingMode(
            .alwaysTemplate)
        profileMicIcon.tintColor = InviteStyle.profileIconTint
        profileMicIcon.contentMode = .scaleAspectFit
        profileLockIcon.strokeColor = InviteStyle.profileIconTint
        profileTitle.font = .systemFont(ofSize: VoiceLoungeFont.size(17), weight: .semibold)
        divider.backgroundColor = VoiceLoungeColor.overlaySoft
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = InviteCell.height
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        tableView.dataSource = self
        tableView.register(InviteCell.self, forCellReuseIdentifier: InviteCell.reuseIdentifier)
        emptyLabel.numberOfLines = 0
    }

    private func setupBindings() { lockSwitch.addTarget(self, action: #selector(lockChanged), for: .valueChanged) }

    func show(seatIndex: Int, isLocked: Bool, skin: VoiceLoungeSkin) {
        self.seatIndex = seatIndex
        self.skin = skin
        tappedLocked = isLocked
        pendingLock = nil
        lockSwitch.onTintColor = skin.mid
        renderProfile(locked: isLocked)
        card.isHidden = isLocked
        present()
    }

    override func sheetWillPresent() { subscribe() }

    override func sheetDidDismiss() {
        cancellables.removeAll()
        audienceList = []
        seatList = []
        pendingLock = nil
    }

    private func subscribe() {
        cancellables.removeAll()
        let audienceStore = LiveAudienceStore.create(liveID: liveID)
        audienceStore.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] state in
            self?.audienceList = state.audienceList
            self?.render()
        }.store(in: &cancellables)
        let liveID = liveID
        audienceStore.fetchAudienceList { result in
            guard case .failure(let error) = result else { return }
            LiveKitLog.warn(
                "[VoiceLounge] refresh audience list failed liveID=\(liveID) code=\(error.code) message=\(error.message)"
            )
        }
        LiveSeatStore.create(liveID: liveID).state.subscribe().receive(on: DispatchQueue.main).sink {
            [weak self] state in self?.applySeatList(state.seatList)
        }.store(in: &cancellables)
        coGuest.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        render()
    }

    private func applySeatList(_ list: [SeatInfo]) {
        seatList = list
        if let seat = list.first(where: { $0.index == seatIndex }), !seat.userInfo.userID.isEmpty {
            dismiss()
            return
        }
        if pendingLock == sdkLocked { pendingLock = nil }
        render()
    }

    private var sdkLocked: Bool { seatList.first { $0.index == seatIndex }?.isLocked ?? tappedLocked }

    private var isLocked: Bool { pendingLock ?? sdkLocked }

    private var candidates: [LiveUserInfo] {
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let onSeatIDs = Set(seatList.map(\.userInfo.userID).filter { !$0.isEmpty })
        var seen = Set<String>()
        return audienceList.filter {
            !$0.userID.isEmpty && $0.userID != selfID && !onSeatIDs.contains($0.userID)
                && seen.insert($0.userID).inserted
        }
    }

    private func toggleLock(_ locked: Bool) {
        guard seatIndex >= 0 else { return }
        pendingLock = locked
        render()
        let store = LiveSeatStore.create(liveID: liveID)
        let completion: CompletionClosure = { [weak self] result in
            Task { @MainActor in
                guard case .failure(let error) = result else { return }
                LiveToast.show(VoiceLoungeErrorText.coGuest(error))
                self?.pendingLock = nil
                self?.render()
            }
        }
        if locked {
            store.lockSeat(seatIndex: seatIndex, completion: completion)
        } else {
            store.unlockSeat(seatIndex: seatIndex, completion: completion)
        }
    }

    private func render() {
        let audience = candidates
        let locked = isLocked
        lockSwitch.setOn(locked, animated: false)
        lockSwitch.isEnabled = pendingLock == nil
        renderProfile(locked: locked)
        cardTitle.text = .invitable("\(audience.count)")
        card.isHidden = locked
        rows = locked ? [] : audience
        emptyLabel.text = .inviteEmpty
        emptyLabel.isHidden = locked || !audience.isEmpty
        tableView.reloadData()
        updateSheetHeight(animated: true)
    }

    private func renderProfile(locked: Bool) {
        let status: String = locked ? .lockedSeat : .emptySeat
        profileMicIcon.isHidden = locked
        profileLockIcon.isHidden = !locked
        profileTitle.text = status
        profileMeta.text = .seatMeta(seatIndex, status)
    }

    private func toggleInvite(_ user: LiveUserInfo) {
        if isApplicant(user.userID) {
            coGuest.accept(userID: user.userID)
            dismiss()
        } else if coGuest.inviteeIDs.contains(user.userID) {
            coGuest.cancelInvitation(userID: user.userID)
        } else {
            coGuest.invite(userID: user.userID, seatIndex: seatIndex)
        }
    }

    private func isApplicant(_ userID: String) -> Bool { coGuest.applicants.contains { $0.userID == userID } }
}

extension VoiceLoungeSeatInvitePanel { @objc private func lockChanged() { toggleLock(lockSwitch.isOn) } }

extension VoiceLoungeSeatInvitePanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: InviteCell.reuseIdentifier, for: indexPath)
        guard let cell = cell as? InviteCell, indexPath.row < rows.count else { return cell }
        let user = rows[indexPath.row]
        cell.bind(
            user: user, isApplicant: isApplicant(user.userID), isInvited: coGuest.inviteeIDs.contains(user.userID),
            isPending: coGuest.pendingUserIDs.contains(user.userID), skin: skin)
        cell.onTap = { [weak self] in self?.toggleInvite(user) }
        return cell
    }
}

private final class InviteCell: UITableViewCell {
    static let reuseIdentifier = "VoiceLoungeInviteCell"
    static let height: CGFloat = 64

    var onTap: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = LiveText.voiceLounge(.body, tone: .secondary)
    private let button = UIButton(type: .custom)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 20
        avatarView.backgroundColor = VoiceLoungeColor.overlayBase
        contentView.addSubview(avatarView)

        nameLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(nameLabel)

        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        contentView.addSubview(button)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 76, height: 40))
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(button.snp.leading).offset(-12)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(user: LiveUserInfo, isApplicant: Bool, isInvited: Bool, isPending: Bool, skin: VoiceLoungeSkin) {
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(
            with: URL(string: user.avatarURL),
            placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
        nameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        let muted = isInvited && !isApplicant
        button.setTitle(isApplicant ? .connect : (isInvited ? .cancelInvite : .invite), for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(muted ? 0.7 : 0.9), for: .normal)
        button.backgroundColor = muted ? VoiceLoungeColor.overlaySoft : skin.mid.withAlphaComponent(0.35)
        button.layer.borderColor = (muted ? UIColor.white.withAlphaComponent(0.15) : skin.mid).cgColor
        button.isEnabled = !isPending
        button.alpha = isPending ? 0.5 : 1
    }
}

private extension String {
    static func invitable(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.seat.invitable", args)
    }
    static var cancelInvite: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.cancel_invite") }
    static var invite: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.invite") }
    static var connect: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connect") }
    static var inviteEmpty: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.invite_empty") }
    static var lockToggle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.lock_toggle") }
    static var sheetTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.sheet_title") }
    static var emptySeat: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.empty_seat") }
    static var lockedSeat: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.locked_seat") }
    static func seatMeta(_ index: Int, _ status: String) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.seat.seat_meta", index, status)
    }
}

private enum InviteStyle {
    static let horizontalInset: CGFloat = 16
    static let contentTop: CGFloat = 66
    static let profileHeight: CGFloat = 88
    static let profileIconSize: CGFloat = 52
    static let profileIconTint = UIColor.white.withAlphaComponent(0.8)
    static let cardGap: CGFloat = 12
    static let lockHeight: CGFloat = 56
    static let lockedBottomPadding: CGFloat = 28
    static let unlockedHeight: CGFloat = 520
}

private final class SeatLockIconView: UIView {
    var strokeColor: UIColor = .white { didSet { shapeLayer.strokeColor = strokeColor.cgColor } }

    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupStyles()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() { layer.addSublayer(shapeLayer) }

    private func setupStyles() {
        isUserInteractionEnabled = false
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = 1.8
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = bounds.width / 24
        let path = UIBezierPath(roundedRect: CGRect(x: 6, y: 11, width: 12, height: 9), cornerRadius: 2)
        let shackle = UIBezierPath()
        shackle.move(to: CGPoint(x: 8.5, y: 11))
        shackle.addLine(to: CGPoint(x: 8.5, y: 8))
        shackle.addArc(withCenter: CGPoint(x: 12, y: 8), radius: 3.5, startAngle: .pi, endAngle: 0, clockwise: true)
        shackle.addLine(to: CGPoint(x: 15.5, y: 11))
        path.append(shackle)
        path.apply(CGAffineTransform(scaleX: scale, y: scale))
        shapeLayer.frame = bounds
        shapeLayer.lineWidth = 1.8 * scale
        shapeLayer.path = path.cgPath
    }
}
