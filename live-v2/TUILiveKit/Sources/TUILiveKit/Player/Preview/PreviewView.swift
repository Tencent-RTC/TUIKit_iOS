import Kingfisher
import AtomicXCore
import SnapKit
import UIKit

@MainActor
final class PreviewView: UIView {
    var onTapEnter: (() -> Void)?

    private let joinButton = UIControl()
    private let entranceAnimationView = EntranceAnimationView()
    private let joinLabel = UILabel()

    private let bottomInfoContainer = UIView()
    private let roomNameLabel = UILabel()
    private let avatarImageView = UIImageView()
    private let anchorNameLabel = UILabel()

    private var liveInfo: LiveInfo?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Task { @MainActor [avatarImageView] in
            avatarImageView.kf.cancelDownloadTask()
        }
    }

    func bind(_ liveInfo: LiveInfo) {
        self.liveInfo = liveInfo

        roomNameLabel.text = liveInfo.liveName.isEmpty ? liveInfo.liveID : liveInfo.liveName
        anchorNameLabel.text = liveInfo.liveOwner.userName.isEmpty
            ? liveInfo.liveOwner.userID
            : liveInfo.liveOwner.userName

        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        let avatarURL = liveInfo.liveOwner.avatarURL
        avatarImageView.kf.setImage(with: URL(string: avatarURL), placeholder: avatarImageView.image)
    }

    func setEnabled(_ enabled: Bool) {
        joinButton.isEnabled = enabled
    }

    override var isHidden: Bool {
        didSet {
            updateAnimationState()
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            entranceAnimationView.stopAnimation()
        } else {
            updateAnimationState()
        }
    }

    private func updateAnimationState() {
        if window != nil && !isHidden {
            entranceAnimationView.startAnimation()
        } else {
            entranceAnimationView.stopAnimation()
        }
    }

    private func configureUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        joinButton.backgroundColor = UIColor(white: 1, alpha: 0.14)
        joinButton.layer.cornerRadius = 20
        joinButton.layer.masksToBounds = true
        joinButton.layer.borderColor = UIColor.white.cgColor
        joinButton.layer.borderWidth = 0.3
        joinButton.isUserInteractionEnabled = true
        joinButton.addAction(UIAction { [weak self] _ in
            self?.onTapEnter?()
        }, for: .touchUpInside)

        joinLabel.textColor = .white
        joinLabel.font = .systemFont(ofSize: 14)
        joinLabel.numberOfLines = 1
        joinLabel.text = LiveKitResources.localizedString("tuilivekit.player.enter_room_hint")

        entranceAnimationView.backgroundColor = .clear

        joinButton.addSubview(entranceAnimationView)
        joinButton.addSubview(joinLabel)

        roomNameLabel.textColor = .white
        roomNameLabel.font = .systemFont(ofSize: 20)
        roomNameLabel.numberOfLines = 1
        roomNameLabel.lineBreakMode = .byTruncatingTail
        roomNameLabel.textAlignment = .left

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 12
        avatarImageView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")

        anchorNameLabel.textColor = UIColor(white: 1, alpha: 0.55)
        anchorNameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        anchorNameLabel.numberOfLines = 1
        anchorNameLabel.lineBreakMode = .byTruncatingTail

        bottomInfoContainer.addSubview(roomNameLabel)
        bottomInfoContainer.addSubview(avatarImageView)
        bottomInfoContainer.addSubview(anchorNameLabel)

        addSubview(joinButton)
        addSubview(bottomInfoContainer)

        joinButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(40)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-234)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
        entranceAnimationView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(25)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(15)
        }
        joinLabel.snp.makeConstraints { make in
            make.leading.equalTo(entranceAnimationView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-25)
        }

        bottomInfoContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-34)
        }
        roomNameLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        avatarImageView.snp.makeConstraints { make in
            make.top.equalTo(roomNameLabel.snp.bottom).offset(5)
            make.leading.equalToSuperview()
            make.width.height.equalTo(24)
            make.bottom.equalToSuperview().offset(-4)
        }
        anchorNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(8)
            make.centerY.equalTo(avatarImageView)
            make.trailing.lessThanOrEqualToSuperview()
        }
    }
}

@MainActor
final class EntranceAnimationView: UIView {
    private static let barCount = 3
    private static let barWidth: CGFloat = 2
    private static let barBaseHeight: CGFloat = 4
    private static let barAmplitude: CGFloat = 11
    private static let barSpacing: CGFloat = 3
    private static let animDuration: CFTimeInterval = 1.0
    private static let barColor = UIColor.white

    private var barLayers: [CALayer] = []
    private var displayLink: CADisplayLink?
    private var animationStart: CFTimeInterval = 0
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    private func setupLayers() {
        for _ in 0..<Self.barCount {
            let layer = CALayer()
            layer.backgroundColor = Self.barColor.cgColor
            layer.cornerRadius = 1
            self.layer.addSublayer(layer)
            barLayers.append(layer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !isAnimating {
            updateBars(progress: 0)
        }
    }

    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        animationStart = CACurrentMediaTime()
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(onTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimation() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onTick() {
        let elapsed = CACurrentMediaTime() - animationStart
        let cycle = Self.animDuration * 2
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        let raw = t / Self.animDuration
        let progress: CGFloat = raw <= 1 ? CGFloat(raw) : CGFloat(2 - raw)
        updateBars(progress: progress)
    }

    private func updateBars(progress: CGFloat) {
        let totalWidth = Self.barWidth * CGFloat(Self.barCount)
            + Self.barSpacing * CGFloat(Self.barCount - 1)
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in 0..<Self.barCount {
            let phase = CGFloat(i) * 0.6
            let adjusted = (progress + phase).truncatingRemainder(dividingBy: 1.0)
            let normalized = adjusted < 0 ? adjusted + 1 : adjusted
            let wave = CGFloat(abs(sin(Double(normalized) * .pi)))
            let height = Self.barBaseHeight + wave * Self.barAmplitude
            let x = startX + CGFloat(i) * (Self.barWidth + Self.barSpacing)
            let y = centerY - height / 2
            barLayers[i].frame = CGRect(x: x, y: y, width: Self.barWidth, height: height)
        }
        CATransaction.commit()
    }
}
