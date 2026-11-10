import AtomicXCore
import Combine
import SnapKit
import UIKit

final class VoiceLoungeCoGuestBannerView: UIView {
    enum Kind {
        case invitation
        case requesting
    }

    private static let autoHideDelay: TimeInterval = 6

    private let kind: Kind
    private let store: VoiceLoungeSeatStore
    private var cancellables = Set<AnyCancellable>()
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.body, tone: .primary)
    private let actionButton = UIButton(type: .custom)
    private let closeButton = UIButton(type: .custom)
    private var autoHideWork: DispatchWorkItem?
    private var animationToken = 0

    private var coGuest: VoiceLoungeCoGuestStore { store.coGuest }

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
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(actionButton)
        addSubview(closeButton)
    }

    private func setupConstraints() {
        snp.makeConstraints { $0.height.equalTo(56) }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.size.equalTo(kind == .invitation ? 22 : 20)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-10)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }
        actionButton.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-12)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 84, height: 40))
        }
    }

    private func setupStyles() {
        isHidden = true
        backgroundColor = VoiceLoungeColor.floatingBar
        layer.cornerRadius = 22
        let iconName = kind == .invitation ? "livekit_coguest_invitation" : "livekit_coguest_mic"
        iconView.image = LiveKitResources.image(named: iconName)?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        titleLabel.text = kind == .invitation ? .inviteBarTitle : .retractTitle
        actionButton.setTitle(kind == .invitation ? .connect : .retract, for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        actionButton.layer.cornerRadius = 20
        closeButton.setImage(
            LiveKitResources.image(named: "livekit_living_close")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = VoiceLoungeColor.floatingBarIcon
        closeButton.backgroundColor = VoiceLoungeColor.overlayBase
        closeButton.layer.cornerRadius = 16
    }

    private func setupBindings() {
        actionButton.addAction(UIAction { [weak self] _ in self?.tapAction() }, for: .touchUpInside)
        closeButton.addAction(UIAction { [weak self] _ in self?.tapClose() }, for: .touchUpInside)
        switch kind {
        case .invitation:
            coGuest.invitationEvents.sink { [weak self] event in self?.handle(event) }.store(in: &cancellables)
        case .requesting:
            store.cancelApplicationPrompts.sink { [weak self] in self?.show() }.store(in: &cancellables)
        }
        coGuest.changes.sink { [weak self] in
            guard let self, self.shouldHide(for: self.coGuest.guestStatus) else { return }
            self.hide()
        }.store(in: &cancellables)
    }

    private func tapAction() {
        hide()
        switch kind {
        case .invitation: coGuest.acceptInvitation()
        case .requesting: coGuest.cancelApplication()
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
        }
    }

    private func handle(_ event: VoiceLoungeCoGuestStore.InvitationEvent) {
        switch event {
        case .received: show()
        case .cancelled:
            guard !isHidden else { return }
            hide()
            LiveToast.show(.inviteCancelled)
        }
    }

    private func show() {
        let skin = store.skin
        actionButton.backgroundColor = skin.mid
        iconView.tintColor = skin.light
        animationToken += 1
        layer.removeAllAnimations()
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
        guard kind == .requesting else { return }
        autoHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        autoHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoHideDelay, execute: work)
    }

    private func hide() {
        autoHideWork?.cancel()
        autoHideWork = nil
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
    static var inviteCancelled: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.comic.invite_cancelled")
    }
    static var retract: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.retract") }
    static var retractTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.retract_title") }
}
