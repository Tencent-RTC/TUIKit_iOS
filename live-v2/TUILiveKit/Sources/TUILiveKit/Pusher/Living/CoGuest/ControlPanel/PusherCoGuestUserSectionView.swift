import Kingfisher
import UIKit
import SnapKit

/// One titled user section inside `PusherCoGuestSettingsView` (applicants,
/// connected guests, or invitable candidates). Instantiated once per section.
final class PusherCoGuestUserSectionView: UIView {
    enum ActionStyle: Equatable {
        case primary
        case destructive
    }

    struct Row: Equatable {
        let user: PusherCoGuestStore.User
        let actionTitle: String
        let actionStyle: ActionStyle
        let isPending: Bool
        let isEnabled: Bool

        // This row shows identity and an action; device state belongs to the seat/manage UI.
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.user.userID == rhs.user.userID &&
                lhs.user.userName == rhs.user.userName &&
                lhs.user.avatarURL == rhs.user.avatarURL &&
                lhs.actionTitle == rhs.actionTitle && lhs.actionStyle == rhs.actionStyle &&
                lhs.isPending == rhs.isPending && lhs.isEnabled == rhs.isEnabled
        }
    }

    private enum Metrics {
        static let titleTop: CGFloat = 16
        static let separatorTop: CGFloat = 43
        static let rowsTop: CGFloat = 50
        static let rowHeight: CGFloat = 52
        static let bottomInset: CGFloat = 16
        static let emptyHeight: CGFloat = 152
    }

    var onAction: ((String) -> Void)?

    private let titleLabel = LiveText(.sectionTitle, tone: .secondary)
    private let emptyLabel = LiveText(.body, tone: .secondary, alignment: .center)
    private let separatorView = UIView()
    private let rowsStack = UIStackView()
    private let baseTitle: String
    private let showsCount: Bool
    private var rows: [Row] = []
    private var rowViews: [String: PusherCoGuestUserRowView] = [:]

    var preferredHeight: CGFloat {
        rows.isEmpty
            ? Metrics.emptyHeight
            : Metrics.rowsTop + CGFloat(rows.count) * Metrics.rowHeight + Metrics.bottomInset
    }

    init(title: String, emptyText: String, showsCount: Bool = false) {
        baseTitle = title
        self.showsCount = showsCount
        super.init(frame: .zero)
        configureUI(title: title, emptyText: emptyText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ rows: [Row]) {
        guard self.rows != rows else { return }
        self.rows = rows
        emptyLabel.isHidden = !rows.isEmpty
        separatorView.isHidden = rows.isEmpty
        titleLabel.text = showsCount && !rows.isEmpty ? "\(baseTitle)（\(rows.count)）" : baseTitle
        let validIDs = Set(rows.map { $0.user.userID })
        for id in Array(rowViews.keys) where !validIDs.contains(id) {
            guard let view = rowViews.removeValue(forKey: id) else { continue }
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, row) in rows.enumerated() {
            let id = row.user.userID
            let rowView: PusherCoGuestUserRowView
            if let existing = rowViews[id] {
                rowView = existing
                rowView.bind(row)
            } else {
                rowView = PusherCoGuestUserRowView(row: row)
                rowView.onAction = { [weak self] in self?.onAction?(id) }
                rowView.snp.makeConstraints { $0.height.equalTo(Metrics.rowHeight) }
                rowViews[id] = rowView
            }
            if rowsStack.arrangedSubviews.firstIndex(of: rowView) != index {
                rowsStack.removeArrangedSubview(rowView)
                rowsStack.insertArrangedSubview(rowView, at: index)
            }
        }
    }

    private func configureUI(title: String, emptyText: String) {
        backgroundColor = PusherCoGuestGroupStyle.background
        layer.cornerRadius = PusherCoGuestGroupStyle.cornerRadius
        layer.masksToBounds = true

        titleLabel.text = title
        addSubview(titleLabel)

        emptyLabel.text = emptyText
        addSubview(emptyLabel)

        separatorView.backgroundColor = PusherCoGuestMemberStyle.separator
        separatorView.isHidden = true
        addSubview(separatorView)

        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        addSubview(rowsStack)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(Metrics.titleTop)
            make.height.equalTo(15)
        }
        emptyLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(79)
            make.height.equalTo(18)
        }
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(Metrics.separatorTop)
            make.height.equalTo(1)
        }
        rowsStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(Metrics.rowsTop)
        }
    }
}

private final class PusherCoGuestUserRowView: UIView {
    var onAction: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = LiveText(.itemTitle, tone: .secondary)
    private let actionButton = UIButton(type: .system)
    private var row: PusherCoGuestUserSectionView.Row?

    init(row: PusherCoGuestUserSectionView.Row) {
        super.init(frame: .zero)
        configureUI()
        bind(row)
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

    private func configureUI() {
        avatarView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 17
        avatarView.layer.masksToBounds = true
        avatarView.layer.borderWidth = 1
        avatarView.layer.borderColor = PusherCoGuestMemberStyle.avatarBorder.cgColor
        addSubview(avatarView)

        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        actionButton.titleLabel?.font = PusherCoGuestUserRowViewTypography.actionButtonFont
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        actionButton.layer.cornerRadius = 10
        actionButton.layer.borderWidth = 1
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        actionButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
        addSubview(actionButton)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(34)
        }
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
            make.width.greaterThanOrEqualTo(68)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(10)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
        }

    }

    func bind(_ row: PusherCoGuestUserSectionView.Row) {
        guard self.row != row else { return }
        let avatarChanged = self.row?.user.avatarURL != row.user.avatarURL
        self.row = row
        nameLabel.text = row.user.userName
        UIView.performWithoutAnimation {
            actionButton.setTitle(
                row.isPending ? LiveKitResources.localizedString("tuilivekit.common.processing") : row.actionTitle,
                for: .normal
            )
            applyStyle(row.actionStyle)
            actionButton.isEnabled = row.isEnabled && !row.isPending
            actionButton.alpha = actionButton.isEnabled ? 1 : 0.46
        }
        guard avatarChanged else { return }
        avatarView.kf.cancelDownloadTask()

        avatarView.kf.setImage(with: URL(string: row.user.avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    private func applyStyle(_ style: PusherCoGuestUserSectionView.ActionStyle) {
        switch style {
        case .primary:
            actionButton.backgroundColor = PusherCoGuestMemberStyle.primaryBackground
            actionButton.layer.borderColor = PusherCoGuestMemberStyle.primaryBorder.cgColor
            actionButton.setTitleColor(.white, for: .normal)
        case .destructive:
            actionButton.backgroundColor = PusherCoGuestMemberStyle.dangerBackground
            actionButton.layer.borderColor = PusherCoGuestMemberStyle.dangerBorder.cgColor
            actionButton.setTitleColor(PusherCoGuestMemberStyle.dangerForeground, for: .normal)
        }
    }

    @objc private func handleAction() {
        onAction?()
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherCoGuestMemberStyle {
    static let separator: UIColor = UIColor.white.withAlphaComponent(0.07)
    static let avatarBorder: UIColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.22)
    static let primaryBackground: UIColor = UIColor(red: 0.133, green: 0.416, blue: 0.871, alpha: 0.393)
    static let primaryBorder: UIColor = UIColor(red: 0.412, green: 0.682, blue: 1, alpha: 0.338)
    static let dangerBackground: UIColor = UIColor(red: 1, green: 0.31, blue: 0.34, alpha: 0.1)
    static let dangerBorder: UIColor = UIColor(red: 1, green: 0.31, blue: 0.34, alpha: 0.22)
    static let dangerForeground: UIColor = UIColor(red: 1, green: 0.439, blue: 0.463, alpha: 1)
}

private enum PusherCoGuestUserRowViewTypography {
    static let actionButtonFont: UIFont = UIFont.systemFont(ofSize: 12)
}
