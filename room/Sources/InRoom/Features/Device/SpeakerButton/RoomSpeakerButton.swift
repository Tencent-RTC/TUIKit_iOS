import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomSpeakerButton: UIControl {

    private let iconView = UIImageView()
    private var popup: RoomSpeakerPopup?
    private var cancellableSet = Set<AnyCancellable>()

    private var audioOutput: AudioRoute = .speakerphone {
        didSet {
            guard oldValue != audioOutput else { return }
            applyIcon()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        }
    }

    init() {
        super.init(frame: .zero)
        iconView.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        audioOutput = DeviceStore.shared.state.value.currentAudioRoute
        applyIcon()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { applyTheme() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        iconView.frame = CGRect(
            x: (bounds.width - 20) / 2,
            y: (bounds.height - 20) / 2,
            width: 20,
            height: 20
        )
    }

    private func setupBindings() {
        DeviceStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \DeviceState.currentAudioRoute))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.audioOutput = $0 }
            .store(in: &cancellableSet)
    }

    @objc private func handleTap() {
        guard popup == nil else { return }
        let popup = RoomSpeakerPopup(current: audioOutput)
        popup.onSelect = { [weak self] output in
            self?.popup = nil
            DeviceStore.shared.setAudioRoute(output)
        }
        popup.onDismiss = { [weak self] in self?.popup = nil }
        self.popup = popup
        popup.show(in: self)
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgHover
    }

    private func applyIcon() {
        iconView.image = RoomKitResources.image(
            named: audioOutput == .speakerphone ? "roomkit_icon_speaker_primary" : "roomkit_icon_earpiece_primary"
        )
    }
}
