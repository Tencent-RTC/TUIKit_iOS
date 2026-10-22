import UIKit
import SnapKit
import AtomicXCore

final class RoomParticipantMoreSheet: UIView {

    private weak var popup: RoomPopup?
    private let roomID: String
    private let participantStore: RoomParticipantStore

    private let chatMuteRow = UIButton(type: .custom)
    private let shareRow = UIButton(type: .custom)

    init(roomID: String) {
        self.roomID = roomID
        participantStore = RoomParticipantStore.create(roomID: roomID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(chatMuteRow)
        addSubview(shareRow)
    }

    private func setupConstraints() {
        chatMuteRow.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.height.equalTo(42)
        }
        shareRow.snp.makeConstraints {
            $0.top.equalTo(chatMuteRow.snp.bottom)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.height.equalTo(42)
            $0.bottom.equalToSuperview().offset(-24)
        }
    }

    private func setupStyles() {
        backgroundColor = UIColor.roomKitBgSurface
        [chatMuteRow, shareRow].forEach { row in
            row.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            row.contentHorizontalAlignment = .leading
            row.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        }
    }


    func show(room: RoomInfo, in host: UIView) {
        bindChatMute(chatMuted: room.isAllMessageDisabled)
        bindShare(shareDisabled: room.isAllScreenShareDisabled)

        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        self.snp.makeConstraints { $0.edges.equalToSuperview() }
        self.popup = popup
        popup.show(in: host)
    }

    private func bindChatMute(chatMuted: Bool) {
        chatMuteRow.setTitle(
            chatMuted ? .participantsUnmuteAllChat : .participantsMuteAllChat,
            for: .normal
        )
        chatMuteRow.setTitleColor(
            chatMuted ? UIColor.roomKitAccent : UIColor.roomKitFgPrimary,
            for: .normal
        )
        chatMuteRow.addAction(.init(handler: { [weak self] _ in
            guard let self else { return }
            popup?.dismiss()
            participantStore.disableAllMessages(disable: !chatMuted) { result in
                switch result {
                case .success:
                    RoomToast.show(chatMuted ? .participantsUnmuteAllChatDone : .participantsMuteAllChatDone)
                case .failure(let error):
                    ErrorLocalized.showError(code: error.code, message: error.message)
                }
            }
        }), for: .touchUpInside)
    }

    private func bindShare(shareDisabled: Bool) {
        shareRow.setTitle(
            shareDisabled ? .participantsShareEveryone : .participantsShareOwnerOnly,
            for: .normal
        )
        shareRow.setTitleColor(
            shareDisabled ? UIColor.roomKitAccent : UIColor.roomKitFgPrimary,
            for: .normal
        )
        shareRow.addAction(.init(handler: { [weak self] _ in
            guard let self else { return }
            popup?.dismiss()
            participantStore.disableAllDevices(device: .screenShare, disable: !shareDisabled) { result in
                switch result {
                case .success:
                    RoomToast.show(shareDisabled ? .participantsShareEveryoneDone : .participantsShareOwnerOnlyDone)
                case .failure(let error):
                    ErrorLocalized.showError(code: error.code, message: error.message)
                }
            }
        }), for: .touchUpInside)
    }
}

private extension String {
    static var participantsMuteAllChat: String { RoomKitResources.localizedString("roomkit.participants.mute_all_chat") }
    static var participantsUnmuteAllChat: String { RoomKitResources.localizedString("roomkit.participants.unmute_all_chat") }
    static var participantsMuteAllChatDone: String { RoomKitResources.localizedString("roomkit.participants.mute_all_chat_done") }
    static var participantsUnmuteAllChatDone: String { RoomKitResources.localizedString("roomkit.participants.unmute_all_chat_done") }
    static var participantsShareEveryone: String { RoomKitResources.localizedString("roomkit.participants.share_everyone") }
    static var participantsShareOwnerOnly: String { RoomKitResources.localizedString("roomkit.participants.share_owner_only") }
    static var participantsShareEveryoneDone: String { RoomKitResources.localizedString("roomkit.participants.share_everyone_done") }
    static var participantsShareOwnerOnlyDone: String { RoomKitResources.localizedString("roomkit.participants.share_owner_only_done") }
}
