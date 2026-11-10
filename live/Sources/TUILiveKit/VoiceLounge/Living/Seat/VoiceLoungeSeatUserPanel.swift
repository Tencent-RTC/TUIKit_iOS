import AtomicXCore
import SnapKit
import UIKit

final class VoiceLoungeSeatUserPanel: VoiceLoungeMenuPanel {
    private let liveID: String
    private let coGuest: VoiceLoungeCoGuestStore
    private let muteCache: VoiceLoungeMuteCache

    init(liveID: String, coGuest: VoiceLoungeCoGuestStore, muteCache: VoiceLoungeMuteCache) {
        self.liveID = liveID
        self.coGuest = coGuest
        self.muteCache = muteCache
        super.init(frame: .zero)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(userID: String, name: String) {
        guard !userID.isEmpty,
            let user = LiveSeatStore.create(liveID: liveID).state.value.seatList.first(where: {
                $0.userInfo.userID == userID
            })?.userInfo
        else { return }
        show(title: name, actions: [micAction(for: user), kickAction(userID: userID), adminAction(for: user)])
    }

    private func micAction(for user: SeatUserInfo) -> Action {
        let userID = user.userID
        guard muteCache.isMicOff(user) else {
            return .init(title: .disableMic) { [weak self] in
                let onSuccess: () -> Void = { [weak self] in self?.muteCache.set(true, for: userID) }
                self?.performSeatAction(successText: .micDisabled, onSuccess: onSuccess) {
                    $0.closeRemoteMicrophone(userID: userID, completion: $1)
                }
            }
        }
        return .init(title: .enableMic) { [weak self] in
            self?.enableMicrophone(userID: userID, isLocked: !user.allowOpenMicrophone)
        }
    }

    private func enableMicrophone(userID: String, isLocked: Bool) {
        let finish: () -> Void = { [weak self] in
            self?.muteCache.set(false, for: userID)
            self?.coGuest.requestOpenMicrophone(userID: userID)
        }
        guard isLocked else {
            finish()
            LiveToast.show(.micEnabled)
            return
        }
        performSeatAction(successText: .micEnabled, onSuccess: finish) {
            $0.openRemoteMicrophone(userID: userID, policy: .unlockOnly, completion: $1)
        }
    }

    private func kickAction(userID: String) -> Action {
        .init(title: .kick, isDestructive: true) { [weak self] in
            self?.performSeatAction(successText: .kicked) { $0.kickUserOutOfSeat(userID: userID, completion: $1) }
        }
    }

    private func adminAction(for user: SeatUserInfo) -> Action {
        let userID = user.userID
        let audienceStore = LiveAudienceStore.create(liveID: liveID)
        let isAdmin = audienceStore.state.value.adminList.contains { $0.userID == userID } || user.role == .admin
        let successText: String = isAdmin ? .adminRevoked : .adminSet
        return .init(title: isAdmin ? .revokeAdmin : .setAdmin) { [liveID] in
            let completion = Self.completion(successText: successText)
            let store = LiveAudienceStore.create(liveID: liveID)
            if isAdmin {
                store.revokeAdministrator(userID: userID, completion: completion)
            } else {
                store.setAdministrator(userID: userID, completion: completion)
            }
        }
    }

    private func performSeatAction(
        successText: String, onSuccess: (() -> Void)? = nil,
        action: (LiveSeatStore, @escaping CompletionClosure) -> Void
    ) { action(LiveSeatStore.create(liveID: liveID), Self.completion(successText: successText, onSuccess: onSuccess)) }

    private static func completion(successText: String, onSuccess: (() -> Void)? = nil) -> CompletionClosure {
        { result in
            Task { @MainActor in
                switch result {
                case .success:
                    LiveToast.show(successText)
                    onSuccess?()
                case .failure(let error): LiveToast.show(VoiceLoungeErrorText.coGuest(error))
                }
            }
        }
    }
}

private extension String {
    static var disableMic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.disable_mic") }
    static var micDisabled: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.mic_disabled") }
    static var enableMic: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.enable_mic") }
    static var micEnabled: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.mic_enabled") }
    static var kick: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.kick") }
    static var kicked: String { LiveKitResources.localizedString("tuilivekit.voiceroom.comic.kicked") }
    static var setAdmin: String { LiveKitResources.localizedString("tuilivekit.voiceroom.admin.set") }
    static var adminSet: String { LiveKitResources.localizedString("tuilivekit.voiceroom.admin.set_done") }
    static var revokeAdmin: String { LiveKitResources.localizedString("tuilivekit.voiceroom.admin.revoke") }
    static var adminRevoked: String { LiveKitResources.localizedString("tuilivekit.voiceroom.admin.revoked") }
}

class VoiceLoungeMenuPanel: BottomSheetView {
    struct Action {
        let title: String
        var isDestructive = false
        let handler: () -> Void
    }

    private let stackView = UIStackView()
    private var actionCount = 0

    private enum Layout {
        static let rowHeight: CGFloat = 52
        static let contentTop: CGFloat = 70
        static let bottomPadding: CGFloat = 28
        static let horizontalInset: CGFloat = 24
    }

    override var sheetHeight: CGFloat {
        Layout.contentTop + CGFloat(actionCount) * Layout.rowHeight + Layout.bottomPadding
            + (window?.safeAreaInsets.bottom ?? 0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(title: String, actions: [Action]) {
        sheetTitle = title
        actionCount = actions.count
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        actions.forEach { action in
            stackView.addArrangedSubview(
                makeRow(title: action.title, isDestructive: action.isDestructive) { [weak self] in
                    self?.dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { action.handler() }
                })
        }
        updateSheetHeight(animated: false)
        present()
    }

    private func setupViews() { contentView.addSubview(stackView) }

    private func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.top.equalToSuperview().offset(Layout.contentTop)
        }
    }

    private func setupStyles() {
        stackView.axis = .vertical
        stackView.spacing = 0
    }

    private func setupBindings() {}

    private func makeRow(title: String, isDestructive: Bool, handler: @escaping () -> Void) -> UIView {
        let row = UIControl()
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17)
        label.textColor =
            isDestructive
            ? UIColor(red: 1.0, green: 0.36, blue: 0.42, alpha: 1) : UIColor.white.withAlphaComponent(0.82)
        label.isUserInteractionEnabled = false
        row.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        row.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        row.addAction(UIAction { [weak label] _ in label?.alpha = 0.5 }, for: [.touchDown, .touchDragEnter])
        row.addAction(
            UIAction { [weak label] _ in label?.alpha = 1 },
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        row.snp.makeConstraints { $0.height.equalTo(Layout.rowHeight) }
        return row
    }
}
