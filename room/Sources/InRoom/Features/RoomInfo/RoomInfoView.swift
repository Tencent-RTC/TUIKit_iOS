import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomInfoView: UIControl {

    private let nameLabel = UILabel()
    private let separator = UIView()
    private let elapsedLabel = UILabel()
    private let caretView = UIImageView()
    private let contentStack = UIStackView()
    private let mainRow = UIStackView()
    private let secondRow = UIStackView()
    private var roomName = ""
    private var elapsed = "00:00"

    private var isTimeWrapped = false

    var availableWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            guard abs(oldValue - availableWidth) > 0.5 else { return }
            setNeedsLayout()
        }
    }

    private var contentTopConstraint: Constraint?
    private var contentBottomConstraint: Constraint?
    private var caretTrailingConstraint: Constraint?
    private var widthLimitConstraint: Constraint?

    private var cancellableSet = Set<AnyCancellable>()

    private static let minutesPerHour = 60

    private static let paddingStart: CGFloat = 6
    private static let paddingEnd: CGFloat = 6
    private static let stackedPaddingEnd: CGFloat = 4
    private static let verticalInset: CGFloat = 4
    private static let stackedInset: CGFloat = 1
    private static let gap: CGFloat = 7
    private static let separatorWidth: CGFloat = 1
    private static let separatorHeight: CGFloat = 12
    private static let caretGap: CGFloat = 2
    private static let caretSize: CGFloat = 11
    private static let minWidth: CGFloat = 44
    private static let unlimitedWidth: CGFloat = 10_000

    private var elapsedBaseTimeMillis: Double = 0
    private var elapsedTimer: Timer?

    var isDetailOpen = false {
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

    init() {
        super.init(frame: .zero)

        nameLabel.lineBreakMode = .byTruncatingTail
        caretView.image = RoomKitResources.image(named: "roomkit_icon_collapse_tertiary")
        caretView.contentMode = .scaleAspectFit

        [contentStack, caretView].forEach {
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        elapsedLabel.setContentHuggingPriority(.required, for: .horizontal)
        elapsedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        setupLayout()
        layer.cornerRadius = 8
        applyTheme()
        setupBindings()
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
        mainRow.axis = .horizontal
        mainRow.alignment = .center
        mainRow.spacing = Self.gap
        mainRow.addArrangedSubview(nameLabel)
        mainRow.addArrangedSubview(separator)
        mainRow.addArrangedSubview(elapsedLabel)

        secondRow.axis = .horizontal
        secondRow.alignment = .center
        secondRow.isHidden = true

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .leading
        contentStack.addArrangedSubview(mainRow)
        contentStack.addArrangedSubview(secondRow)

        separator.snp.makeConstraints {
            $0.width.equalTo(Self.separatorWidth)
            $0.height.equalTo(Self.separatorHeight)
        }

        contentStack.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Self.paddingStart)
            $0.trailing.equalTo(caretView.snp.leading).offset(-Self.caretGap)
            contentTopConstraint = $0.top.equalToSuperview().offset(Self.verticalInset).constraint
            contentBottomConstraint = $0.bottom.equalToSuperview().offset(-Self.verticalInset).constraint
        }

        caretView.snp.makeConstraints {
            $0.size.equalTo(Self.caretSize)
            $0.centerY.equalToSuperview()
            caretTrailingConstraint = $0.trailing.equalToSuperview().offset(-Self.paddingEnd).constraint
        }

        snp.makeConstraints {
            widthLimitConstraint = $0.width.lessThanOrEqualTo(Self.unlimitedWidth).constraint
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let limit = max(Self.minWidth, min(effectiveWidth, Self.unlimitedWidth))
        if abs(appliedWidthLimit - limit) > 0.5 {
            appliedWidthLimit = limit
            widthLimitConstraint?.update(offset: limit)
        }
        let oneLine = Self.paddingStart + nameLabel.intrinsicContentSize.width + Self.gap
            + Self.separatorWidth + Self.gap + elapsedLabel.intrinsicContentSize.width
            + Self.caretGap + Self.caretSize + Self.paddingEnd
        setTimeWrapped(oneLine > effectiveWidth)
    }

    private var appliedWidthLimit: CGFloat = 0

    private var effectiveWidth: CGFloat {
        min(availableWidth, window?.bounds.width ?? .greatestFiniteMagnitude)
    }

    private func setTimeWrapped(_ wrapped: Bool) {
        guard wrapped != isTimeWrapped else { return }
        isTimeWrapped = wrapped
        separator.isHidden = wrapped
        if wrapped {
            mainRow.removeArrangedSubview(elapsedLabel)
            secondRow.addArrangedSubview(elapsedLabel)
            secondRow.isHidden = false
        } else {
            secondRow.removeArrangedSubview(elapsedLabel)
            mainRow.addArrangedSubview(elapsedLabel)
            secondRow.isHidden = true
        }
        let inset = wrapped ? Self.stackedInset : Self.verticalInset
        contentTopConstraint?.update(offset: inset)
        contentBottomConstraint?.update(offset: -inset)
        caretTrailingConstraint?.update(offset: wrapped ? -Self.stackedPaddingEnd : -Self.paddingEnd)
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    private func setupBindings() {
        RoomStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] room in
                guard let self, let room, !room.isEmpty else { return }
                if self.roomName != room.roomName {
                    self.roomName = room.roomName
                    self.applyTexts()
                }
                let createTime = Self.normalizeToMillis(room.createTime)
                if createTime > 0, self.elapsedBaseTimeMillis <= 0 || createTime < self.elapsedBaseTimeMillis {
                    self.elapsedBaseTimeMillis = createTime
                }
                self.tickElapsed()
            }
            .store(in: &cancellableSet)
    }

    // MARK: - elapsed

    private func startElapsedTimerIfNeeded() {
        guard elapsedTimer == nil else { return }
        if elapsedBaseTimeMillis <= 0 { elapsedBaseTimeMillis = Date().timeIntervalSince1970 * 1000 }
        elapsed = "00:00"
        applyTexts()
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
        nameLabel.attributedText = NSAttributedString(string: roomName, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.roomKitFgPrimary,
            .kern: -0.13,
        ])
        elapsedLabel.attributedText = NSAttributedString(string: elapsed, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.roomKitFgSecondary,
            .kern: 0.26,
        ])
        setNeedsLayout()
    }
}


