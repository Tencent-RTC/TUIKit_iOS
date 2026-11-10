import Kingfisher
import AtomicXCore
import Combine
import SnapKit
import UIKit

@MainActor
final class AudienceListPanel: BottomSheetView {
    override var sheetHeight: CGFloat { 422 }

    struct Item: Equatable {
        let id: String
        let name: String
        let avatarURL: String
        let level: Int
        let giftValue: String
    }

    private let audienceList = UITableView(frame: .zero, style: .plain)
    private var items: [Item] = []
    private var liveID = ""
    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func activate(liveID: String) {
        guard !liveID.isEmpty else {
            deactivate()
            return
        }
        deactivate()
        self.liveID = liveID
    }

    func deactivate() {
        cancellables.removeAll()
        liveID = ""
        guard !items.isEmpty else { return }
        items = []
        audienceList.reloadData()
    }

    func show() {
        cancellables.removeAll()
        guard !liveID.isEmpty else {
            present()
            return
        }
        let subscribedLiveID = liveID
        let audienceStore = LiveAudienceStore.create(liveID: subscribedLiveID)
        audienceStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] audienceState in
                guard let self, self.liveID == subscribedLiveID else { return }
                let newItems = audienceState.audienceList.map { audience in
                    Item(
                        id: audience.userID,
                        name: audience.userName,
                        avatarURL: audience.avatarURL,
                        level: audience.level,
                        giftValue: "0"
                    )
                }
                self.applyItems(newItems)
            }
            .store(in: &cancellables)
        audienceStore.fetchAudienceList(completion: nil)
        present()
    }

    override func sheetDidDismiss() {
        super.sheetDidDismiss()
        cancellables.removeAll()
    }

    private func applyItems(_ newItems: [Item]) {
        guard items != newItems else { return }
        items = newItems
        audienceList.reloadData()
    }

    private func configureUI() {
        sheetTitle = LiveKitResources.localizedString("tuilivekit.player.online_audience")

        audienceList.backgroundColor = .clear
        audienceList.separatorStyle = .none
        audienceList.showsVerticalScrollIndicator = false
        audienceList.rowHeight = 64
        audienceList.dataSource = self
        audienceList.delegate = self
        audienceList.register(AudienceListCell.self, forCellReuseIdentifier: AudienceListCell.reuseIdentifier)
        contentView.addSubview(audienceList)

        audienceList.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(58)
            make.bottom.equalToSuperview().inset(24)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AudienceListPanel: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: AudienceListCell.reuseIdentifier,
            for: indexPath
        ) as? AudienceListCell else {
            return UITableViewCell()
        }
        let item = items[indexPath.row]
        cell.bind(rank: indexPath.row + 1, item: item)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        guard !item.id.isEmpty, item.id != selfUserID, let container = superview else { return }
        let profilePanel = AudienceProfilePanel(
            userID: item.id,
            userName: item.name,
            avatarURL: item.avatarURL
        )
        container.addSubview(profilePanel)
        profilePanel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        dismiss()
        profilePanel.present()
    }
}

private final class AudienceListCell: UITableViewCell {
    static let reuseIdentifier = "TUILiveKit.PlayerAudienceListCell"

    private let tvMarker = UILabel()
    private let avatar = UIImageView()
    private let tvName = UILabel()
    private let levelBadge = LevelBadgeView(level: 0)
    private let tvGiftValue = UILabel()
    private let rowDivider = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.kf.cancelDownloadTask()
        avatar.kf.setImage(with: Optional<URL>.none, placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    func bind(rank: Int, item: AudienceListPanel.Item) {
        tvMarker.text = String(rank)
        let rawName = item.name.isEmpty ? item.id : item.name
        tvName.text = rawName.count > 10 ? String(rawName.prefix(10)) + "…" : rawName
        levelBadge.bind(level: item.level)
        tvGiftValue.text = item.giftValue
        avatar.kf.cancelDownloadTask()
        avatar.kf.setImage(with: URL(string: item.avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    private func configureUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        tvMarker.textColor = UIColor.white.withAlphaComponent(0.38)
        tvMarker.font = .systemFont(ofSize: 15)
        tvMarker.textAlignment = .center

        avatar.contentMode = .scaleAspectFill
        avatar.layer.cornerRadius = 21
        avatar.layer.masksToBounds = true

        tvName.textColor = UIColor.white.withAlphaComponent(0.88)
        tvName.font = .systemFont(ofSize: 15)
        tvName.lineBreakMode = .byTruncatingTail

        tvGiftValue.textColor = UIColor(red: 1, green: 0.886, blue: 0.604, alpha: 1)
        tvGiftValue.font = .systemFont(ofSize: 12, weight: .bold)
        tvGiftValue.textAlignment = .right

        rowDivider.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        [tvMarker, avatar, tvName, levelBadge, tvGiftValue, rowDivider].forEach {
            contentView.addSubview($0)
        }
        tvMarker.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 12, height: 21))
        }
        avatar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.top.equalToSuperview().offset(11)
            make.size.equalTo(42)
        }
        tvName.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(92)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(100)
            make.height.equalTo(21)
        }
        levelBadge.snp.makeConstraints { make in
            make.leading.equalTo(tvName.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
            make.height.equalTo(15)
        }
        tvGiftValue.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 38, height: 16))
        }
        rowDivider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
