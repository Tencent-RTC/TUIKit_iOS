import Kingfisher
import AtomicXCore
import Combine
import SnapKit
import UIKit

final class RequestingPanel: BottomSheetView {
    private static let applyErrorMessageKeys: [Int: String] = [
        100_004: "tuilivekit.player.coguest.error.room_not_exist",
        100_005: "tuilivekit.player.coguest.error.not_room_member",
        100_200: "tuilivekit.player.coguest.error.seat_locked",
        100_202: "tuilivekit.player.coguest.error.already_requesting",
        100_203: "tuilivekit.player.coguest.error.already_on_seat",
        100_205: "tuilivekit.player.coguest.error.seat_full",
        100_210: "tuilivekit.player.coguest.error.seat_occupied",
        100_211: "tuilivekit.player.coguest.error.not_supported",
    ]

    var onDismiss: (() -> Void)?
    var onRequestSettings: (() -> Void)?

    override var sheetHeight: CGFloat { 221 }
    override var isDismissibleByTappingOutside: Bool { true }

    override func sheetDidDismiss() {
        onDismiss?()
    }

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()

    private let actionsContainer = UIImageView()
    private let voiceButton = UIButton(type: .custom)
    private let videoButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .custom)
    private var appliedAvatarURL: String?
    private var liveID = ""
    private let uiState: CurrentValueSubject<CoGuestStatus, Never>
    private let openCameraAfterAccept: CurrentValueSubject<Bool, Never>
    private let updateUiState: (CoGuestStatus) -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        uiState: CurrentValueSubject<CoGuestStatus, Never>,
        openCameraAfterAccept: CurrentValueSubject<Bool, Never>,
        updateUiState: @escaping (CoGuestStatus) -> Void
    ) {
        self.uiState = uiState
        self.openCameraAfterAccept = openCameraAfterAccept
        self.updateUiState = updateUiState
        super.init(frame: .zero)
        configureUI()
        uiState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyUiState(state) }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ liveInfo: LiveInfo) {
        liveID = liveInfo.liveID
        let owner = liveInfo.liveOwner
        let rawName = owner.userName.isEmpty ? owner.userID : owner.userName
        nameLabel.text = rawName.count > 15 ? String(rawName.prefix(15)) + "…" : rawName
        let requestedURL = owner.avatarURL
        guard appliedAvatarURL != requestedURL else { return }
        appliedAvatarURL = requestedURL
        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: URL(string: requestedURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    func applyForSeat(requestVideo: Bool) {
        guard uiState.value == .idle, !liveID.isEmpty else { return }
        openCameraAfterAccept.send(requestVideo)
        let extraInfo = requestVideo ? "{\"mediaType\":\"video\"}" : "{\"mediaType\":\"audio\"}"
        CoGuestStore.create(liveID: liveID)
            .applyForSeat(seatIndex: -1, timeout: 0, extraInfo: extraInfo) { [weak self] result in
                Task { @MainActor in
                    guard let self, case let .failure(error) = result else { return }
                    self.openCameraAfterAccept.send(true)
                    LiveKitLog.error("[PlayerCoGuest] applyForSeat failed: code=\(error.code), message=\(error.message)")
                    let key = Self.applyErrorMessageKeys[error.code]
                        ?? "tuilivekit.player.coguest.error.apply_failed"
                    LiveToast.show(LiveKitResources.localizedString(key))
                    self.updateUiState(.idle)
                }
            }
        updateUiState(.requesting)
    }

    private func applyUiState(_ state: CoGuestStatus) {
        let showCancel = state == .requesting
        actionsContainer.isHidden = showCancel
        voiceButton.isHidden = showCancel
        videoButton.isHidden = showCancel
        cancelButton.isHidden = !showCancel
    }

    private func configureUI() {
        updateSheetHeight(animated: false)

        let voiceButton = self.voiceButton
        let videoButton = self.videoButton

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 29
        avatarView.layer.borderWidth = 1
        avatarView.layer.borderColor = UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 0.82).cgColor

        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textAlignment = .center

        [voiceButton, videoButton].forEach { button in
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.backgroundColor = .clear
        }
        voiceButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.coguest.voice"), for: .normal)
        videoButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.coguest.video"), for: .normal)
        voiceButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        videoButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        voiceButton.addAction(UIAction { [weak self] _ in
            self?.applyForSeat(requestVideo: false)
        }, for: .touchUpInside)
        videoButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.uiState.value == .idle {
                self.onRequestSettings?()
            }
        }, for: .touchUpInside)

        actionsContainer.image = LiveKitResources.image(named: "livekit_player_coguest_requesting_button_bg")
        actionsContainer.contentMode = .scaleToFill
        actionsContainer.isUserInteractionEnabled = true
        actionsContainer.addSubview(voiceButton)
        actionsContainer.addSubview(videoButton)

        cancelButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.coguest.cancel_application"), for: .normal)
        cancelButton.setTitleColor(UIColor.white.withAlphaComponent(0.72), for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        cancelButton.layer.cornerRadius = 11
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.cancelApplication()
        }, for: .touchUpInside)

        [avatarView, nameLabel, actionsContainer, cancelButton].forEach(contentView.addSubview)
        avatarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(32)
            make.width.height.equalTo(58)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(avatarView.snp.bottom).offset(10)
            make.height.equalTo(22)
        }
        actionsContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(141)
            make.height.equalTo(40)
        }
        voiceButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(videoButton)
        }
        videoButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.equalTo(voiceButton.snp.trailing)
        }
        cancelButton.snp.makeConstraints { make in
            make.edges.equalTo(actionsContainer)
        }
    }

    private func cancelApplication() {
        guard uiState.value == .requesting, !liveID.isEmpty else { return }
        CoGuestStore.create(liveID: liveID).cancelApplication { [weak self] result in
            Task { @MainActor in
                if case .success = result {
                    self?.openCameraAfterAccept.send(true)
                }
            }
        }
        updateUiState(.idle)
    }
}
