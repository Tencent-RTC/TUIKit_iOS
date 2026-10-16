import Kingfisher
import UIKit
import SnapKit

/// Renders normal gifts in at most two independent channels. The merge key is
/// always `senderID + giftID`.
final class LiveGiftEntryView: UIView {
    private enum Constants {
        static let maximumChannelCount = 2
        static let itemHeight: CGFloat = 44
        static let channelSpacing: CGFloat = 4
        static let holdDuration: TimeInterval = 2
        static let enterDuration: TimeInterval = 0.52
        static let exitDuration: TimeInterval = 0.32
    }

    private final class Entry {
        let key: String
        let view = LiveGiftEntryItemView()
        var gift: LiveGiftEvent
        var count: UInt
        var expiration: DispatchWorkItem?
        var animator: UIViewPropertyAnimator?
        var isLeaving = false

        init(gift: LiveGiftEvent, count: UInt) {
            key = gift.comboKey
            self.gift = gift
            self.count = count
        }

        func cancelScheduledWork() {
            expiration?.cancel()
            expiration = nil
            animator?.stopAnimation(true)
            animator = nil
        }
    }

    private struct PendingEntry {
        let key: String
        var gift: LiveGiftEvent
        var count: UInt
    }

    private let stackView = UIStackView()
    private var activeEntries: [Entry] = []
    private var queue: [PendingEntry] = []
    private var generation = UUID()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func enqueue(_ gift: LiveGiftEvent) {
        guard gift.count > 0 else { return }

        if let active = activeEntries.first(where: { $0.key == gift.comboKey && !$0.isLeaving }) {
            active.gift = gift
            active.count = Self.addingWithoutOverflow(active.count, gift.count)
            active.view.updateCount(active.count, animated: true)
            scheduleExpiration(for: active)
            return
        }

        if let leaving = activeEntries.first(where: { $0.key == gift.comboKey && $0.isLeaving }) {
            finish(leaving)
        }

        if let index = queue.firstIndex(where: { $0.key == gift.comboKey }) {
            queue[index].gift = gift
            queue[index].count = Self.addingWithoutOverflow(queue[index].count, gift.count)
            return
        }

        let pending = PendingEntry(key: gift.comboKey, gift: gift, count: gift.count)
        if activeEntries.count < Constants.maximumChannelCount {
            activate(pending)
        } else {
            queue.append(pending)
        }
    }

    func reset() {
        generation = UUID()
        activeEntries.forEach {
            $0.cancelScheduledWork()
            $0.view.prepareForRemoval()
            $0.view.removeFromSuperview()
        }
        activeEntries.removeAll()
        queue.removeAll()
        isHidden = true
    }

    private func configureUI() {
        isHidden = true
        isUserInteractionEnabled = false
        clipsToBounds = false

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = Constants.channelSpacing
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func activate(_ pending: PendingEntry) {
        let gift = pending.gift
        let entry = Entry(gift: gift, count: pending.count)
        activeEntries.append(entry)
        stackView.addArrangedSubview(entry.view)
        entry.view.snp.makeConstraints { make in
            make.height.equalTo(Constants.itemHeight)
        }
        entry.view.bind(gift, count: pending.count)

        isHidden = false
        layoutIfNeeded()
        entry.view.alpha = 0
        entry.view.transform = CGAffineTransform(translationX: -(bounds.width + 12), y: 0)

        UIView.animate(
            withDuration: 0.26,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            entry.view.alpha = 1
        }
        let animator = UIViewPropertyAnimator(
            duration: Constants.enterDuration,
            controlPoint1: CGPoint(x: 0.16, y: 0.82),
            controlPoint2: CGPoint(x: 0.22, y: 1)
        ) {
            entry.view.transform = .identity
        }
        entry.animator = animator
        animator.addCompletion { [weak entry] _ in
            entry?.animator = nil
        }
        animator.startAnimation()
        scheduleExpiration(for: entry)
    }

    private func scheduleExpiration(for entry: Entry) {
        entry.expiration?.cancel()
        let currentGeneration = generation
        let work = DispatchWorkItem { [weak self, weak entry] in
            guard let self, let entry, self.generation == currentGeneration else { return }
            self.dismiss(entry)
        }
        entry.expiration = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.holdDuration, execute: work)
    }

    private func dismiss(_ entry: Entry) {
        guard activeEntries.contains(where: { $0 === entry }), !entry.isLeaving else { return }
        entry.isLeaving = true
        entry.expiration = nil
        entry.animator?.stopAnimation(false)
        entry.animator?.finishAnimation(at: .current)
        entry.animator = nil

        UIView.animate(
            withDuration: Constants.exitDuration,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
        ) {
            entry.view.alpha = 0
            entry.view.transform = CGAffineTransform(translationX: -24, y: 0)
        } completion: { [weak self, weak entry] _ in
            guard let self, let entry else { return }
            self.finish(entry)
        }
    }

    private func finish(_ entry: Entry) {
        guard let index = activeEntries.firstIndex(where: { $0 === entry }) else { return }
        entry.cancelScheduledWork()
        entry.view.prepareForRemoval()
        stackView.removeArrangedSubview(entry.view)
        entry.view.removeFromSuperview()
        activeEntries.remove(at: index)

        if !queue.isEmpty {
            activate(queue.removeFirst())
        } else if activeEntries.isEmpty {
            isHidden = true
        }
    }

    private static func addingWithoutOverflow(_ lhs: UInt, _ rhs: UInt) -> UInt {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt.max : value
    }
}

private final class LiveGiftEntryItemView: UIView {
    private let capsuleView = UIView()
    private let avatarView = UIImageView()
    private let senderLabel = UILabel()
    private let detailLabel = UILabel()
    private let giftImageView = UIImageView()
    private let giftFallbackView = LiveGiftFallbackView()
    private let multiplierLabel = UILabel()
    private let countLabel = UILabel()
    private var representedGiftURL = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ gift: LiveGiftEvent, count: UInt) {
        let senderName = gift.senderName.isEmpty ? gift.senderID : gift.senderName
        senderLabel.text = senderName
        detailLabel.text = String(
            format: LiveKitResources.localizedString("tuilivekit.pusher.gift.sent"),
            gift.name
        )
        updateCount(count, animated: false)
        loadAvatar(gift.senderAvatarURL)
        loadGiftImage(gift.iconURL)
    }

    func updateCount(_ count: UInt, animated: Bool) {
        countLabel.text = String(count)
        guard animated else { return }
        layer.removeAnimation(forKey: "gift-count-bump")
        UIView.animateKeyframes(
            withDuration: 0.22,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.45) {
                self.countLabel.transform = CGAffineTransform(scaleX: 1.24, y: 1.24)
                self.countLabel.textColor = GiftEntryStyle.countHighlight
            }
            UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.55) {
                self.countLabel.transform = .identity
                self.countLabel.textColor = .white
            }
        }
    }

    func prepareForRemoval() {
        avatarView.kf.cancelDownloadTask()
        giftImageView.kf.cancelDownloadTask()

        layer.removeAllAnimations()
        countLabel.layer.removeAllAnimations()
    }

    private func configureUI() {
        isUserInteractionEnabled = false
        clipsToBounds = false

        capsuleView.backgroundColor = GiftEntryStyle.capsuleBackground
        capsuleView.layer.cornerRadius = 22
        addSubview(capsuleView)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 19
        avatarView.layer.borderWidth = 1
        avatarView.layer.borderColor = GiftEntryStyle.avatarBorderAndDetail.cgColor
        capsuleView.addSubview(avatarView)

        senderLabel.textColor = .white
        senderLabel.font = LiveGiftEntryItemViewTypography.senderFont
        senderLabel.lineBreakMode = .byTruncatingTail
        detailLabel.textColor = GiftEntryStyle.avatarBorderAndDetail
        detailLabel.font = LiveGiftEntryItemViewTypography.detailFont
        detailLabel.lineBreakMode = .byTruncatingTail
        [senderLabel, detailLabel].forEach(capsuleView.addSubview)

        giftImageView.contentMode = .scaleAspectFit
        giftImageView.clipsToBounds = false
        capsuleView.addSubview(giftImageView)
        capsuleView.addSubview(giftFallbackView)

        multiplierLabel.text = "×"
        multiplierLabel.textColor = .white
        multiplierLabel.font = LiveGiftEntryItemViewTypography.multiplierFont
        multiplierLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(multiplierLabel)

        countLabel.textColor = .white
        countLabel.font = LiveGiftEntryItemViewTypography.countFont
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.6
        countLabel.layer.shadowColor = UIColor.black.cgColor
        countLabel.layer.shadowOpacity = 0.55
        countLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        countLabel.layer.shadowRadius = 4
        addSubview(countLabel)

        capsuleView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.equalTo(178).priority(.high)
            make.width.lessThanOrEqualToSuperview().offset(-56)
            make.height.equalTo(44)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(3)
            make.centerY.equalToSuperview()
            make.size.equalTo(38)
        }
        giftImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(5)
            make.centerY.equalToSuperview()
            make.size.equalTo(37)
        }
        giftFallbackView.snp.makeConstraints { make in
            make.center.equalTo(giftImageView)
            make.size.equalTo(34)
        }
        senderLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(7)
            make.trailing.equalTo(giftImageView.snp.leading).offset(-2)
            make.bottom.equalTo(capsuleView.snp.centerY).offset(-1)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(senderLabel)
            make.top.equalTo(capsuleView.snp.centerY).offset(1)
        }
        multiplierLabel.snp.makeConstraints { make in
            make.leading.equalTo(capsuleView.snp.trailing).offset(4)
            make.centerY.equalToSuperview().offset(2)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(multiplierLabel.snp.trailing).offset(2)
            make.trailing.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview().offset(1)
            make.width.greaterThanOrEqualTo(28)
        }
    }

    private func loadAvatar(_ urlString: String) {
        avatarView.kf.cancelDownloadTask()
        let placeholder = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        avatarView.kf.setImage(with: URL(string: urlString), placeholder: placeholder)
    }

    private func loadGiftImage(_ urlString: String) {
        giftImageView.kf.cancelDownloadTask()
        representedGiftURL = urlString
        giftImageView.image = nil
        giftFallbackView.isHidden = false
        giftImageView.kf.setImage(with: URL(string: urlString), placeholder: giftImageView.image) { [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            let image = try? result.get().image
            guard let self, self.representedGiftURL == urlString else { return }
            self.giftFallbackView.isHidden = image != nil
        }
    }
}

private final class LiveGiftFallbackView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [
            LiveTheme.Color.brandBlue.cgColor,
            GiftEntryStyle.giftGradientEnd.cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)

        let label = UILabel()
        label.text = LiveKitResources.localizedString("tuilivekit.pusher.gift.fallback")
        label.textColor = .white
        label.font = LiveGiftFallbackViewTypography.labelFont
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 12
        layer.masksToBounds = true
        gradient.frame = bounds
        gradient.cornerRadius = 12
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftEntryStyle {
    static let countHighlight: UIColor = UIColor(red: 0.47, green: 0.85, blue: 1, alpha: 1)
    static let capsuleBackground: UIColor = UIColor(red: 0.031, green: 0.039, blue: 0.059, alpha: 0.28)
    static let avatarBorderAndDetail: UIColor = UIColor.white.withAlphaComponent(0.72)
    static let giftGradientEnd: UIColor = UIColor(red: 0.51, green: 0.35, blue: 0.96, alpha: 1)
}

private enum LiveGiftEntryItemViewTypography {
    static let senderFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let detailFont: UIFont = UIFont.systemFont(ofSize: 9)
    static let multiplierFont: UIFont = UIFont.systemFont(ofSize: 17, weight: .heavy)
    static let countFont: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .heavy)
}

private enum LiveGiftFallbackViewTypography {
    static let labelFont: UIFont = UIFont.systemFont(ofSize: 17, weight: .heavy)
}
