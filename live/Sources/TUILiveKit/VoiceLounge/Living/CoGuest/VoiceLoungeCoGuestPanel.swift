import AtomicXCore
import Combine
import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeCoGuestPanel: BottomSheetView {
    private enum Mode: Equatable {
        case idle
        case applying
        case onSeat(isMicOn: Bool)
    }

    private let liveID: String
    private let coGuest: VoiceLoungeCoGuestStore

    private let avatarRing = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = LiveText.voiceLounge(.action, tone: .primary, alignment: .center)
    private let buttonRow = UIStackView()
    private let primaryButton = MicActionButton()
    private let secondaryButton = MicActionButton()
    private var mode: Mode = .idle
    private var preferredSeatIndex = -1
    private var selfSeatUser: SeatUserInfo?
    private var skin = VoiceLoungeSkin.defaultSkin
    private var cancellables = Set<AnyCancellable>()

    override var sheetHeight: CGFloat { 300 }

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

    func show(preferredSeatIndex: Int?, skin: VoiceLoungeSkin) {
        self.preferredSeatIndex = preferredSeatIndex ?? -1
        self.skin = skin
        avatarRing.layer.borderColor = skin.mid.withAlphaComponent(0.55).cgColor
        present()
    }

    private func setupViews() {
        contentView.addSubview(avatarRing)
        avatarRing.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        buttonRow.addArrangedSubview(primaryButton)
        buttonRow.addArrangedSubview(secondaryButton)
        contentView.addSubview(buttonRow)
    }

    private func setupConstraints() {
        avatarRing.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(36)
            make.size.equalTo(84)
        }
        avatarView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(76)
        }
        nameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarRing.snp.bottom).offset(14)
            make.leading.greaterThanOrEqualToSuperview().offset(20)
        }
        buttonRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(nameLabel.snp.bottom).offset(32)
            make.height.equalTo(56)
        }
    }

    private func setupStyles() {
        avatarRing.layer.borderWidth = 2
        avatarRing.layer.cornerRadius = 42
        avatarRing.backgroundColor = UIColor(red: 0.16, green: 0.13, blue: 0.24, alpha: 1)
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 38
        nameLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        buttonRow.axis = .horizontal
        buttonRow.spacing = 20
        buttonRow.distribution = .fillEqually
    }

    private func setupBindings() {
        primaryButton.addTarget(self, action: #selector(tapPrimary), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(tapSecondary), for: .touchUpInside)
    }

    override func sheetWillPresent() {
        let profile = LoginStore.shared.state.value.loginUserInfo
        let selfID = profile?.userID ?? ""
        let nickname = profile?.nickname ?? ""
        nameLabel.text = nickname.isEmpty ? selfID : nickname
        avatarView.kf.setImage(
            with: URL(string: profile?.avatarURL ?? ""),
            placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))

        cancellables.removeAll()
        selfSeatUser = nil
        LiveSeatStore.create(liveID: liveID).state.subscribe().receive(on: DispatchQueue.main).sink {
            [weak self] state in
            self?.selfSeatUser = state.seatList.first { $0.userInfo.userID == selfID }?.userInfo
            self?.render()
        }.store(in: &cancellables)
        coGuest.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        render()
    }

    override func sheetDidDismiss() { cancellables.removeAll() }

    private var currentMode: Mode {
        switch coGuest.guestStatus {
        case .idle: return .idle
        case .applying: return .applying
        case .onSeat: return .onSeat(isMicOn: selfSeatUser?.microphoneStatus == .on)
        }
    }

    private func render() {
        mode = currentMode
        switch mode {
        case .idle:
            primaryButton.apply(title: .voiceApply, style: .filled(skin))
            secondaryButton.isHidden = true
        case .applying:
            primaryButton.apply(title: .cancelApply, style: .outlined)
            secondaryButton.isHidden = true
        case .onSeat(let isMicOn):
            primaryButton.apply(title: isMicOn ? .mute : .unmute, style: .outlined)
            secondaryButton.apply(title: .leaveSeat, style: .outlined)
            secondaryButton.isHidden = false
        }
    }

    private func toggleMute(_ user: SeatUserInfo?) {
        let store = LiveSeatStore.create(liveID: liveID)
        if user?.microphoneStatus == .on {
            store.muteMicrophone()
        } else if user?.allowOpenMicrophone == false {
            LiveToast.show(.microphoneLocked)
        } else {
            store.unmuteMicrophone(completion: nil)
        }
    }
}

extension VoiceLoungeCoGuestPanel {
    @objc private func tapPrimary() {
        let action: () -> Void
        switch mode {
        case .idle:
            let seatIndex = preferredSeatIndex
            action = { [coGuest] in coGuest.apply(seatIndex: seatIndex) }
        case .applying: action = { [coGuest] in coGuest.cancelApplication() }
        case .onSeat:
            let user = selfSeatUser
            action = { [weak self] in self?.toggleMute(user) }
        }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { action() }
    }

    @objc private func tapSecondary() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [coGuest] in coGuest.leaveSeat() }
    }
}

private final class MicActionButton: UIControl {
    enum Style {
        case filled(VoiceLoungeSkin)
        case outlined
    }

    private let gradientView = GradientView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        gradientView.isUserInteractionEnabled = false
        gradientView.layer.cornerRadius = 16
        gradientView.clipsToBounds = true
        addSubview(gradientView)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        gradientView.snp.makeConstraints { $0.edges.equalToSuperview() }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(8)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(title: String, style: Style) {
        titleLabel.text = title
        switch style {
        case .filled(let skin):
            gradientView.isHidden = false
            gradientView.colors = [skin.deep, skin.light]
            layer.borderWidth = 0
            layer.shadowColor = skin.mid.cgColor
            layer.shadowOpacity = 0.55
            layer.shadowRadius = 14
            layer.shadowOffset = CGSize(width: 0, height: 4)
        case .outlined:
            gradientView.isHidden = true
            layer.borderWidth = 1.5
            layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
            layer.shadowOpacity = 0
        }
    }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }
}

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    var colors: [UIColor] = [] { didSet { (layer as? CAGradientLayer)?.colors = colors.map(\.cgColor) } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as? CAGradientLayer
        gradient?.startPoint = CGPoint(x: 0, y: 0.5)
        gradient?.endPoint = CGPoint(x: 1, y: 0.5)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class VoiceLoungeCoGuestManagePanel: BottomSheetView {
    private enum Section: Int, CaseIterable { case connected, applicants }

    private let liveID: String
    private let coGuest: VoiceLoungeCoGuestStore
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var connected: [SeatUserInfo] = []
    private var applicants: [LiveUserInfo] = []
    private var skin = VoiceLoungeSkin.defaultSkin
    private var cancellables = Set<AnyCancellable>()

    override var sheetHeight: CGFloat { 520 }

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

    func show(skin: VoiceLoungeSkin) {
        self.skin = skin
        present()
    }

    override func sheetWillPresent() {
        cancellables.removeAll()
        coGuest.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        render()
    }

    override func sheetDidDismiss() { cancellables.removeAll() }

    private func setupViews() { contentView.addSubview(tableView) }

    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(66)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func setupStyles() {
        sheetTitle = .settingsTitle
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 16, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MicUserCell.self, forCellReuseIdentifier: MicUserCell.reuseIdentifier)
        tableView.register(MicEmptyCell.self, forCellReuseIdentifier: MicEmptyCell.reuseIdentifier)
        tableView.register(MicSectionHeader.self, forHeaderFooterViewReuseIdentifier: MicSectionHeader.reuseIdentifier)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
    }

    private func setupBindings() {}

    private func hangUp(userID: String) {
        LiveSeatStore.create(liveID: liveID).kickUserOutOfSeat(userID: userID) { result in
            Task { @MainActor in
                switch result {
                case .success: LiveToast.show(.kicked)
                case .failure(let error): LiveToast.show(VoiceLoungeErrorText.coGuest(error))
                }
            }
        }
    }

    private func render() {
        connected = coGuest.connectedUsers
        applicants = coGuest.applicants
        tableView.reloadData()
    }

    private func isEmpty(_ section: Section) -> Bool {
        switch section {
        case .connected: return connected.isEmpty
        case .applicants: return applicants.isEmpty
        }
    }

    private func rowCount(_ section: Section) -> Int {
        switch section {
        case .connected: return max(1, connected.count)
        case .applicants: return max(1, applicants.count)
        }
    }
}

extension VoiceLoungeCoGuestManagePanel: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section).map(rowCount) ?? 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return 0 }
        return isEmpty(section) ? MicEmptyCell.height : MicUserCell.height
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        MicSectionHeader.height + (section == 0 ? 0 : MicSectionHeader.cardSpacing)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = Section(rawValue: section),
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: MicSectionHeader.reuseIdentifier)
                as? MicSectionHeader
        else { return nil }
        switch section {
        case .connected: header.bind(title: .connectedTitle, showsDivider: !connected.isEmpty)
        case .applicants: header.bind(title: .appliedTitle("\(applicants.count)"), showsDivider: true)
        }
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        if isEmpty(section) {
            let cell = tableView.dequeueReusableCell(withIdentifier: MicEmptyCell.reuseIdentifier, for: indexPath)
            (cell as? MicEmptyCell)?.bind(text: section == .connected ? .connectedEmpty : .applicantsEmpty)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: MicUserCell.reuseIdentifier, for: indexPath)
        guard let cell = cell as? MicUserCell else { return cell }
        let isLast = indexPath.row == rowCount(section) - 1
        switch section {
        case .connected:
            let user = connected[indexPath.row]
            let userID = user.userID
            cell.bind(
                name: user.userName.isEmpty ? userID : user.userName, avatarURL: user.avatarURL,
                button: .init(title: .hangUp, showsMic: false, style: .destructive), isEnabled: true, isLast: isLast,
                skin: skin)
            cell.onTap = { [weak self] in self?.hangUp(userID: userID) }
        case .applicants:
            let user = applicants[indexPath.row]
            let userID = user.userID
            cell.bind(
                name: user.userName.isEmpty ? userID : user.userName, avatarURL: user.avatarURL,
                button: .init(title: .connect, showsMic: true, style: .tinted),
                isEnabled: !coGuest.pendingUserIDs.contains(userID), isLast: isLast, skin: skin)
            cell.onTap = { [weak self] in self?.coGuest.accept(userID: userID) }
        }
        return cell
    }
}

private enum MicCardStyle {
    static let inset: CGFloat = 16
    static let corner: CGFloat = 18
    static let hangUp = VoiceLoungeColor.rose
    static let topCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    static let bottomCorners: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    static func style(_ view: UIView, corners: CACornerMask) {
        view.backgroundColor = VoiceLoungeColor.card
        view.layer.cornerRadius = corners.isEmpty ? 0 : corner
        view.layer.maskedCorners = corners
    }
}

private final class MicSectionHeader: UITableViewHeaderFooterView {
    static let reuseIdentifier = "VoiceLoungeMicSectionHeader"
    static let height: CGFloat = 56
    static let cardSpacing: CGFloat = 14

    private let card = UIView()
    private let titleLabel = UILabel()
    private let divider = UIView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
        MicCardStyle.style(card, corners: MicCardStyle.topCorners)
        contentView.addSubview(card)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        card.addSubview(titleLabel)
        divider.backgroundColor = VoiceLoungeColor.overlaySoft
        card.addSubview(divider)

        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MicCardStyle.inset)
            make.bottom.equalToSuperview()
            make.height.equalTo(Self.height)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(18)
        }
        divider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(4)
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(title: String, showsDivider: Bool) {
        titleLabel.text = title
        divider.isHidden = !showsDivider
    }
}

private final class MicEmptyCell: UITableViewCell {
    static let reuseIdentifier = "VoiceLoungeMicEmptyCell"
    static let height: CGFloat = 118

    private let card = UIView()
    private let label = LiveText.voiceLounge(.body, tone: .tertiary, alignment: .center)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        MicCardStyle.style(card, corners: MicCardStyle.bottomCorners)
        contentView.addSubview(card)
        card.addSubview(label)
        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MicCardStyle.inset)
            make.top.bottom.equalToSuperview()
        }
        label.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(text: String) { label.text = text }
}

private final class MicUserCell: UITableViewCell {
    struct ButtonSpec {
        enum Style { case tinted, destructive }
        let title: String
        let showsMic: Bool
        let style: Style
    }

    static let reuseIdentifier = "VoiceLoungeMicUserCell"
    static let height: CGFloat = 72

    var onTap: (() -> Void)?

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let button = UIControl()
    private let micView = UIImageView(image: LiveKitResources.image(named: "livekit_coguest_mic"))
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(card)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarView.backgroundColor = VoiceLoungeColor.overlayBase
        card.addSubview(avatarView)

        nameLabel.font = .systemFont(ofSize: 17)
        nameLabel.textColor = LiveTheme.Color.text(.secondary)
        nameLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(nameLabel)

        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        card.addSubview(button)

        let content = UIStackView(arrangedSubviews: [micView, titleLabel])
        content.axis = .horizontal
        content.spacing = 4
        content.alignment = .center
        content.isUserInteractionEnabled = false
        micView.contentMode = .scaleAspectFit
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .white
        button.addSubview(content)

        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MicCardStyle.inset)
            make.top.bottom.equalToSuperview()
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(44)
        }
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }
        micView.snp.makeConstraints { $0.size.equalTo(14) }
        content.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(12)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(16)
            make.trailing.lessThanOrEqualTo(button.snp.leading).offset(-12)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(
        name: String, avatarURL: String, button spec: ButtonSpec, isEnabled: Bool, isLast: Bool, skin: VoiceLoungeSkin
    ) {
        MicCardStyle.style(card, corners: isLast ? MicCardStyle.bottomCorners : [])
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(
            with: URL(string: avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
        nameLabel.text = name
        switch spec.style {
        case .tinted:
            button.backgroundColor = skin.deep.withAlphaComponent(0.55)
            button.layer.borderColor = skin.mid.withAlphaComponent(0.8).cgColor
        case .destructive:
            button.backgroundColor = MicCardStyle.hangUp.withAlphaComponent(0.55)
            button.layer.borderColor = MicCardStyle.hangUp.withAlphaComponent(0.8).cgColor
        }
        micView.isHidden = !spec.showsMic
        titleLabel.text = spec.title
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? 1 : 0.5
    }
}

private extension String {
    static var voiceApply: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.voice_apply") }
    static var cancelApply: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.cancel_apply") }
    static var mute: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.mute") }
    static var unmute: String { LiveKitResources.localizedString("tuilivekit.voiceroom.living.unmute") }
    static var leaveSeat: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.leave_comic") }
    static var microphoneLocked: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.microphone_locked")
    }
    static func appliedTitle(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.applied_title", args)
    }
    static var connectedEmpty: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connected_empty") }
    static var applicantsEmpty: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.comic.applicants_empty")
    }
    static var connect: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connect") }
    static var connectedTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connected_title") }
    static var hangUp: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.hang_up") }
    static var kicked: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.kicked") }
    static var settingsTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.settings_title") }
}
