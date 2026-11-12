import AtomicXCore
import Combine
import SnapKit
import UIKit

final class TopBarView: UIView {

    var onInviteTap: (() -> Void)?

    private let pipButton = UIButton(type: .system)
    private let timerLabel = UILabel()
    private let inviteButton = UIButton(type: .system)
    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        for (button, icon) in [(pipButton, "callkit_icon_pip"), (inviteButton, "callkit_icon_adduser")] {
            button.setImage(CallKitResources.image(named: icon)?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.tintColor = .white
        }
        pipButton.addAction(UIAction { _ in
            CallKitToast.show(CallKitResources.text("callkit.call.minimize_unsupported"))
        }, for: .touchUpInside)
        inviteButton.addAction(UIAction { [weak self] _ in self?.onInviteTap?() }, for: .touchUpInside)

        timerLabel.font = CallKitTheme.timerFont
        timerLabel.textColor = .white
        timerLabel.textAlignment = .center
        timerLabel.alpha = 0

        [pipButton, timerLabel, inviteButton].forEach { addSubview($0) }
        pipButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(CallKitTheme.topBarButtonSize)
        }
        inviteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(CallKitTheme.topBarButtonSize)
        }
        timerLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.activeCall.duration })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds in self?.timerLabel.text = Self.formatDuration(max(0, Int(seconds))) }
            .store(in: &cancellables)

        pipButton.isHidden = !CallKitConfig.shared.enableFloatWindow
    }

    func handleConnected() {
        timerLabel.alpha = 1
    }

    private static func formatDuration(_ total: Int) -> String {
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    func setImmersive(_ immersive: Bool) {
        pipButton.isHidden = !CallKitConfig.shared.enableFloatWindow
        inviteButton.isHidden = false
    }
}
