import AtomicXCore
import Combine
import SnapKit
import UIKit

final class VoiceLoungeCoGuestBannerView: UIView {
    enum Kind {
        case invitation
        case requesting
        case leaving
    }

    private let kind: Kind
    private let store: VoiceLoungeSeatStore
    private var cancellables = Set<AnyCancellable>()
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.body, tone: .primary)
    private let actionButton = UIButton(type: .custom)
    private let closeButton = UIButton(type: .custom)
    private var animationToken = 0

    private let barView = UIView()

    private var coGuest: VoiceLoungeCoGuestStore { store.coGuest }
    private var hasCloseButton: Bool { kind != .requesting }

    private enum Metrics {
        static let barHeight: CGFloat = 56
        static let closeSize: CGFloat = 36
        static let closeGap: CGFloat = 8
    }

    init(kind: Kind, store: VoiceLoungeSeatStore) {
        self.kind = kind
        self.store = store
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(barView)
        barView.addSubview(iconView)
        barView.addSubview(titleLabel)
        barView.addSubview(actionButton)
        addSubview(closeButton)
    }

    private func setupConstraints() {
        snp.makeConstraints { $0.height.equalTo(Metrics.barHeight) }
        barView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview().inset(Metrics.closeSize + Metrics.closeGap)
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.size.equalTo(kind == .requesting ? 20 : 22)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-10)
        }
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(hasCloseButton ? CGSize(width: 84, height: 40) : CGSize(width: 68, height: 36))
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(Metrics.closeSize)
        }
    }

    private func setupStyles() {
        isHidden = true
        backgroundColor = .clear
        barView.backgroundColor = VoiceLoungeColor.floatingBar
        barView.layer.cornerRadius = 22
        iconView.image = LiveKitResources.image(named: "livekit_coguest_invitation")?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        switch kind {
        case .invitation:
            titleLabel.text = .inviteBarTitle
            actionButton.setTitle(.connect, for: .normal)
        case .requesting:
            titleLabel.text = .applyingTitle
            actionButton.setTitle(.cancel, for: .normal)
        case .leaving:
            titleLabel.text = .leaveTitle
            actionButton.setTitle(.leaveConfirm, for: .normal)
        }
        actionButton.layer.cornerRadius = hasCloseButton ? 20 : 18
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.isHidden = !hasCloseButton
        closeButton.setImage(
            LiveKitResources.image(named: "livekit_living_close")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = VoiceLoungeColor.floatingBarIcon
        closeButton.backgroundColor = VoiceLoungeColor.floatingBar
        closeButton.layer.cornerRadius = Metrics.closeSize / 2
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        barView.frame.contains(point) || (!closeButton.isHidden && closeButton.frame.contains(point))
    }

    private func setupBindings() {
        actionButton.addAction(UIAction { [weak self] _ in self?.tapAction() }, for: .touchUpInside)
        closeButton.addAction(UIAction { [weak self] _ in self?.tapClose() }, for: .touchUpInside)
        switch kind {
        case .invitation:
            coGuest.invitationEvents.sink { [weak self] event in self?.handle(event) }.store(in: &cancellables)
        case .requesting: store.cancelApplicationPrompts.sink { [weak self] in self?.show() }.store(in: &cancellables)
        case .leaving: store.leavePrompts.sink { [weak self] in self?.show() }.store(in: &cancellables)
        }
        coGuest.changes.sink { [weak self] in self?.syncWithStatus() }.store(in: &cancellables)
    }

    private func syncWithStatus() {
        let status = coGuest.guestStatus
        if kind == .requesting, status == .applying {
            if isHidden { show() }
            return
        }
        if shouldHide(for: status) { hide() }
    }

    private func tapAction() {
        hide()
        switch kind {
        case .invitation: coGuest.acceptInvitation()
        case .requesting: coGuest.cancelApplication()
        case .leaving: coGuest.leaveSeat()
        }
    }

    private func tapClose() {
        hide()
        if kind == .invitation { coGuest.rejectInvitation() }
    }

    private func shouldHide(for status: VoiceLoungeCoGuestStore.GuestStatus) -> Bool {
        switch kind {
        case .invitation: return status == .onSeat
        case .requesting: return status != .applying
        case .leaving: return status != .onSeat
        }
    }

    private func handle(_ event: VoiceLoungeCoGuestStore.InvitationEvent) {
        switch event {
        case .received: show()
        case .cancelled:
            guard !isHidden else { return }
            hide()
        }
    }

    private func show() {
        let skin = store.skin
        actionButton.backgroundColor = skin.mid
        iconView.tintColor = skin.light
        closeButton.tintColor = skin.light
        animationToken += 1
        layer.removeAllAnimations()
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    private func hide() {
        guard !isHidden else { return }
        animationToken += 1
        let token = animationToken
        UIView.animate(
            withDuration: 0.2, animations: { self.alpha = 0 },
            completion: { [weak self] finished in
                guard let self, finished, token == self.animationToken else { return }
                self.isHidden = true
            })
    }
}

private extension String {
    static var inviteBarTitle: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.comic.invite_bar_title")
    }
    static var connect: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.connect") }
    static var cancel: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.applying_cancel") }
    static var applyingTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.applying_title") }
    static var leaveTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.leave_title") }
    static var leaveConfirm: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.leave_confirm") }
}
