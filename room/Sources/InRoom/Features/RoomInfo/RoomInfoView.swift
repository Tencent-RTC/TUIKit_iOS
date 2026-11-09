import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomInfoView: UIControl {

    private let roomID: String

    private let nameLabel = UILabel()
    private let separator = UIView()
    private let elapsedLabel = UILabel()
    private let caretView = UIImageView()
    private var roomName = ""
    private var elapsed = "00:00"

    private var cancellableSet = Set<AnyCancellable>()

    private static let minutesPerHour = 60

    private var elapsedBaseTimeMillis: Double = 0
    private var elapsedRoomID: String?
    private var elapsedTimer: Timer?
    private var infoPopup: RoomInfoPopup?

    private(set) var isDetailOpen = false {
        didSet {
            guard oldValue != isDetailOpen else { return }
            UIView.animate(withDuration: 0.25) {
                self.caretView.transform = self.isDetailOpen ? CGAffineTransform(rotationAngle: .pi) : .identity
            }
            caretView.image = RoomKitResources.image(named: isDetailOpen ? "roomkit_icon_collapse_accent" : "roomkit_icon_collapse_tertiary")
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            applyTheme()
        }
    }

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)

        nameLabel.lineBreakMode = .byTruncatingTail
        caretView.image = RoomKitResources.image(named: "roomkit_icon_collapse_tertiary")
        caretView.contentMode = .scaleAspectFit

        [nameLabel, separator, elapsedLabel, caretView].forEach {
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        elapsedLabel.setContentHuggingPriority(.required, for: .horizontal)
        elapsedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)

        setupLayout()
        layer.cornerRadius = 8
        applyTheme()
        setupBindings()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        guard infoPopup == nil, let roomID = RoomStore.shared.state.value.currentRoom?.roomID else { return }
        let popup = RoomInfoPopup(roomID: roomID)
        popup.onDismiss = { [weak self] in
            self?.infoPopup = nil
            self?.isDetailOpen = false
        }
        infoPopup = popup
        isDetailOpen = true
        popup.show(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopElapsedTimer()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
            startElapsedTimerIfNeeded()
        } else {
            stopElapsedTimer()
        }
    }

    private func setupLayout() {
        nameLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(6)
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
            $0.width.lessThanOrEqualTo(124)
        }
        separator.snp.makeConstraints {
            $0.leading.equalTo(nameLabel.snp.trailing).offset(7)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(1)
            $0.height.equalTo(12)
        }
        elapsedLabel.snp.makeConstraints {
            $0.leading.equalTo(separator.snp.trailing).offset(7)
            $0.centerY.equalToSuperview()
            $0.trailing.equalTo(caretView.snp.leading).offset(-2)
        }
        caretView.snp.makeConstraints {
            $0.size.equalTo(11)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-6)
        }
    }

    private func setupBindings() {
        RoomStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] room in

                guard let self, let room, !room.isEmpty, room.roomID == self.roomID else { return }
                if self.roomName != room.roomName {
                    self.roomName = room.roomName
                    self.applyTexts()
                }

                if self.elapsedRoomID != room.roomID {
                    self.elapsedRoomID = room.roomID
                    self.elapsedBaseTimeMillis = Self.normalizeToMillis(room.createTime)
                }
                self.tickElapsed()
            }
            .store(in: &cancellableSet)
    }

    private func startElapsedTimerIfNeeded() {
        guard elapsedTimer == nil else { return }
        tickElapsed()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickElapsed()
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func tickElapsed() {
        guard elapsedBaseTimeMillis > 0 else { return }
        let seconds = max(0, Int((Date().timeIntervalSince1970 * 1000 - elapsedBaseTimeMillis) / 1000))
        let text = Self.formatElapsed(seconds)
        guard elapsed != text else { return }
        elapsed = text
        applyTexts()
    }

    private static func normalizeToMillis(_ raw: Int) -> Double {
        guard raw > 0 else { return 0 }
        return raw >= 1_000_000_000_000 ? Double(raw) : Double(raw) * 1000
    }

    private static func formatElapsed(_ seconds: Int) -> String {
        let minutes = seconds / 60
        guard minutes >= Self.minutesPerHour else {
            return String(format: "%02d:%02d", minutes, seconds % 60)
        }
        return String(format: "%02d:%02d:%02d",
                      minutes / Self.minutesPerHour,
                      minutes % Self.minutesPerHour,
                      seconds % 60)
    }

    private func applyTheme() {
        backgroundColor = isHighlighted ? UIColor.roomKitBgPress : .clear
        separator.backgroundColor = UIColor.roomKitSeparator
        applyTexts()
    }

    private func applyTexts() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        nameLabel.attributedText = NSAttributedString(string: roomName, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.roomKitFgPrimary,
            .kern: -0.156,
            .paragraphStyle: paragraph,
        ])
        elapsedLabel.attributedText = NSAttributedString(string: elapsed, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.roomKitFgSecondary,
            .kern: 0.26,
        ])
        setNeedsLayout()
    }
}
