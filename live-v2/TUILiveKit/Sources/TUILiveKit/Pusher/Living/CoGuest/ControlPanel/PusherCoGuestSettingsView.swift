import UIKit
import SnapKit

/// Co-guest management drawer: seat layout picker plus applicant, connected and
/// candidate sections.
final class PusherCoGuestSettingsView: BottomSheetView {
    weak var actionHandler: PusherCoGuestActionHandling?

    private enum Metrics {
        /// Distance from the panel top to the scroll view, covering grabber and title.
        static let scrollTopInset: CGFloat = 78
        /// Gap between the scroll view bottom and the panel safe area bottom.
        static let scrollBottomInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let layoutSectionHeight: CGFloat = 162
        static let maximumPanelHeight: CGFloat = 654
        /// Keeps the panel from covering the whole screen on short devices.
        static let minimumTopGap: CGFloat = 80
    }

    private let titleLabel = LiveText(.sheetTitle, alignment: .center)
    private let endAllButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let layoutSection = CoGuestSectionView()
    private let layoutSectionTitle = LiveText(.sectionTitle, tone: .secondary)
    private let connectedSection = PusherCoGuestUserSectionView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.coguest.connected"),
        emptyText: LiveKitResources.localizedString("tuilivekit.pusher.coguest.empty"),
        showsCount: true
    )
    private let applicantSection = PusherCoGuestUserSectionView(title: LiveKitResources.localizedString("tuilivekit.pusher.coguest.applicants"), emptyText: "")
    private let candidateSection = PusherCoGuestUserSectionView(title: LiveKitResources.localizedString("tuilivekit.pusher.coguest.candidates"), emptyText: "")
    private var layoutControls: [PusherCoGuestStore.Layout: CoGuestLayoutControl] = [:]
    private var sectionHeightConstraints: [ObjectIdentifier: Constraint] = [:]
    private var state = PusherCoGuestStore.State()

    /// Height that shows the whole content without scrolling, capped so that the
    /// panel never fills the screen. Derived from the real section heights and the
    /// bottom safe area instead of a fixed base value.
    override var sheetHeight: CGFloat {
        let target = Metrics.scrollTopInset
            + contentHeight
            + Metrics.scrollBottomInset
            + safeAreaInsets.bottom
        let available = bounds.height > 0
            ? bounds.height - Metrics.minimumTopGap
            : Metrics.maximumPanelHeight
        return min(min(Metrics.maximumPanelHeight, available), target)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func bind(_ state: PusherCoGuestStore.State) {
        let previousHeight = sheetHeight
        self.state = state
        layoutControls.forEach { layout, control in
            control.isActive = layout == state.layout
            control.isEnabled = !state.isUpdatingLayout
            control.alpha = 1
        }

        connectedSection.bind(rows(state.connected, titleKey: "tuilivekit.pusher.coguest.end", style: .destructive))
        applicantSection.bind(rows(state.applicants, titleKey: "tuilivekit.pusher.coguest.accept", style: .primary, enabled: !state.isFull))
        let inviteeRows = rows(state.invitees, titleKey: "tuilivekit.pusher.coguest.cancel_invitation", style: .destructive)
        let candidateRows = rows(state.candidates, titleKey: "tuilivekit.pusher.coguest.invite", style: .primary, enabled: !state.isFull)
        candidateSection.bind(inviteeRows + candidateRows)
        applicantSection.isHidden = state.applicants.isEmpty
        candidateSection.isHidden = inviteeRows.isEmpty && candidateRows.isEmpty
        // The bulk action only exists while at least one guest is connected.
        endAllButton.isHidden = state.connected.isEmpty
        endAllButton.isEnabled = !state.connected.allSatisfy { state.pendingUserIDs.contains($0.userID) }
        endAllButton.alpha = endAllButton.isEnabled ? 1 : 0.46

        updateSectionHeight(connectedSection)
        updateSectionHeight(applicantSection)
        updateSectionHeight(candidateSection)
        if abs(sheetHeight - previousHeight) > 0.5 {
            updateSheetHeight(animated: !isHidden)
        }
    }

    func show() {
        present()
    }

    override func sheetWillPresent() {
        scrollView.setContentOffset(.zero, animated: false)
    }

    private func configureUI() {
        titleLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.coguest.settings")
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(titleLabel)

        endAllButton.setTitle(LiveKitResources.localizedString("tuilivekit.pusher.coguest.end_all"), for: .normal)
        endAllButton.setTitleColor(PusherCoGuestSettingsStyle.endAllForeground, for: .normal)
        endAllButton.titleLabel?.font = LiveTheme.Typography.font(for: .action)
        endAllButton.contentHorizontalAlignment = .right
        endAllButton.isHidden = true
        endAllButton.addTarget(self, action: #selector(handleEndAll), for: .touchUpInside)
        contentView.addSubview(endAllButton)

        scrollView.showsVerticalScrollIndicator = false
        contentView.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        scrollView.addSubview(contentStack)

        [layoutSection, connectedSection, applicantSection, candidateSection].forEach {
            contentStack.addArrangedSubview($0)
        }

        layoutSectionTitle.text = LiveKitResources.localizedString("tuilivekit.pusher.coguest.layout")
        layoutSection.addSubview(layoutSectionTitle)

        let layoutControls = PusherCoGuestStore.Layout.allCases.map { layout -> CoGuestLayoutControl in
            let control = CoGuestLayoutControl(title: layout.title, assetName: layout.assetName)
            control.addAction(UIAction { [weak self] _ in self?.actionHandler?.selectLayout(layout) }, for: .touchUpInside)
            self.layoutControls[layout] = control
            return control
        }
        let layoutGrid = UIStackView(arrangedSubviews: stride(from: 0, to: layoutControls.count, by: 2).map { index in
            let row = UIStackView(arrangedSubviews: Array(layoutControls[index ..< min(index + 2, layoutControls.count)]))
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            return row
        })
        layoutGrid.axis = .vertical
        layoutGrid.spacing = 8
        layoutGrid.distribution = .fillEqually
        layoutSection.addSubview(layoutGrid)

        connectedSection.onAction = { [weak self] in self?.actionHandler?.disconnect(userID: $0) }
        applicantSection.onAction = { [weak self] in self?.actionHandler?.acceptApplication(userID: $0) }
        candidateSection.onAction = { [weak self] userID in
            guard let self else { return }
            if self.state.invitees.contains(where: { $0.userID == userID }) {
                self.actionHandler?.cancelInvitation(userID: userID)
            } else {
                self.actionHandler?.invite(userID: userID)
            }
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview().priority(.high)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(endAllButton.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(36)
            make.height.equalTo(20)
        }
        endAllButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(max(88, ceil(endAllButton.intrinsicContentSize.width)))
            make.height.equalTo(20)
        }
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(78)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-32)
        }
        layoutSection.snp.makeConstraints { $0.height.equalTo(162) }
        layoutSectionTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(16)
            make.height.equalTo(15)
        }
        layoutGrid.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(42)
            make.height.equalTo(104)
        }
        [connectedSection, applicantSection, candidateSection].forEach { section in
            section.snp.makeConstraints { make in
                sectionHeightConstraints[ObjectIdentifier(section)] = make.height.equalTo(section.preferredHeight).constraint
            }
        }
        bind(state)
    }

    private func updateSectionHeight(_ section: PusherCoGuestUserSectionView) {
        sectionHeightConstraints[ObjectIdentifier(section)]?.update(offset: section.preferredHeight)
    }

    private func rows(
        _ users: [PusherCoGuestStore.User],
        titleKey: String,
        style: PusherCoGuestUserSectionView.ActionStyle,
        enabled: Bool = true
    ) -> [PusherCoGuestUserSectionView.Row] {
        users.map {
            .init(user: $0, actionTitle: LiveKitResources.localizedString(titleKey), actionStyle: style,
                  isPending: state.pendingUserIDs.contains($0.userID), isEnabled: enabled)
        }
    }

    private var contentHeight: CGFloat {
        let sections = [connectedSection, applicantSection, candidateSection].filter { !$0.isHidden }
        return Metrics.layoutSectionHeight + sections.reduce(0) {
            $0 + Metrics.sectionSpacing + $1.preferredHeight
        }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSheetHeight(animated: false)
    }

    @objc private func handleEndAll() {
        actionHandler?.endAllConnections()
    }
}

private final class CoGuestSectionView: UIView {
    private let topHighlight = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = PusherCoGuestGroupStyle.background
        layer.cornerRadius = PusherCoGuestGroupStyle.cornerRadius
        layer.masksToBounds = true
        topHighlight.backgroundColor = UIColor.white.withAlphaComponent(0.05).cgColor
        layer.addSublayer(topHighlight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        topHighlight.frame = CGRect(x: 16, y: 0, width: max(0, bounds.width - 32), height: 1 / UIScreen.main.scale)
    }
}

private final class CoGuestLayoutControl: UIControl {
    private let inactiveGradient = CAGradientLayer()
    private let activeGradient = CAGradientLayer()
    private let activeBorder = CAGradientLayer()
    private let activeBorderMask = CAShapeLayer()
    private let iconView: UIImageView
    private let titleLabel = LiveText(.itemTitle, tone: .secondary)

    var isActive = false { didSet { updateAppearance() } }

    init(title: String, assetName: String) {
        iconView = UIImageView(image: LiveKitResources.image(named: assetName)?.withRenderingMode(.alwaysTemplate))
        super.init(frame: .zero)
        configureUI(title: title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        [inactiveGradient, activeGradient, activeBorder].forEach { $0.frame = bounds }
        activeBorderMask.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75),
            cornerRadius: 11.25
        ).cgPath
    }

    private func configureUI(title: String) {
        backgroundColor = PusherCoGuestSettingsStyle.templateBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true
        layer.borderWidth = 1

        inactiveGradient.colors = [UIColor.white.withAlphaComponent(0.05).cgColor, UIColor.white.withAlphaComponent(0.015).cgColor]
        inactiveGradient.startPoint = CGPoint(x: 0.5, y: 0)
        inactiveGradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(inactiveGradient, at: 0)

        activeGradient.colors = [
            LiveTheme.Color.brandBlue.withAlphaComponent(0.26).cgColor,
            LiveTheme.Color.brandDeepBlue.withAlphaComponent(0.16).cgColor,
        ]
        activeGradient.startPoint = CGPoint(x: 0.5, y: 0)
        activeGradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(activeGradient, above: inactiveGradient)

        activeBorder.colors = [
            LiveTheme.Color.brandDeepBlue.cgColor,
            LiveTheme.Color.brandBlue.cgColor,
            LiveTheme.Color.brandCyan.cgColor,
        ]
        activeBorder.startPoint = CGPoint(x: 0, y: 1)
        activeBorder.endPoint = CGPoint(x: 1, y: 0)
        activeBorderMask.fillColor = UIColor.clear.cgColor
        activeBorderMask.strokeColor = UIColor.white.cgColor
        activeBorderMask.lineWidth = 1.5
        activeBorder.mask = activeBorderMask
        layer.addSublayer(activeBorder)

        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        titleLabel.text = title
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.85
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.size.equalTo(20)
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(12)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(4)
            make.trailing.equalToSuperview().inset(12)
        }
        updateAppearance()
    }

    private func updateAppearance() {
        activeGradient.isHidden = !isActive
        activeBorder.isHidden = !isActive
        layer.borderColor = isActive ? UIColor.clear.cgColor : UIColor.white.withAlphaComponent(0.14).cgColor
        iconView.tintColor = isActive
            ? PusherCoGuestSettingsStyle.selectedCaption
            : PusherCoGuestSettingsStyle.idleCaption
        titleLabel.textColor = iconView.tintColor
        titleLabel.isEmphasized = isActive
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
enum PusherCoGuestGroupStyle {
    static let background: UIColor = UIColor.black.withAlphaComponent(0.278)
    static let cornerRadius: CGFloat = 16
}

private enum PusherCoGuestSettingsStyle {
    static let endAllForeground: UIColor = UIColor(red: 0.898, green: 0.420, blue: 0.451, alpha: 1)
    static let templateBackground: UIColor = UIColor.black.withAlphaComponent(0.22)
    static let selectedCaption: UIColor = UIColor(red: 0.557, green: 0.812, blue: 1, alpha: 1)
    static let idleCaption: UIColor = UIColor.white.withAlphaComponent(0.72)
}
