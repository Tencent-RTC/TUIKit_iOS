import TUIRoomKit
import UIKit
import SnapKit
import Combine
import AtomicXCore

public final class RoomHomeView: UIView {

    public weak var routerContext: RouterContext?
    public var onLoggedOut: (() -> Void)?
    private var cancellableSet = Set<AnyCancellable>()

    private let avatar = RoomAvatar()
    private let titleText = UILabel()

    private let entryStack = UIStackView()
    private let quickMeetingEntry = UIControl()
    private let joinEntry = UIControl()
    private let scheduleEntry = UIControl()
    private var entryIconCircles: [UIView] = []
    private var entryTitleLabels: [UILabel] = []

    private let schedulePanel = UIView()
    private let agendaTitleBar = UIView()
    private let agendaTitleLabel = UILabel()
    private let agendaEmptyContainer = UIView()
    private let agendaEmptyStack = UIStackView()
    private let agendaEmptyArt = UIImageView()
    private let agendaEmptyLabel = UILabel()

    private var profileSheet: RoomHomeLogoutSheet?

    public init() {
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
            observeUserInfo()
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for circle in entryIconCircles {
            guard let gradient = circle.layer.sublayers?.first as? CAGradientLayer else { continue }
            gradient.frame = circle.bounds
            gradient.cornerRadius = circle.bounds.width / 2
        }
        CATransaction.commit()
    }

    private func setupViews() {
        addSubview(avatar)
        addSubview(titleText)

        entryStack.axis = .horizontal
        entryStack.distribution = .fillEqually
        entryStack.alignment = .top
        setupEntry(quickMeetingEntry, iconName: "roomkit_icon_quick_meeting_white",
                   title: .homeQuickMeeting, showsWell: false, action: #selector(handleQuickMeetingTap))
        setupEntry(joinEntry, iconName: "roomkit_icon_plus_accent",
                   title: .homeJoinMeeting, showsWell: true, action: #selector(handleJoinTap))
        setupEntry(scheduleEntry, iconName: "roomkit_icon_calendar_white",
                   title: .homeScheduleMeeting, showsWell: false, action: #selector(handleScheduleTap))
        entryStack.addArrangedSubview(quickMeetingEntry)
        entryStack.addArrangedSubview(joinEntry)
        entryStack.addArrangedSubview(scheduleEntry)
        addSubview(entryStack)

        agendaEmptyStack.addArrangedSubview(agendaEmptyArt)
        agendaEmptyStack.addArrangedSubview(agendaEmptyLabel)
        agendaEmptyContainer.addSubview(agendaEmptyStack)
        schedulePanel.addSubview(agendaTitleBar)
        schedulePanel.addSubview(agendaTitleLabel)
        schedulePanel.addSubview(agendaEmptyContainer)
        addSubview(schedulePanel)
    }

    private func setupConstraints() {
        avatar.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(10)
            $0.leading.equalToSuperview().offset(16)
            $0.size.equalTo(32)
        }
        titleText.snp.makeConstraints {
            $0.centerY.equalTo(avatar)
            $0.leading.equalTo(avatar.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        entryStack.snp.makeConstraints {
            $0.top.equalTo(avatar.snp.bottom).offset(16)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
        }
        schedulePanel.snp.makeConstraints {
            $0.top.equalTo(entryStack.snp.bottom).offset(28)
            $0.leading.equalToSuperview().offset(12)
            $0.trailing.equalToSuperview().offset(-12)
            $0.bottom.equalTo(safeAreaLayoutGuide).offset(-16)
        }

        agendaTitleBar.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.centerY.equalTo(agendaTitleLabel)
            $0.size.equalTo(CGSize(width: 3, height: 12))
        }
        agendaTitleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.leading.equalTo(agendaTitleBar.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        agendaEmptyContainer.snp.makeConstraints {
            $0.top.equalTo(agendaTitleLabel.snp.bottom).offset(8)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        agendaEmptyStack.snp.makeConstraints {
            $0.top.greaterThanOrEqualToSuperview().offset(12)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-26)
            $0.leading.greaterThanOrEqualToSuperview().offset(20)
            $0.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
        agendaEmptyArt.snp.makeConstraints {
            $0.width.equalTo(schedulePanel).multipliedBy(0.78).priority(.high)
            $0.width.lessThanOrEqualTo(232)
            $0.height.equalTo(agendaEmptyArt.snp.width).multipliedBy(0.5)
        }
    }

    private func setupStyles() {
        titleText.font = .systemFont(ofSize: 17, weight: .semibold)
        titleText.lineBreakMode = .byTruncatingTail

        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleAvatarTap)))

        schedulePanel.layer.cornerRadius = 20
        schedulePanel.layer.masksToBounds = true
        agendaTitleBar.layer.cornerRadius = 1.5
        agendaTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        agendaTitleLabel.text = .homeAgenda

        agendaEmptyArt.contentMode = .scaleAspectFit
        agendaEmptyStack.axis = .vertical
        agendaEmptyStack.alignment = .center
        agendaEmptyStack.spacing = 12
        agendaEmptyLabel.numberOfLines = 0

        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: RoomKitResources.languageDidChangeNotification, object: nil)

        applyTheme()
    }

    private func setupEntry(_ card: UIControl, iconName: String, title: String, showsWell: Bool, action: Selector) {
        let iconCircle = UIView()
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.roomKitAccentSoftTint.cgColor,
            UIColor.roomKitAccent.cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        iconCircle.layer.insertSublayer(gradient, at: 0)
        iconCircle.layer.masksToBounds = true
        iconCircle.layer.cornerRadius = 34
        iconCircle.isUserInteractionEnabled = false

        let iconView = UIImageView(image: RoomKitResources.image(named: iconName))
        iconView.isUserInteractionEnabled = false
        if showsWell {
            let well = UIView()
            well.backgroundColor = UIColor.roomKitFgOnAccent
            well.layer.cornerRadius = 6
            well.isUserInteractionEnabled = false
            iconCircle.addSubview(well)
            well.snp.makeConstraints { $0.center.equalToSuperview(); $0.size.equalTo(22) }
            well.addSubview(iconView)
            iconView.snp.makeConstraints { $0.center.equalToSuperview(); $0.size.equalTo(6) }
        } else {
            iconCircle.addSubview(iconView)
            iconView.snp.makeConstraints { $0.center.equalToSuperview(); $0.size.equalTo(22) }
        }

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = title
        titleLabel.textColor = UIColor.roomKitFgPrimary
        titleLabel.isUserInteractionEnabled = false

        card.addSubview(iconCircle)
        card.addSubview(titleLabel)
        card.snp.makeConstraints { $0.height.equalTo(96) }
        iconCircle.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
            $0.size.equalTo(68)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(iconCircle.snp.bottom).offset(10)
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(13 * 1.2)
        }

        entryIconCircles.append(iconCircle)
        entryTitleLabels.append(titleLabel)

        card.addTarget(self, action: action, for: .touchUpInside)
        for event: UIControl.Event in [.touchDown, .touchDragEnter] {
            card.addTarget(self, action: #selector(handleEntryPressDown(_:)), for: event)
        }
        for event: UIControl.Event in [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit] {
            card.addTarget(self, action: #selector(handleEntryPressUp(_:)), for: event)
        }
    }

    @objc private func handleEntryPressDown(_ sender: UIControl) {
        sender.alpha = 0.82
        sender.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
    }

    @objc private func handleEntryPressUp(_ sender: UIControl) {
        sender.alpha = 1
        sender.transform = .identity
    }

    @objc private func handleQuickMeetingTap() {
        routerContext?.push(RoomQuickStartViewController(), animated: true)
    }

    @objc private func handleJoinTap() {
        routerContext?.push(RoomJoinViewController(), animated: true)
    }

    @objc private func handleScheduleTap() {
        RoomToast.show(.homeComingSoon)
    }

    private func updateAgendaEmptyText() {
        let lineHeight = 15 * 1.3
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        agendaEmptyLabel.attributedText = NSAttributedString(
            string: .homeAgendaEmpty,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.roomKitFgSecondary,
                .paragraphStyle: paragraph,
            ]
        )
    }

    private var presenter: UIViewController? {
        if let controller = routerContext as? UIViewController { return controller }
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    @objc private func handleAvatarTap() {
        guard profileSheet == nil else { return }
        let sheet = RoomHomeLogoutSheet()
        sheet.onSettings = { [weak self] in
            self?.profileSheet?.dismiss()
            self?.profileSheet = nil
            self?.routerContext?.push(RoomSettingsViewController(), animated: true)
        }
        sheet.onLogout = { [weak self] in
            self?.profileSheet?.dismiss()
            self?.profileSheet = nil
            self?.presentLogoutDialog()
        }
        sheet.onDismiss = { [weak self] in
            self?.profileSheet = nil
        }
        profileSheet = sheet
        sheet.show(in: self)
    }

    private func presentLogoutDialog() {
        guard let presenter else { return }
        var dialog: RoomDialog?
        dialog = RoomDialog.Builder(in: presenter)
            .title(RoomKitResources.localizedString("roomkit.home.logout"))
            .message(RoomKitResources.localizedString("roomkit.home.logout_confirm"))
            .closable(false)
            .cancelable(false)
            .secondaryAction(RoomKitResources.localizedString("roomkit.common.cancel")) {}
            .primaryAction(RoomKitResources.localizedString("roomkit.home.logout")) { [weak self] in
                dialog?.dismiss(animated: true)
                self?.logout()
            }
            .show()
    }

    private func logout() {
        LoginStore.shared.logout { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    RoomToast.show(RoomKitResources.localizedString("roomkit.home.logged_out"))
                    self?.onLoggedOut?()
                case .failure(let error):
                    ErrorLocalized.showError(code: error.code, message: error.message)
                }
            }
        }
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgCanvas
        titleText.textColor = UIColor.roomKitFgPrimary

        schedulePanel.backgroundColor = UIColor.roomKitBgSurface
        agendaTitleBar.backgroundColor = UIColor.roomKitAccent
        agendaTitleLabel.textColor = UIColor.roomKitFgPrimary
        agendaEmptyArt.image = RoomKitResources.image(named: "roomkit_illustration_agenda_empty")
        updateAgendaEmptyText()
    }

    @objc private func handleLanguageChanged() {
        let titles: [String] = [.homeQuickMeeting, .homeJoinMeeting, .homeScheduleMeeting]
        for (index, label) in entryTitleLabels.enumerated() where titles.indices.contains(index) {
            label.text = titles[index]
        }
        agendaTitleLabel.text = .homeAgenda
        updateAgendaEmptyText()
    }

    private func observeUserInfo() {
        LoginStore.shared.state
            .subscribe(StatePublisherSelector(projector: { state in
                state.loginStatus == .logined ? state.loginUserInfo : nil
            }))
            .receive(on: RunLoop.main)
            .sink { [weak self] userInfo in
                self?.updateUserInfo(userInfo)
            }
            .store(in: &cancellableSet)
    }

    private func updateUserInfo(_ userInfo: UserProfile?) {
        guard let userInfo else { return }
        let displayName = userInfo.displayName
        titleText.text = displayName
        avatar.text = displayName
        avatar.url = userInfo.avatarURL
    }
}

extension String {
    fileprivate static var homeComingSoon: String { RoomKitResources.localizedString("roomkit.home.coming_soon") }
    fileprivate static var homeQuickMeeting: String { RoomKitResources.localizedString("roomkit.home.quick_meeting") }
    fileprivate static var homeJoinMeeting: String { RoomKitResources.localizedString("roomkit.home.join_meeting") }
    fileprivate static var homeScheduleMeeting: String { RoomKitResources.localizedString("roomkit.home.schedule_meeting") }
    fileprivate static var homeAgenda: String { RoomKitResources.localizedString("roomkit.home.agenda") }
    fileprivate static var homeAgendaEmpty: String { RoomKitResources.localizedString("roomkit.home.agenda_empty") }
}
