import AtomicXCore
import UIKit

@MainActor final class VoiceLoungeSeatTapHandler {
    private let store: VoiceLoungeSeatStore
    private lazy var seatInvitePanel = VoiceLoungeSeatInvitePanel(liveID: store.liveID, coGuest: store.coGuest)
    private lazy var seatUserPanel: VoiceLoungeSeatUserPanel = {
        let panel = VoiceLoungeSeatUserPanel(store: store)
        panel.onConfirm = { [weak self] title, message, confirmTitle, action in
            self?.onConfirm?(title, message, confirmTitle, action)
        }
        return panel
    }()

    var onSendGift: ((_ userID: String, _ name: String) -> Void)?
    var onConfirm:
        ((_ title: String, _ message: String, _ confirmTitle: String, _ action: @escaping () -> Void) -> Void)?

    init(store: VoiceLoungeSeatStore) { self.store = store }

    var panels: [BottomSheetView] { store.role == .host ? [seatInvitePanel, seatUserPanel] : [] }

    func handleTap(_ index: Int) {
        guard let seat = store.seats.first(where: { $0.index == index }) else { return }
        switch store.role {
        case .host: handleHostTap(seat)
        case .audience: handleAudienceTap(seat)
        }
    }
}

private extension VoiceLoungeSeatTapHandler {
    var coGuest: VoiceLoungeCoGuestStore { store.coGuest }

    var selfUserID: String { LoginStore.shared.state.value.loginUserInfo?.userID ?? "" }

    func handleHostTap(_ seat: VoiceLoungeSeat) {
        guard seat.role != .host else { return }
        switch seat.state {
        case .empty, .locked:
            seatInvitePanel.show(seatIndex: seat.index, isLocked: seat.state == .locked, skin: store.skin)
        case .faded:
            guard !seat.userID.isEmpty else { return }
            seatUserPanel.show(seat: seat)
        case .occupied:
            guard seat.userID != selfUserID else { return }
            seatUserPanel.show(seat: seat)
        }
    }

    func handleAudienceTap(_ seat: VoiceLoungeSeat) {
        switch seat.state {
        case .occupied:
            if seat.userID == selfUserID, coGuest.guestStatus == .onSeat {
                store.promptLeave()
                return
            }
            guard !seat.userID.isEmpty else { return }
            onSendGift?(seat.userID, seat.name)
        case .locked: LiveToast.show(.seatLocked)
        case .faded:
            guard seat.userID == selfUserID else { return }
            if coGuest.promptPendingInvitation() { return }
            switch coGuest.guestStatus {
            case .idle: coGuest.apply(seatIndex: seat.index)
            case .applying: store.promptCancelApplication()
            case .onSeat: break
            }
        case .empty:
            guard seat.role != .host else { return }
            if coGuest.promptPendingInvitation() { return }
            switch coGuest.guestStatus {
            case .idle:
                store.moveAudienceFadedSeat(to: seat.index)
                coGuest.apply(seatIndex: seat.index)
            case .applying:
                store.moveAudienceFadedSeat(to: seat.index)
                coGuest.switchApplication(to: seat.index)
            case .onSeat: LiveToast.show(.alreadyOnSeat)
            }
        }
    }
}

private extension String {
    static var seatLocked: String { LiveKitResources.localizedString("tuilivekit.player.coguest.error.seat_locked") }
    static var alreadyOnSeat: String {
        LiveKitResources.localizedString("tuilivekit.player.coguest.error.already_on_seat")
    }
}
