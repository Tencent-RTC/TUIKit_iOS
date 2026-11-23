import AtomicXCore
import Combine
import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeSeatUserPanel: BottomSheetView {
    var onConfirm:
        ((_ title: String, _ message: String, _ confirmTitle: String, _ action: @escaping () -> Void) -> Void)?

    private enum Mode {
        case onMic
        case pending
    }

    private let store: VoiceLoungeSeatStore
    private var liveID: String { store.liveID }
    private var coGuest: VoiceLoungeCoGuestStore { store.coGuest }
    private var muteCache: VoiceLoungeMuteCache { store.muteCache }

    private let profileCard = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = LiveText.voiceLounge(.action, tone: .primary)
    private let badgeStack = UIStackView()
    private let adminBadge = BadgeLabel()
    private let mutedBadge = BadgeLabel()
    private let subtitleLabel = LiveText.voiceLounge(.caption, tone: .tertiary)

    private let cardStack = UIStackView()
    private let togglesCard = UIView()
    private let muteRow = ToggleRow(glyph: .mic, title: .muteRowTitle)
    private let rowDivider = UIView()
    private let adminRow = ToggleRow(glyph: .crown, title: .adminSet)
    private let cohostDivider = UIView()
    private let cohostRow = ToggleRow(glyph: .star, title: .cohostSet)
    private let inviteCard = UIView()
    private let inviteRow = ActionRow(glyph: .invite)
    private let leaveCard = UIView()
    private let leaveRow = ActionRow(glyph: .leave, tint: PanelStyle.destructiveTint)

    private var mode: Mode = .onMic
    private var currentUserID = ""
    private var currentSeat: VoiceLoungeSeat?
    private var isMuteRequestInFlight = false
    private var pendingAdmin: Bool?
    private var pendingCohost: Bool?
    private var togglesHeight: Constraint?
    private var cancellables = Set<AnyCancellable>()

    override var sheetHeight: CGFloat {
        let cards = visibleCards.map { cardHeight($0) }
        let content = cards.reduce(0) { $0 + PanelStyle.cardSpacing + $1 }
        return PanelStyle.profileTop + PanelStyle.profileHeight + content + PanelStyle.bottomPadding
            + safeAreaInsets.bottom
    }

    init(store: VoiceLoungeSeatStore) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(seat: VoiceLoungeSeat) {
        guard !seat.userID.isEmpty else { return }
        switch seat.state {
        case .occupied: mode = .onMic
        case .faded: mode = .pending
        case .empty, .locked: return
        }
        currentUserID = seat.userID
        isMuteRequestInFlight = false
        pendingAdmin = nil
        pendingCohost = nil
        guard render() else { return }
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(
            with: URL(string: seat.avatarURL),
            placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
        present()
    }

    override func sheetWillPresent() {
        cancellables.removeAll()
        store.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        coGuest.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
    }

    override func sheetDidDismiss() {
        cancellables.removeAll()
        currentSeat = nil
        currentUserID = ""
    }

    private var visibleCards: [UIView] { cardStack.arrangedSubviews.filter { !$0.isHidden } }

    private func cardHeight(_ card: UIView) -> CGFloat {
        card === togglesCard ? PanelStyle.rowHeight * CGFloat(toggleRowCount) : PanelStyle.rowHeight
    }

    private var toggleRowCount: Int { cohostRow.isHidden ? 2 : 3 }

    private func setupViews() {
        contentView.addSubview(profileCard)
        profileCard.addSubview(avatarView)
        profileCard.addSubview(nameLabel)
        profileCard.addSubview(badgeStack)
        badgeStack.addArrangedSubview(mutedBadge)
        badgeStack.addArrangedSubview(adminBadge)
        profileCard.addSubview(subtitleLabel)

        contentView.addSubview(cardStack)
        [togglesCard, inviteCard, leaveCard].forEach(cardStack.addArrangedSubview)
        [muteRow, rowDivider, adminRow, cohostDivider, cohostRow].forEach(togglesCard.addSubview)
        inviteCard.addSubview(inviteRow)
        leaveCard.addSubview(leaveRow)
    }

    private func setupConstraints() {
        profileCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(PanelStyle.horizontalInset)
            make.top.equalToSuperview().offset(PanelStyle.profileTop)
            make.height.equalTo(PanelStyle.profileHeight)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(PanelStyle.avatarSize)
        }
        badgeStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        badgeStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeStack.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.top.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(badgeStack.snp.leading).offset(-8)
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(badgeStack.snp.leading).offset(-8)
        }
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cardStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(PanelStyle.horizontalInset)
            make.top.equalTo(profileCard.snp.bottom).offset(PanelStyle.cardSpacing)
        }
        togglesCard.snp.makeConstraints { make in
            togglesHeight = make.height.equalTo(PanelStyle.rowHeight * 2).constraint
        }
        muteRow.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(PanelStyle.rowHeight)
        }
        rowDivider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(PanelStyle.rowInset)
            make.top.equalTo(muteRow.snp.bottom)
            make.height.equalTo(0.5)
        }
        adminRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(muteRow.snp.bottom)
            make.height.equalTo(PanelStyle.rowHeight)
        }
        cohostDivider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(PanelStyle.rowInset)
            make.top.equalTo(adminRow.snp.bottom)
            make.height.equalTo(0.5)
        }
        cohostRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(adminRow.snp.bottom)
            make.height.equalTo(PanelStyle.rowHeight)
        }
        [(inviteCard, inviteRow), (leaveCard, leaveRow)].forEach { card, row in
            card.snp.makeConstraints { make in make.height.equalTo(PanelStyle.rowHeight) }
            row.snp.makeConstraints { make in make.edges.equalToSuperview() }
        }
    }

    private func setupStyles() {
        sheetTitle = LiveKitResources.localizedString("tuilivekit.voiceroom.seat.sheet_title")
        profileCard.backgroundColor = VoiceLoungeColor.overlayHair
        profileCard.layer.cornerRadius = PanelStyle.cardRadius
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = PanelStyle.avatarSize / 2
        avatarView.backgroundColor = VoiceLoungeColor.overlaySoft
        badgeStack.axis = .horizontal
        badgeStack.spacing = 6
        badgeStack.alignment = .center
        adminBadge.text = .adminBadge
        mutedBadge.text = .mutedBadge
        mutedBadge.apply(tint: PanelStyle.destructiveTint)
        cardStack.axis = .vertical
        cardStack.spacing = PanelStyle.cardSpacing
        [togglesCard, inviteCard, leaveCard].forEach { card in
            card.backgroundColor = VoiceLoungeColor.overlayHair
            card.layer.cornerRadius = PanelStyle.cardRadius
            card.clipsToBounds = true
        }
        [rowDivider, cohostDivider].forEach { $0.backgroundColor = UIColor.white.withAlphaComponent(0.08) }
    }

    private func setupBindings() {
        muteRow.onToggle = { [weak self] isOn in self?.handleMuteToggle(isOn) }
        adminRow.onToggle = { [weak self] isOn in self?.handleAdmin(isOn) }
        cohostRow.onToggle = { [weak self] isOn in self?.handleCohost(isOn) }
        inviteRow.onTap = { [weak self] in self?.handleInvite() }
        leaveRow.onTap = { [weak self] in self?.handleKick() }
    }

    @discardableResult private func render() -> Bool {
        let userID = currentUserID
        let expected: VoiceLoungeSeat.State = mode == .onMic ? .occupied : .faded
        guard !userID.isEmpty, let seat = store.seats.first(where: { $0.userID == userID && $0.state == expected })
        else {
            if !isHidden { dismiss() }
            return false
        }
        currentSeat = seat
        nameLabel.text = seat.name
        adminBadge.apply(tint: store.skin.mid)
        switch mode {
        case .onMic:
            subtitleLabel.text = .seatMeta(seat.index, .statusOnMic)
            adminBadge.isHidden = !seat.isAdmin
            mutedBadge.isHidden = !seat.isMuted
            if !isMuteRequestInFlight { muteRow.setOn(seat.isMuted) }
            if pendingAdmin == seat.isAdmin { pendingAdmin = nil }
            if pendingCohost == (seat.role == .cohost) { pendingCohost = nil }
            adminRow.setOn(pendingAdmin ?? seat.isAdmin)
            cohostRow.setOn(pendingCohost ?? (seat.role == .cohost))
            togglesCard.isHidden = false
            cohostRow.isHidden = store.layout != .twoV8
            cohostDivider.isHidden = cohostRow.isHidden
            togglesHeight?.update(offset: PanelStyle.rowHeight * CGFloat(toggleRowCount))
            inviteCard.isHidden = true
            leaveCard.isHidden = false
            leaveRow.title = .kickOffSeat
        case .pending:
            let applying = isApplicant(userID)
            subtitleLabel.text = .seatMeta(seat.index, .statusPending)
            adminBadge.isHidden = true
            mutedBadge.isHidden = true
            inviteRow.title = applying ? .acceptApply : .cancelInvite
            togglesCard.isHidden = true
            inviteCard.isHidden = false
            leaveCard.isHidden = !applying
            leaveRow.title = .rejectApply
        }
        badgeStack.isHidden = adminBadge.isHidden && mutedBadge.isHidden
        updateSheetHeight(animated: !isHidden)
        return true
    }

    private func handleMuteToggle(_ isOn: Bool) {
        let userID = currentUserID
        guard !userID.isEmpty else { return }
        let seatList = LiveSeatStore.create(liveID: liveID).state.value.seatList
        guard let user = seatList.first(where: { $0.userInfo.userID == userID })?.userInfo else { return }
        isMuteRequestInFlight = true
        if isOn {
            performSeatAction(
                revertTo: false, action: { $0.closeRemoteMicrophone(userID: userID, completion: $1) },
                onSuccess: { [weak self] in self?.muteCache.set(true, for: userID) })
        } else {
            let finish: () -> Void = { [weak self] in
                self?.muteCache.set(false, for: userID)
                self?.coGuest.requestOpenMicrophone(userID: userID)
            }
            if user.allowOpenMicrophone {
                isMuteRequestInFlight = false
                finish()
            } else {
                performSeatAction(
                    revertTo: true,
                    action: { $0.openRemoteMicrophone(userID: userID, policy: .unlockOnly, completion: $1) },
                    onSuccess: finish)
            }
        }
    }

    private func handleAdmin(_ isOn: Bool) {
        guard let seat = currentSeat, mode == .onMic else { return }
        let userID = seat.userID
        let audienceStore = LiveAudienceStore.create(liveID: liveID)
        pendingAdmin = isOn
        let completion = Self.completion { [weak self] result in
            guard let self, self.currentUserID == userID else { return }
            if case .failure = result { self.pendingAdmin = nil }
            self.render()
        }
        if isOn {
            audienceStore.setAdministrator(userID: userID, completion: completion)
        } else {
            audienceStore.revokeAdministrator(userID: userID, completion: completion)
        }
    }

    private func handleCohost(_ isOn: Bool) {
        guard let seat = currentSeat, mode == .onMic, store.layout == .twoV8 else { return }
        let userID = seat.userID
        let seatList = LiveSeatStore.create(liveID: liveID).state.value.seatList
        if !isOn {
            let freeIndex = seatList.filter { $0.index >= PanelStyle.firstGuestIndex && $0.userInfo.userID.isEmpty }
                .filter { !$0.isLocked }.map(\.index).min()
            guard let freeIndex else {
                cohostRow.setOn(true)
                LiveToast.show(.cohostNoFreeSeat)
                return
            }
            moveUser(userID, to: freeIndex, policy: .abortWhenOccupied)
            return
        }
        let cohostIndex = PanelStyle.cohostIndex
        let occupantID = seatList.first { $0.index == cohostIndex }?.userInfo.userID ?? ""
        guard !occupantID.isEmpty, occupantID != userID else {
            moveUser(userID, to: cohostIndex, policy: .abortWhenOccupied)
            return
        }
        let occupantName = store.seats.first { $0.index == cohostIndex }?.name ?? occupantID
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.onConfirm?(.cohostReplaceTitle, .cohostReplaceMessage(occupantName), .cohostReplaceConfirm) {
                [weak self] in self?.moveUser(userID, to: cohostIndex, policy: .swapPosition)
            }
        }
    }

    private func moveUser(_ userID: String, to index: Int, policy: MoveSeatPolicy) {
        pendingCohost = index == PanelStyle.cohostIndex
        let completion = Self.completion { [weak self] result in
            guard let self, self.currentUserID == userID else { return }
            if case .failure = result { self.pendingCohost = nil }
            self.render()
        }
        LiveSeatStore.create(liveID: liveID).moveUserToSeat(
            userID: userID, targetIndex: index, policy: policy, completion: completion)
    }

    private func isApplicant(_ userID: String) -> Bool { coGuest.applicants.contains { $0.userID == userID } }

    private func handleInvite() {
        guard let seat = currentSeat, mode == .pending else { return }
        if isApplicant(seat.userID) {
            coGuest.accept(userID: seat.userID)
        } else {
            coGuest.cancelInvitation(userID: seat.userID)
        }
        dismiss()
    }

    private func handleKick() {
        let userID = currentUserID
        guard !userID.isEmpty else { return }
        if mode == .pending {
            guard isApplicant(userID) else { return }
            coGuest.reject(userID: userID)
            dismiss()
            return
        }
        dismiss()
        let store = LiveSeatStore.create(liveID: liveID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            store.kickUserOutOfSeat(userID: userID, completion: Self.completion())
        }
    }

    private func performSeatAction(
        revertTo: Bool? = nil, action: (LiveSeatStore, @escaping CompletionClosure) -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        let completion = Self.completion { [weak self] result in
            self?.isMuteRequestInFlight = false
            switch result {
            case .success: onSuccess?()
            case .failure: if let revertTo { self?.muteRow.setOn(revertTo) }
            }
        }
        action(LiveSeatStore.create(liveID: liveID), completion)
    }

    private static func completion(onFinish: ((Result<Void, ErrorInfo>) -> Void)? = nil) -> CompletionClosure {
        { result in
            Task { @MainActor in
                if case .failure(let error) = result { LiveToast.show(VoiceLoungeErrorText.coGuest(error)) }
                onFinish?(result)
            }
        }
    }
}

private enum PanelStyle {
    static let horizontalInset: CGFloat = 16
    static let profileTop: CGFloat = 62
    static let profileHeight: CGFloat = 80
    static let cardSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let avatarSize: CGFloat = 48
    static let rowHeight: CGFloat = 56
    static let rowInset: CGFloat = 16
    static let glyphSize: CGFloat = 22
    static let bottomPadding: CGFloat = 24
    static let cohostIndex = 1
    static let firstGuestIndex = 2
    static let destructiveTint = UIColor(red: 1.0, green: 0.36, blue: 0.42, alpha: 1)
}

private enum PanelGlyph { case mic, crown, leave, star, invite }

private final class GlyphView: UIView {
    var strokeColor: UIColor = .white { didSet { shapeLayer.strokeColor = strokeColor.cgColor } }
    private let glyph: PanelGlyph
    private let shapeLayer = CAShapeLayer()

    init(glyph: PanelGlyph) {
        self.glyph = glyph
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = 1.6
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        let scale = min(bounds.width, bounds.height) / 24
        let path = Self.path(for: glyph)
        path.apply(CGAffineTransform(scaleX: scale, y: scale))
        shapeLayer.path = path.cgPath
    }

    private static func path(for glyph: PanelGlyph) -> UIBezierPath {
        let path = UIBezierPath()
        switch glyph {
        case .mic:
            path.append(UIBezierPath(roundedRect: CGRect(x: 9, y: 3.5, width: 6, height: 11), cornerRadius: 3))
            let arc = UIBezierPath(
                arcCenter: CGPoint(x: 12, y: 12), radius: 5.2, startAngle: 0, endAngle: .pi, clockwise: true)
            path.append(arc)
            path.move(to: CGPoint(x: 12, y: 17.2))
            path.addLine(to: CGPoint(x: 12, y: 20.5))
            path.move(to: CGPoint(x: 9, y: 20.5))
            path.addLine(to: CGPoint(x: 15, y: 20.5))
        case .crown:
            path.move(to: CGPoint(x: 4.5, y: 17.5))
            path.addLine(to: CGPoint(x: 19.5, y: 17.5))
            path.move(to: CGPoint(x: 4.5, y: 17.5))
            path.addLine(to: CGPoint(x: 3.5, y: 7))
            path.addLine(to: CGPoint(x: 8, y: 11))
            path.addLine(to: CGPoint(x: 12, y: 5.5))
            path.addLine(to: CGPoint(x: 16, y: 11))
            path.addLine(to: CGPoint(x: 20.5, y: 7))
            path.addLine(to: CGPoint(x: 19.5, y: 17.5))
        case .leave:
            path.move(to: CGPoint(x: 12, y: 4))
            path.addLine(to: CGPoint(x: 12, y: 15))
            path.move(to: CGPoint(x: 7.5, y: 10.5))
            path.addLine(to: CGPoint(x: 12, y: 15))
            path.addLine(to: CGPoint(x: 16.5, y: 10.5))
            path.move(to: CGPoint(x: 5, y: 19.5))
            path.addLine(to: CGPoint(x: 19, y: 19.5))
        case .star:
            let center = CGPoint(x: 12, y: 12.6)
            for point in 0..<10 {
                let radius: CGFloat = point.isMultiple(of: 2) ? 8.6 : 3.9
                let angle = -CGFloat.pi / 2 + CGFloat(point) * .pi / 5
                let vertex = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if point == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
            }
            path.close()
        case .invite:
            path.append(UIBezierPath(ovalIn: CGRect(x: 6.5, y: 4.5, width: 7, height: 7)))
            path.move(to: CGPoint(x: 3.5, y: 19.5))
            path.addQuadCurve(to: CGPoint(x: 16.5, y: 19.5), controlPoint: CGPoint(x: 10, y: 11))
            path.move(to: CGPoint(x: 19.5, y: 8))
            path.addLine(to: CGPoint(x: 19.5, y: 14))
            path.move(to: CGPoint(x: 16.5, y: 11))
            path.addLine(to: CGPoint(x: 22.5, y: 11))
        }
        return path
    }
}

private final class BadgeLabel: UILabel {
    private static let insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 11, weight: .medium)
        layer.cornerRadius = 4
        layer.borderWidth = 0.5
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func apply(tint: UIColor) {
        textColor = tint
        backgroundColor = tint.withAlphaComponent(0.16)
        layer.borderColor = tint.withAlphaComponent(0.5).cgColor
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + Self.insets.left + Self.insets.right,
            height: size.height + Self.insets.top + Self.insets.bottom)
    }

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: Self.insets)) }
}

private final class ActionRow: UIControl {
    var onTap: (() -> Void)?
    var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }

    private let iconView: GlyphView
    private let titleLabel = UILabel()

    init(glyph: PanelGlyph, tint: UIColor = UIColor.white.withAlphaComponent(0.85)) {
        iconView = GlyphView(glyph: glyph)
        super.init(frame: .zero)
        iconView.strokeColor = tint
        addSubview(iconView)
        titleLabel.font = .systemFont(ofSize: 16, weight: tint == PanelStyle.destructiveTint ? .medium : .regular)
        titleLabel.textColor = tint
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(PanelStyle.rowInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(PanelStyle.glyphSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().inset(PanelStyle.rowInset)
        }
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.6 : 1 } }

    @objc private func handleTap() { onTap?() }
}

private final class ToggleRow: UIView {
    var onToggle: ((Bool) -> Void)?

    private let iconView: GlyphView
    private let titleLabel = UILabel()
    private let toggleSwitch = UISwitch()

    init(glyph: PanelGlyph, title: String) {
        iconView = GlyphView(glyph: glyph)
        super.init(frame: .zero)
        iconView.strokeColor = UIColor.white.withAlphaComponent(0.85)
        addSubview(iconView)
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        addSubview(titleLabel)
        toggleSwitch.onTintColor = UIColor(red: 0.46, green: 0.78, blue: 1, alpha: 1)
        addSubview(toggleSwitch)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(toggleSwitch.snp.leading).offset(-10)
        }
        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        toggleSwitch.addTarget(self, action: #selector(handleChange), for: .valueChanged)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setOn(_ isOn: Bool) { toggleSwitch.setOn(isOn, animated: false) }

    @objc private func handleChange() { onToggle?(toggleSwitch.isOn) }
}

private extension String {
    static var muteRowTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.disable_mic") }
    static var adminSet: String { LiveKitResources.localizedString("tuilivekit.voiceroom.admin.set") }
    static var cohostSet: String { LiveKitResources.localizedString("tuilivekit.voiceroom.cohost.set") }
    static var cohostNoFreeSeat: String { LiveKitResources.localizedString("tuilivekit.voiceroom.cohost.no_free_seat") }
    static var cohostReplaceTitle: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.cohost.replace_title")
    }
    static func cohostReplaceMessage(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.cohost.replace_message", args)
    }
    static var cohostReplaceConfirm: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.cohost.replace_confirm")
    }
    static var cancelInvite: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.cancel_invite") }
    static var acceptApply: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connect") }
    static var rejectApply: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.reject_apply") }
    static var adminBadge: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.badge_admin") }
    static var mutedBadge: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.badge_muted") }
    static var statusOnMic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.status_on_mic") }
    static var statusPending: String { LiveKitResources.localizedString("tuilivekit.voiceroom.seat.status_pending") }
    static func seatMeta(_ index: Int, _ status: String) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.seat.seat_meta", index, status)
    }
    static var kickOffSeat: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.kick") }
}
