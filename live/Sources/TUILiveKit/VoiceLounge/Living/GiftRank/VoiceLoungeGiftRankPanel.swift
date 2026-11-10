import Combine
import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeGiftRankPanel: BottomSheetView {
    private let store: VoiceLoungeGiftRankStore
    private var cancellables = Set<AnyCancellable>()
    private var ranking: [VoiceLoungeGiftRankStore.Entry] = []
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let podium = PodiumView()
    private let emptyLabel = LiveText.voiceLounge(.body, tone: .tertiary, alignment: .center)

    override var sheetHeight: CGFloat { 640 }

    init(store: VoiceLoungeGiftRankStore) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) override init(frame: CGRect) {
        fatalError("init(frame:) is unavailable; use init(store:)")
    }

    func show() {
        render(store.ranking)
        present()
        store.refresh()
    }

    private func setupViews() {
        contentView.addSubview(emptyLabel)
        contentView.addSubview(tableView)
    }

    private func setupConstraints() {
        emptyLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(120)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupStyles() {
        sheetTitle = .giftRank
        emptyLabel.text = .empty
        emptyLabel.isHidden = true
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = RankCell.height
        tableView.dataSource = self
        tableView.register(RankCell.self, forCellReuseIdentifier: RankCell.reuseIdentifier)
        podium.frame = CGRect(x: 0, y: 0, width: 0, height: Self.podiumHeight)
        tableView.tableHeaderView = podium
    }

    private func setupBindings() {
        store.changes.sink { [weak self] in
            guard let self else { return }
            self.render(self.store.ranking)
        }.store(in: &cancellables)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = tableView.bounds.width
        guard width > 0, podium.frame.width != width else { return }
        podium.frame = CGRect(x: 0, y: 0, width: width, height: Self.podiumHeight)
        tableView.tableHeaderView = podium
    }

    private static let podiumHeight: CGFloat = 230

    private func render(_ ranking: [VoiceLoungeGiftRankStore.Entry]) {
        self.ranking = ranking
        emptyLabel.isHidden = !ranking.isEmpty
        tableView.isHidden = ranking.isEmpty
        podium.bind(Array(ranking.prefix(3)))
        tableView.reloadData()
    }

}

extension VoiceLoungeGiftRankPanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(0, ranking.count - 3) }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RankCell.reuseIdentifier, for: indexPath)
        let index = indexPath.row + 3
        if let cell = cell as? RankCell, index < ranking.count { cell.bind(rank: index + 1, entry: ranking[index]) }
        return cell
    }
}

private final class PodiumView: UIView {
    private let slot1 = PodiumSlot(rank: 1)
    private let slot2 = PodiumSlot(rank: 2)
    private let slot3 = PodiumSlot(rank: 3)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(slot2)
        addSubview(slot1)
        addSubview(slot3)
        slot1.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
            make.width.equalTo(110)
        }
        slot2.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(-104)
            make.top.equalToSuperview().offset(52)
            make.width.equalTo(100)
        }
        slot3.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(104)
            make.top.equalToSuperview().offset(52)
            make.width.equalTo(100)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ top3: [VoiceLoungeGiftRankStore.Entry]) {
        slot1.bind(top3.count > 0 ? top3[0] : nil)
        slot2.bind(top3.count > 1 ? top3[1] : nil)
        slot3.bind(top3.count > 2 ? top3[2] : nil)
    }
}

private final class PodiumSlot: UIView {
    private let rank: Int
    private let avatarView = UIImageView()
    private let ringView = UIView()
    private let badge = UILabel()
    private let nameLabel = UILabel()
    private let coinsLabel = UILabel()

    init(rank: Int) {
        self.rank = rank
        super.init(frame: .zero)

        let size: CGFloat = rank == 1 ? 72 : 60
        let color = PodiumSlot.rankColor(rank)

        ringView.layer.borderWidth = 2.5
        ringView.layer.borderColor = color.cgColor
        ringView.layer.cornerRadius = size / 2 + 3
        addSubview(ringView)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = size / 2
        avatarView.backgroundColor = VoiceLoungeColor.overlayBase
        addSubview(avatarView)

        badge.text = "\(rank)"
        badge.font = .systemFont(ofSize: 14, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = color
        badge.layer.cornerRadius = 10
        badge.layer.masksToBounds = true
        addSubview(badge)

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        addSubview(nameLabel)

        coinsLabel.font = .systemFont(ofSize: 14)
        coinsLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        coinsLabel.textAlignment = .center
        addSubview(coinsLabel)

        ringView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(size + 6)
        }
        avatarView.snp.makeConstraints { make in
            make.center.equalTo(ringView)
            make.size.equalTo(size)
        }
        badge.snp.makeConstraints { make in
            make.centerX.equalTo(ringView)
            make.bottom.equalTo(ringView).offset(2)
            make.size.equalTo(20)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(ringView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }
        coinsLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ entry: VoiceLoungeGiftRankStore.Entry?) {
        if let entry {
            avatarView.kf.setImage(
                with: URL(string: entry.avatarURL),
                placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
            nameLabel.text = entry.name
            coinsLabel.text = "\(entry.coins)"
            isHidden = false
        } else {
            isHidden = true
        }
    }

    static func rankColor(_ rank: Int) -> UIColor {
        switch rank {
        case 1: return UIColor(red: 1.0, green: 0.82, blue: 0.3, alpha: 1)
        case 2: return UIColor(red: 0.78, green: 0.82, blue: 0.9, alpha: 1)
        default: return UIColor(red: 0.84, green: 0.6, blue: 0.4, alpha: 1)
        }
    }
}

private final class RankCell: UITableViewCell {
    static let reuseIdentifier = "VoiceLoungeGiftRankCell"
    static let height: CGFloat = 64

    private let rankLabel = UILabel()
    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let coinsLabel = UILabel()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        rankLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        rankLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        rankLabel.textAlignment = .center
        contentView.addSubview(rankLabel)

        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 18
        avatar.backgroundColor = VoiceLoungeColor.overlayBase
        contentView.addSubview(avatar)

        nameLabel.font = .systemFont(ofSize: 16)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)

        coinsLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        coinsLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        coinsLabel.textAlignment = .right
        contentView.addSubview(coinsLabel)

        separator.backgroundColor = VoiceLoungeColor.overlayHair
        contentView.addSubview(separator)

        rankLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(24)
        }
        avatar.snp.makeConstraints { make in
            make.leading.equalTo(rankLabel.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(36)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatar.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(coinsLabel.snp.leading).offset(-10)
        }
        coinsLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
        }
        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(rank: Int, entry: VoiceLoungeGiftRankStore.Entry) {
        rankLabel.text = "\(rank)"
        nameLabel.text = entry.name
        coinsLabel.text = "\(entry.coins)"
        avatar.kf.cancelDownloadTask()
        avatar.kf.setImage(
            with: URL(string: entry.avatarURL),
            placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }
}

private extension String {
    static var empty: String { LiveKitResources.localizedString("tuilivekit.voiceroom.rank.empty") }
    static var giftRank: String { LiveKitResources.localizedString("tuilivekit.voiceroom.room.gift_rank") }
}
