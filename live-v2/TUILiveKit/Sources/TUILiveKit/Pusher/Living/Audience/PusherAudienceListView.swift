import Kingfisher
import SnapKit
import UIKit

final class PusherAudienceListView: BottomSheetView {
    var onRefresh: (() -> Void)?
    var onSelectAudience: ((PusherAudienceStore.User) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var audience: [PusherAudienceStore.User] = []
    private var selectedAudience: PusherAudienceStore.User?

    override var sheetHeight: CGFloat { 422 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func bind(_ audience: [PusherAudienceStore.User]) {
        guard self.audience != audience else { return }
        self.audience = audience
        tableView.reloadData()
    }

    func show() {
        selectedAudience = nil
        onRefresh?()
        present()
    }

    func cancelPendingSelection() {
        selectedAudience = nil
    }

    override func sheetDidDismiss() {
        guard let selectedAudience else { return }
        self.selectedAudience = nil
        onSelectAudience?(selectedAudience)
    }

    private func configureUI() {
        sheetTitle = LiveKitResources.localizedString("tuilivekit.player.online_audience")

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = 64
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            PusherAudienceListCell.self,
            forCellReuseIdentifier: PusherAudienceListCell.reuseIdentifier
        )
        contentView.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(58)
            make.bottom.equalToSuperview().inset(24)
        }
    }
}

extension PusherAudienceListView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        audience.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PusherAudienceListCell.reuseIdentifier,
            for: indexPath
        ) as? PusherAudienceListCell else {
            return UITableViewCell()
        }
        cell.bind(rank: indexPath.row + 1, maximumRank: audience.count, user: audience[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard audience.indices.contains(indexPath.row) else { return }
        selectedAudience = audience[indexPath.row]
        dismiss()
    }
}

private final class PusherAudienceListCell: UITableViewCell {
    static let reuseIdentifier = "TUILiveKit.PusherAudienceListCell"

    private let rankLabel = LiveText(.listTitle, tone: .disabled, alignment: .center)
    private let avatarView = UIImageView()
    private let nameLabel = LiveText(.listTitle, tone: .secondary)
    private let levelBadgeView = LevelBadgeView(level: 0)
    private let giftValueLabel = UILabel()
    private let separatorView = UIView()
    private var rankWidthConstraint: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: Optional<URL>.none, placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    func bind(rank: Int, maximumRank: Int, user: PusherAudienceStore.User) {
        let font = rankLabel.font ?? LiveTheme.Typography.font(for: .listTitle)
        let digitWidth = (0...9).map {
            (String($0) as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        let rankWidth = max(
            LiveAudienceRowStyle.rankSize.width,
            ceil(digitWidth * CGFloat(String(maximumRank).count))
        )
        rankWidthConstraint?.update(offset: rankWidth)
        rankLabel.text = String(rank)
        nameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        levelBadgeView.bind(level: user.level)
        giftValueLabel.text = "0"
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: URL(string: user.avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    private func configureUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = LiveAudienceRowStyle.avatarRadius
        avatarView.layer.masksToBounds = true

        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        giftValueLabel.textColor = LiveTheme.Color.audienceGiftValue
        giftValueLabel.font = LiveAudienceRowStyle.giftValueFont
        giftValueLabel.textAlignment = .right

        separatorView.backgroundColor = LiveAudienceRowStyle.separator

        [rankLabel, avatarView, nameLabel, levelBadgeView, giftValueLabel, separatorView].forEach {
            contentView.addSubview($0)
        }
        rankLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(LiveAudienceRowStyle.edgeInset)
            make.centerY.equalToSuperview()
            rankWidthConstraint = make.width.equalTo(LiveAudienceRowStyle.rankSize.width).constraint
            make.height.equalTo(LiveAudienceRowStyle.rankSize.height)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(rankLabel.snp.trailing).offset(
                LiveAudienceRowStyle.avatarLeading - LiveAudienceRowStyle.edgeInset - LiveAudienceRowStyle.rankSize.width
            )
            make.top.equalToSuperview().offset(LiveAudienceRowStyle.avatarTop)
            make.size.equalTo(LiveAudienceRowStyle.avatarSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(
                LiveAudienceRowStyle.nameLeading - LiveAudienceRowStyle.avatarLeading - LiveAudienceRowStyle.avatarSize
            )
            make.centerY.equalToSuperview()
            make.height.equalTo(21)
        }
        levelBadgeView.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.height.equalTo(15)
            make.trailing.lessThanOrEqualTo(giftValueLabel.snp.leading).offset(-12)
        }
        giftValueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(LiveAudienceRowStyle.edgeInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LiveAudienceRowStyle.giftValueSize)
        }
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(LiveAudienceRowStyle.edgeInset)
            make.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
