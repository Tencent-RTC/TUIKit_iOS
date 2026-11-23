import Kingfisher
import SnapKit
import UIKit

final class VoiceLoungeHostHeroView: UIView {
    private let hostContainer = UIView()
    private let rippleView = HostRippleView()
    private let avatarView = HostAvatarView()
    private let nameLabel = UILabel()
    private let secondaryContainer = UIView()
    private let secondaryRingView = PlaceholderRingView()
    private let secondaryLabel = UILabel()

    private var hostCenterXConstraint: Constraint?
    private var secondaryCenterXConstraint: Constraint?
    private var hostTopConstraint: Constraint?
    private var secondaryTopConstraint: Constraint?
    private var avatarSizeConstraint: Constraint?
    private var rippleSizeConstraint: Constraint?
    private var nameTopConstraint: Constraint?
    private var currentLayout: VoiceLoungeSeatLayout = .oneV8
    private var representedAvatarURL = ""
    private var isActive = true
    private var isAppActive = UIApplication.shared.applicationState != .background

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        observeAppLifecycle()
        applyLayout(.oneV8, animated: false)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { Task { @MainActor [avatarView] in avatarView.cancelImageLoading() } }

    func bind(hostName: String, avatarURL: String, skin: VoiceLoungeSkin) {
        nameLabel.text = hostName
        guard representedAvatarURL != avatarURL else { return }
        representedAvatarURL = avatarURL
        avatarView.setAvatar(url: avatarURL)
    }

    func applyLayout(_ layout: VoiceLoungeSeatLayout, animated: Bool = true) {
        currentLayout = layout
        let secondary = SecondarySpec.spec(for: layout)
        let avatarSize = secondary == nil ? HeroStyle.avatarSize : HeroStyle.secondarySize
        secondaryContainer.isHidden = secondary == nil
        secondaryLabel.text = secondary?.title ?? ""
        secondaryLabel.isHidden = (secondary?.title ?? "").isEmpty
        hostCenterXConstraint?.update(offset: secondary?.hostOffset ?? 0)
        secondaryCenterXConstraint?.update(offset: secondary?.secondaryOffset ?? 0)
        hostTopConstraint?.update(offset: secondary?.topOffset ?? 0)
        secondaryTopConstraint?.update(offset: secondary?.topOffset ?? 0)
        avatarSizeConstraint?.update(offset: avatarSize)
        rippleSizeConstraint?.update(offset: avatarSize + HeroStyle.ringPadding)
        nameTopConstraint?.update(offset: secondary == nil ? HeroStyle.nameTop : HeroStyle.compactNameTop)
        guard animated, window != nil else {
            layoutIfNeeded()
            return
        }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState]) { self.layoutIfNeeded() }
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        updateRipple()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateRipple()
    }

    private func setupViews() {
        isUserInteractionEnabled = false
        clipsToBounds = false
        addSubview(secondaryContainer)
        secondaryContainer.addSubview(secondaryRingView)
        secondaryContainer.addSubview(secondaryLabel)
        addSubview(hostContainer)
        hostContainer.addSubview(rippleView)
        hostContainer.addSubview(avatarView)
        hostContainer.addSubview(nameLabel)
    }

    private func setupConstraints() {
        hostContainer.snp.makeConstraints { make in
            hostCenterXConstraint = make.centerX.equalToSuperview().constraint
            hostTopConstraint = make.top.equalToSuperview().constraint
            make.bottom.equalToSuperview()
            make.width.equalTo(HeroStyle.avatarSize + 56)
        }
        avatarView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            avatarSizeConstraint = make.size.equalTo(HeroStyle.avatarSize).constraint
        }
        rippleView.snp.makeConstraints { make in
            make.center.equalTo(avatarView)
            rippleSizeConstraint = make.size.equalTo(HeroStyle.ringSize).constraint
        }
        nameLabel.snp.makeConstraints { make in
            nameTopConstraint = make.top.equalTo(avatarView.snp.bottom).offset(HeroStyle.nameTop).constraint
            make.leading.trailing.equalToSuperview().inset(4)
            make.bottom.equalToSuperview()
        }
        secondaryContainer.snp.makeConstraints { make in
            secondaryCenterXConstraint = make.centerX.equalToSuperview().constraint
            secondaryTopConstraint = make.top.equalToSuperview().constraint
            make.width.equalTo(HeroStyle.secondarySize + 40)
        }
        secondaryRingView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(HeroStyle.secondarySize)
        }
        secondaryLabel.snp.makeConstraints { make in
            make.top.equalTo(secondaryRingView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(2)
        }
    }

    private func setupStyles() {
        nameLabel.font = HeroStyle.nameFont
        nameLabel.textColor = HeroStyle.nameColor
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = 0.6
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        nameLabel.layer.shadowRadius = 4

        secondaryLabel.font = .systemFont(ofSize: VoiceLoungeFont.size(11))
        secondaryLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        secondaryLabel.textAlignment = .center
        secondaryLabel.numberOfLines = 1
    }

    private func observeAppLifecycle() {
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        center.addObserver(
            self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    private func updateRipple() {
        if isActive, isAppActive, window != nil { rippleView.startAnimating() } else { rippleView.stopAnimating() }
    }
}

extension VoiceLoungeHostHeroView {
    @objc private func appDidEnterBackground() {
        isAppActive = false
        updateRipple()
    }

    @objc private func appWillEnterForeground() {
        isAppActive = true
        updateRipple()
    }
}

private struct SecondarySpec {
    let title: String
    let hostOffset: CGFloat
    let secondaryOffset: CGFloat
    let topOffset: CGFloat

    static func spec(for layout: VoiceLoungeSeatLayout) -> SecondarySpec? {
        switch layout {
        case .oneV8, .oneV8x: return nil
        case .twoV8: return SecondarySpec(title: .cohostTitle, hostOffset: -72, secondaryOffset: 72, topOffset: 10)
        case .duo: return SecondarySpec(title: "", hostOffset: -60, secondaryOffset: 60, topOffset: 40)
        }
    }
}

private final class HostRippleView: UIView {
    private let waveRings = [CAShapeLayer(), CAShapeLayer()]
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false
        waveRings.forEach { ring in
            VoiceLoungeSeatStyle.styleWaveRing(ring)
            layer.addSublayer(ring)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        VoiceLoungeSeatStyle.startWave(on: waveRings)
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        VoiceLoungeSeatStyle.stopWave(on: waveRings)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        waveRings.forEach { ring in
            ring.frame = bounds
            ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
        }
        CATransaction.commit()
    }
}

private final class HostAvatarView: UIView {
    private let shadowLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowOpacity = 0.45
        shadowLayer.shadowOffset = CGSize(width: 0, height: 10)
        shadowLayer.shadowRadius = 14
        layer.addSublayer(shadowLayer)

        gradientLayer.colors = [HeroStyle.avatarGradientTop.cgColor, HeroStyle.avatarGradientBottom.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.27)
        gradientLayer.endPoint = CGPoint(x: 0.73, y: 1)
        layer.addSublayer(gradientLayer)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setAvatar(url: String) {
        let placeholder = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        imageView.kf.cancelDownloadTask()
        guard let avatarURL = URL(string: url), !url.isEmpty else {
            imageView.image = placeholder
            return
        }
        imageView.kf.setImage(with: avatarURL, placeholder: imageView.image ?? placeholder)
    }

    func cancelImageLoading() { imageView.kf.cancelDownloadTask() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.height / 2
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = radius
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = UIBezierPath(ovalIn: bounds).cgPath
        imageView.frame = bounds
        imageView.layer.cornerRadius = radius
    }
}

private final class PlaceholderRingView: UIView {
    private let micView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = HeroStyle.placeholderFill
        layer.borderWidth = 1
        layer.borderColor = HeroStyle.placeholderBorder.cgColor

        micView.image = LiveKitResources.image(named: "livekit_voiceprepare_seat_mic")?.withRenderingMode(
            .alwaysTemplate)
        micView.tintColor = UIColor.white.withAlphaComponent(0.5)
        micView.contentMode = .scaleAspectFit
        addSubview(micView)
        micView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(22)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

private enum HeroStyle {
    static let avatarSize: CGFloat = 96
    static let secondarySize: CGFloat = 76
    static let ringPadding: CGFloat = VoiceLoungeSeatStyle.waveRingOffset * 2
    static let ringSize: CGFloat = avatarSize + ringPadding
    static let nameTop: CGFloat = 20
    static let compactNameTop: CGFloat = 12
    static let avatarGradientTop = UIColor(red: 0.118, green: 0.125, blue: 0.161, alpha: 1)
    static let avatarGradientBottom = UIColor(red: 0.051, green: 0.055, blue: 0.078, alpha: 1)
    static let nameFont = UIFont.systemFont(ofSize: VoiceLoungeFont.size(13))
    static let nameColor = UIColor.white.withAlphaComponent(0.92)
    static let placeholderFill = UIColor.white.withAlphaComponent(0.05)
    static let placeholderBorder = UIColor.white.withAlphaComponent(0.1)
}

private extension String {
    static var cohostTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.layout.cohost") }
}
