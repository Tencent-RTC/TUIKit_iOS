import UIKit
import SnapKit
import Kingfisher
import AtomicXCore
import SVGAPlayer

/**
 * Gift animation display component
 *
 * Supports two gift animation effects:
 * 1. Full-screen SVGA animation — when `Gift.resourceURL` has a value, play the full-screen animation with `SVGAPlayer`
 * 2. Barrage slide animation — when `Gift.resourceURL` is empty, the gift slides in from the left, stays briefly, and then disappears (similar to the Douyin live gift barrage)
 *
 * Usage:
 * Overlay `GiftAnimationView` on top of the live video view in full-screen mode, then call `playGiftAnimation`.
 */
class GiftAnimationView: UIView {

    // MARK: - Properties

    /// SVGA parser
    private let svgaParser = SVGAParser()

    /// barrage animation queue (prevents multiple barrage views from overlapping)
    private var barrageAnimationQueue: [GiftBarrageItem] = []
    private var isPlayingBarrage = false

    /// Currently occupied Y-axis slots for barrage display (up to 3 items can be displayed at the same time)
    private var activeSlots: [Int: GiftBarrageItemView] = [:]
    private let maxSlots = 3

    // MARK: - UI Components

    /// full-screen SVGA player
    private lazy var svgaPlayer: SVGAPlayer = {
        let player = SVGAPlayer()
        player.delegate = self
        player.loops = 1
        player.clearsAfterStop = true
        player.isUserInteractionEnabled = false
        player.contentMode = .scaleAspectFit
        return player
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        isUserInteractionEnabled = false
        backgroundColor = .clear

        // SVGA player (full-screen, Defaulthidden)
        addSubview(svgaPlayer)
        svgaPlayer.isHidden = true
        svgaPlayer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Public API

    /// Play a gift animation
    /// - Parameters:
    /// - gift: gift information
    /// - count: gift count
    /// - sender: sender information
    func playGiftAnimation(gift: Gift, count: UInt8, sender: LiveUserInfo) {
        if !gift.resourceURL.isEmpty {
            // If resourceURL exists -> full-screen SVGA animation
            playSVGAAnimation(resourceURL: gift.resourceURL)
        }

        // Display the barrage slide animation regardless of whether an SVGA animation exists
        let item = GiftBarrageItem(gift: gift, count: count, sender: sender)
        enqueueBarrageAnimation(item)
    }

    // MARK: - full-screen SVGA animation

    private func playSVGAAnimation(resourceURL: String) {
        guard let url = URL(string: resourceURL) else { return }

        svgaPlayer.isHidden = false

        svgaParser.parse(with: url) { [weak self] videoItem in
            guard let self = self, let videoItem = videoItem else { return }
            DispatchQueue.main.async {
                self.svgaPlayer.videoItem = videoItem
                self.svgaPlayer.startAnimation()
            }
        } failureBlock: { [weak self] error in
            DispatchQueue.main.async {
                self?.svgaPlayer.isHidden = true
            }
        }
    }

    // MARK: - barrage slide animation (similar to Douyin live streaming)

    /// Add the barrage item to the queue
    private func enqueueBarrageAnimation(_ item: GiftBarrageItem) {
        barrageAnimationQueue.append(item)
        processBarrageQueue()
    }

    /// Process the barrage queue and display items in available slots
    private func processBarrageQueue() {
        guard !barrageAnimationQueue.isEmpty else { return }

        // Find an available slot
        for slot in 0..<maxSlots {
            guard !barrageAnimationQueue.isEmpty else { break }
            if activeSlots[slot] == nil {
                let item = barrageAnimationQueue.removeFirst()
                showBarrageItem(item, inSlot: slot)
            }
        }
    }

    /// Display the barrage animation in the specified slot
    private func showBarrageItem(_ item: GiftBarrageItem, inSlot slot: Int) {
        let itemView = GiftBarrageItemView()
        itemView.configure(with: item)
        addSubview(itemView)

        activeSlots[slot] = itemView

        // Calculate the slot Y offset (starting slightly above the middle of the screen, with each slot spaced 56pt apart)
        let slotY = bounds.height * 0.35 + CGFloat(slot) * 56

        // Initial position: outside the left side of the screen
        itemView.frame = CGRect(x: -300, y: slotY, width: 280, height: 48)
        itemView.alpha = 0

        // Phase 1: slide in from the left
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            itemView.frame.origin.x = 12
            itemView.alpha = 1
        } completion: { _ in
            // Phase 2: stay for 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                // Phase 3: fade out upward
                UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn) {
                    itemView.alpha = 0
                    itemView.frame.origin.y -= 20
                } completion: { _ in
                    itemView.removeFromSuperview()
                    self?.activeSlots[slot] = nil
                    // Process the next item in the queue
                    self?.processBarrageQueue()
                }
            }
        }
    }
}

// MARK: - SVGAPlayerDelegate

extension GiftAnimationView: SVGAPlayerDelegate {

    func svgaPlayerDidFinishedAnimation(_ player: SVGAPlayer!) {
        player.isHidden = true
        player.clear()
    }
}

// MARK: - GiftBarrageItem

/// Barrage animation data model
private struct GiftBarrageItem {
    let gift: Gift
    let count: UInt8
    let sender: LiveUserInfo
}

// MARK: - GiftBarrageItemView

/// Barrage animation view - simulates the Douyin-style live gift barrage
/// Layout: [Avatar] [Sender Name / Sent Gift Name] [Gift Icon] [xCount]
private class GiftBarrageItemView: UIView {

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        return iv
    }()

    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let giftIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .heavy)
        label.textColor = .systemYellow
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 24

        addSubview(avatarImageView)
        addSubview(textLabel)
        addSubview(giftIconView)
        addSubview(countLabel)

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        textLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(giftIconView.snp.leading).offset(-4)
        }

        giftIconView.snp.makeConstraints { make in
            make.trailing.equalTo(countLabel.snp.leading).offset(-2)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        countLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    func configure(with item: GiftBarrageItem) {
        let senderName = item.sender.userName.isEmpty ? item.sender.userID : item.sender.userName

        // avatar
        if let avatarURL = URL(string: item.sender.avatarURL), !item.sender.avatarURL.isEmpty {
            avatarImageView.kf.setImage(with: avatarURL, placeholder: UIImage(systemName: "person.circle.fill"))
        } else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = .white
        }

        // text: sender name + "sent" + gift name
        let attributed = NSMutableAttributedString()
        let nameAttr = NSAttributedString(
            string: senderName + "\n",
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            ]
        )
        attributed.append(nameAttr)

        let actionAttr = NSAttributedString(
            string: "\("interactive.gift.sent".localized) \(item.gift.name)",
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .font: UIFont.systemFont(ofSize: 11),
            ]
        )
        attributed.append(actionAttr)
        textLabel.attributedText = attributed

        // gift icon
        let placeholder = UIImage(systemName: "gift.fill")
        if let iconURL = URL(string: item.gift.iconURL), !item.gift.iconURL.isEmpty {
            giftIconView.kf.setImage(with: iconURL, placeholder: placeholder)
        } else {
            giftIconView.image = placeholder
            giftIconView.tintColor = .systemPink
        }

        // count
        countLabel.text = "x\(item.count)"

        // count bounce animation
        countLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.4, delay: 0.3, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8, options: .curveEaseOut) {
            self.countLabel.transform = .identity
        }
    }
}
