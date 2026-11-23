import AtomicXCore
import Combine
import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeCoGuestManagePanel: BottomSheetView {
    private enum Section: Int, CaseIterable { case connected, applicants }

    private let store: VoiceLoungeSeatStore
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var connected: [SeatUserInfo] = []
    private var applicants: [LiveUserInfo] = []
    private var isSeatFull = false
    private var skin = VoiceLoungeSkin.defaultSkin
    private var cancellables = Set<AnyCancellable>()

    private var liveID: String { store.liveID }
    private var coGuest: VoiceLoungeCoGuestStore { store.coGuest }

    private static let tableTop: CGFloat = 66
    private static let tableBottomInset: CGFloat = 12
    private static let maxContentHeight: CGFloat = 560

    override var sheetHeight: CGFloat {
        let content = Section.allCases.reduce(CGFloat(0)) { total, section in
            let header = MicSectionHeader.height + (section == .connected ? 0 : MicSectionHeader.cardSpacing)
            let rowHeight = isEmpty(section) ? MicEmptyCell.height : MicUserCell.height
            return total + header + rowHeight * CGFloat(rowCount(section))
        }
        let height = Self.tableTop + 4 + content + Self.tableBottomInset
        return min(height, Self.maxContentHeight) + (window?.safeAreaInsets.bottom ?? 0)
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

    func show(skin: VoiceLoungeSkin) {
        self.skin = skin
        reloadData()
        present()
    }

    override func sheetWillPresent() {
        cancellables.removeAll()
        coGuest.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        store.changes.sink { [weak self] in self?.render() }.store(in: &cancellables)
        render()
    }

    override func sheetDidDismiss() { cancellables.removeAll() }

    private func setupViews() { contentView.addSubview(tableView) }

    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(Self.tableTop)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func setupStyles() {
        sheetTitle = .settingsTitle
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: Self.tableBottomInset, right: 0)
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
                if case .failure(let error) = result { LiveToast.show(VoiceLoungeErrorText.coGuest(error)) }
            }
        }
    }

    private func reloadData() {
        connected = coGuest.connectedUsers
        applicants = coGuest.applicants
        isSeatFull = store.hasNoFreeGuestSeat
    }

    private func render() {
        reloadData()
        tableView.reloadData()
        updateSheetHeight(animated: true)
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
        guard let section = Section(rawValue: section) else { return 0 }
        return rowCount(section)
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
            let button: MicUserCell.ButtonSpec =
                isSeatFull
                ? .init(title: .full, showsMic: false, style: .disabled)
                : .init(title: .connect, showsMic: true, style: .tinted)
            cell.bind(
                name: user.userName.isEmpty ? userID : user.userName, avatarURL: user.avatarURL, button: button,
                isEnabled: !isSeatFull && !coGuest.pendingUserIDs.contains(userID), isLast: isLast, skin: skin)
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
        enum Style { case tinted, destructive, disabled }
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
        case .disabled:
            button.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        }
        micView.isHidden = !spec.showsMic
        titleLabel.text = spec.title
        titleLabel.textColor = spec.style == .disabled ? UIColor.white.withAlphaComponent(0.4) : .white
        button.isEnabled = isEnabled
        button.alpha = isEnabled || spec.style == .disabled ? 1 : 0.5
    }
}

private extension String {
    static func appliedTitle(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.comic.applied_title", args)
    }
    static var connectedEmpty: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connected_empty") }
    static var applicantsEmpty: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.comic.applicants_empty")
    }
    static var connect: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connect") }
    static var full: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.seat_full") }
    static var connectedTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connected_title") }
    static var hangUp: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.hang_up") }
    static var settingsTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.settings_title") }
}
