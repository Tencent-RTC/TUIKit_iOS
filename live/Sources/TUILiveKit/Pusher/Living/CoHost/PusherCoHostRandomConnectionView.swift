import UIKit
import SnapKit
import Kingfisher
import CoreImage

final class PusherCoHostRandomConnectionView: UIView {
    private let backgroundGradient = CAGradientLayer()
    private let backgroundGlow = CAGradientLayer()
    private let sheen = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let buttonSurface = UIButton(type: .custom)
    private let buttonGradient = CAGradientLayer()
    private let radar = UIView()
    private let sweep = UIView()
    private let sweepImage = UIImageView(image: LiveKitResources.image(named: "livekit_cohost_radar_sweep"))
    private let sweepMask = CAShapeLayer()
    private let hostAvatar = UIImageView()
    private let hostGlow = CAShapeLayer()
    private let hostShadow = CAShapeLayer()
    private let pulses = [CAShapeLayer(), CAShapeLayer()]
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var peers: [RadarPeerView] = []
    private var positions = RandomConnectionStyle.defaultPositions
    private var hostAvatarURL: String?
    private var isHostImageRequestActive = false
    private var hasResolvedHostImage = false
    private var hostImageGeneration = 0
    private var candidateAvatarURLs: [String] = []
    private var isPresentationEnabled = false
    private var animationStart: CFTimeInterval?
    private var hasRandomizedPositions = false
    private var notifications: [NSObjectProtocol] = []

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: RandomConnectionStyle.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        observePresentationChanges()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        MainActor.assumeIsolated {
            stopAnimation()
            cancelImageRequests()
        }
    }

    func bind(hostAvatarURL: String, candidates: [PusherCoHostStore.User]) {
        if self.hostAvatarURL != hostAvatarURL {
            self.hostAvatarURL = hostAvatarURL
            hostImageGeneration += 1
            hostAvatar.kf.cancelDownloadTask()
            isHostImageRequestActive = false
            hasResolvedHostImage = false
            hostAvatar.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
            if canPresent { loadHostAvatar() }
        }
        var seenUsers = Set<String>()
        let urls = candidates.filter { seenUsers.insert($0.userID).inserted }.prefix(peers.count).map(\.avatarURL)
        guard urls != candidateAvatarURLs else { return }
        candidateAvatarURLs = urls
        for (index, peer) in peers.enumerated() {
            peer.bind(avatarURL: index < urls.count ? urls[index] : "", loadsImage: canPresent)
        }
    }

    func setPresentationEnabled(_ enabled: Bool, restart: Bool = false) {
        isPresentationEnabled = enabled
        if enabled && (!hasRandomizedPositions || restart) {
            stopAnimation()
            randomizePositions()
            layoutRadar()
            hasRandomizedPositions = true
        }
        updatePresentation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePresentation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundGradient.frame = bounds
        backgroundGlow.frame = bounds
        sheen.frame = bounds.insetBy(dx: 1, dy: 1)
        buttonGradient.frame = buttonSurface.bounds
        buttonSurface.layer.shadowPath = UIBezierPath(roundedRect: buttonSurface.bounds, cornerRadius: 11).cgPath
        CATransaction.commit()
    }

    private func configureUI() {
        layer.cornerRadius = 17
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        clipsToBounds = true
        backgroundGradient.colors = [
            RandomConnectionStyle.backgroundStart.cgColor, RandomConnectionStyle.backgroundEnd.cgColor,
        ]
        backgroundGradient.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(backgroundGradient, at: 0)
        backgroundGlow.type = .radial
        backgroundGlow.colors = [LiveTheme.Color.brandBlue.withAlphaComponent(0.24).cgColor, UIColor.clear.cgColor]
        backgroundGlow.locations = [0, 0.34]
        backgroundGlow.startPoint = CGPoint(x: 0.3, y: 0.55)
        backgroundGlow.endPoint = CGPoint(x: 0.87, y: 0.75)
        layer.insertSublayer(backgroundGlow, above: backgroundGradient)
        sheen.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.035).cgColor, UIColor.clear.cgColor]
        sheen.locations = [0.16, 0.42, 0.68]
        sheen.startPoint = .zero
        sheen.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(sheen, above: backgroundGlow)

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.cohost.random_title")
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        addSubview(titleLabel)
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .light)
        subtitleLabel.textColor = .white
        subtitleLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.cohost.random_subtitle")
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75
        addSubview(subtitleLabel)

        radar.isUserInteractionEnabled = false
        radar.accessibilityElementsHidden = true
        addSubview(radar)
        radar.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.trailing.equalToSuperview().inset(52).priority(.high)
            make.leading.greaterThanOrEqualToSuperview().offset(96)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            make.width.equalTo(132)
            make.height.equalTo(84)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(17)
            make.top.equalToSuperview().offset(19)
            make.trailing.lessThanOrEqualTo(radar.snp.leading).offset(25)
            make.height.equalTo(22)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(7)
            make.trailing.lessThanOrEqualTo(radar.snp.leading).offset(25)
            make.height.equalTo(17)
        }
        configureRadar()

        buttonSurface.addTarget(self, action: #selector(showRandomConnectionNotice), for: .touchUpInside)
        buttonSurface.layer.cornerRadius = 11
        buttonSurface.layer.borderWidth = 1
        buttonSurface.layer.borderColor = RandomConnectionStyle.buttonBorder.cgColor
        buttonSurface.layer.shadowColor = UIColor(red: 0, green: 0.322, blue: 0.851, alpha: 0.2).cgColor
        buttonSurface.layer.shadowOpacity = 1
        buttonSurface.layer.shadowOffset = CGSize(width: 0, height: 7)
        buttonSurface.layer.shadowRadius = 9
        buttonGradient.colors = [RandomConnectionStyle.buttonStart.cgColor, RandomConnectionStyle.buttonEnd.cgColor]
        buttonGradient.startPoint = CGPoint(x: 0, y: 1)
        buttonGradient.endPoint = CGPoint(x: 1, y: 0)
        buttonGradient.cornerRadius = 11
        buttonSurface.layer.insertSublayer(buttonGradient, at: 0)
        addSubview(buttonSurface)
        buttonSurface.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(17)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(22)
            make.height.equalTo(40)
        }
        let buttonTitle = UILabel()
        buttonTitle.text = LiveKitResources.localizedString("tuilivekit.pusher.cohost.random_button")
        buttonTitle.textColor = .white
        buttonTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        buttonTitle.textAlignment = .center
        buttonSurface.accessibilityLabel = buttonTitle.text
        buttonSurface.addSubview(buttonTitle)
        buttonTitle.snp.makeConstraints { $0.edges.equalToSuperview().inset(8) }
    }

    @objc private func showRandomConnectionNotice() {
        LiveToast.show(
            LiveKitResources.localizedString("tuilivekit.pusher.cohost.random_developing"), in: window?.windowScene)
    }

    private func configureRadar() {
        for pulse in pulses {
            pulse.bounds = CGRect(x: 0, y: 0, width: 34, height: 34)
            pulse.position = RandomConnectionStyle.center
            pulse.path = UIBezierPath(ovalIn: pulse.bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
            pulse.fillColor = UIColor.clear.cgColor
            pulse.strokeColor = UIColor.white.withAlphaComponent(0.82).cgColor
            pulse.lineWidth = 1
            pulse.opacity = 0
            radar.layer.addSublayer(pulse)
        }
        sweep.bounds = CGRect(x: 0, y: 0, width: 112, height: 112)
        sweep.center = RandomConnectionStyle.center
        radar.addSubview(sweep)
        // Ardot 5074:337 exports a 136 × 142 canvas with the scan body offset by (12, 18).
        sweepImage.frame = CGRect(x: -12, y: -18, width: 136, height: 142)
        sweepImage.contentMode = .scaleAspectFit
        sweep.addSubview(sweepImage)
        let maskPath = UIBezierPath(rect: sweepImage.bounds)
        maskPath.append(UIBezierPath(ovalIn: CGRect(x: 47.5, y: 53.5, width: 41, height: 41)))
        sweepMask.frame = sweepImage.bounds
        sweepMask.path = maskPath.cgPath
        sweepMask.fillRule = .evenOdd
        sweepImage.layer.mask = sweepMask

        peers = RandomConnectionStyle.sizes.map { _ in RadarPeerView(imageContext: imageContext) }
        peers.forEach { radar.addSubview($0) }
        for shadow in [hostShadow, hostGlow] {
            shadow.frame = CGRect(x: 72, y: 25, width: 34, height: 34)
            shadow.path = UIBezierPath(ovalIn: shadow.bounds).cgPath
            shadow.fillColor = UIColor(red: 0.808, green: 0.871, blue: 0.973, alpha: 0.937).cgColor
            shadow.shadowPath = shadow.path
            shadow.shadowOpacity = 1
            radar.layer.addSublayer(shadow)
        }
        // Ardot 5074:343 keeps the blue glow outside the circular avatar crop.
        hostGlow.shadowColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.4).cgColor
        hostGlow.shadowRadius = 7
        hostGlow.shadowOffset = .zero
        hostShadow.shadowColor = UIColor.black.withAlphaComponent(0.251).cgColor
        hostShadow.shadowRadius = 9
        hostShadow.shadowOffset = CGSize(width: 0, height: 7)
        hostAvatar.contentMode = .scaleAspectFill
        hostAvatar.layer.cornerRadius = 17
        hostAvatar.clipsToBounds = true
        hostAvatar.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        radar.addSubview(hostAvatar)
        hostAvatar.frame = CGRect(x: 72, y: 25, width: 34, height: 34)
        layoutRadar()
        stopAnimation()
    }

    private func layoutRadar() {
        for (index, peer) in peers.enumerated() {
            let size = RandomConnectionStyle.sizes[index]
            peer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            peer.center = positions[index]
            peer.layer.cornerRadius = size / 2
            peer.phase = phase(at: positions[index])
        }
    }

    private func observePresentationChanges() {
        for name in [
            UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
        ] {
            notifications.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.stopAnimation()
                        self.updatePresentation()
                    }
                })
        }
    }

    private var canPresent: Bool {
        isPresentationEnabled && window != nil && UIApplication.shared.applicationState == .active
    }

    private func updatePresentation() {
        guard canPresent else {
            stopAnimation()
            cancelImageRequests()
            return
        }
        loadHostAvatar()
        peers.forEach { $0.resumeImageRequest() }
        guard !UIAccessibility.isReduceMotionEnabled else {
            stopAnimation()
            peers.forEach { $0.showStatic() }
            return
        }
        guard animationStart == nil else { return }
        let start = CACurrentMediaTime()
        animationStart = start
        sweep.isHidden = false
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = RandomConnectionStyle.scanDuration
        rotation.repeatCount = .infinity
        rotation.beginTime = sweep.layer.convertTime(start, from: nil)
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        sweep.layer.add(rotation, forKey: "scan")
        for (index, pulse) in pulses.enumerated() {
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.95, 1.9, 1.9]
            scale.keyTimes = [0, 0.76, 1]
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.68, 0, 0]
            opacity.keyTimes = scale.keyTimes
            let color = CAKeyframeAnimation(keyPath: "strokeColor")
            color.values = [
                UIColor.white.withAlphaComponent(0.82).cgColor,
                LiveTheme.Color.brandCyan.withAlphaComponent(0.08).cgColor,
                LiveTheme.Color.brandCyan.withAlphaComponent(0.08).cgColor,
            ]
            color.keyTimes = scale.keyTimes
            for animation in [scale, opacity, color] {
                animation.duration = 2.8
                animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 2)
            }
            let group = CAAnimationGroup()
            group.animations = [scale, opacity, color]
            group.duration = 2.8
            group.repeatCount = .infinity
            group.beginTime = pulse.convertTime(start + Double(index) * 1.4, from: nil)
            pulse.add(group, forKey: "pulse")
        }
        peers.forEach { $0.animate(start: start) }
    }

    private func stopAnimation() {
        animationStart = nil
        sweep.layer.removeAllAnimations()
        sweep.transform = .identity
        sweep.isHidden = true
        pulses.forEach {
            $0.removeAllAnimations()
            $0.opacity = 0
            $0.transform = CATransform3DIdentity
        }
        peers.forEach { $0.stopAnimation() }
    }

    private func cancelImageRequests() {
        hostImageGeneration += 1
        hostAvatar.kf.cancelDownloadTask()
        isHostImageRequestActive = false
        peers.forEach { $0.cancelImageRequest() }
    }

    private func loadHostAvatar() {
        guard !isHostImageRequestActive, !hasResolvedHostImage, let hostAvatarURL, !hostAvatarURL.isEmpty,
            let url = URL(string: hostAvatarURL)
        else { return }
        isHostImageRequestActive = true
        hostImageGeneration += 1
        let generation = hostImageGeneration
        hostAvatar.kf.setImage(
            with: url, placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"),
            options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 34, height: 34))),
                .scaleFactor(UIScreen.main.scale),
            ]
        ) { [weak self] _ in
            guard let self, self.hostImageGeneration == generation else { return }
            self.isHostImageRequestActive = false
            self.hasResolvedHostImage = true
        }
    }

    private func phase(at position: CGPoint) -> Double {
        let angle = atan2(position.x - RandomConnectionStyle.center.x, RandomConnectionStyle.center.y - position.y)
        return (Double(angle) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1)
    }

    private func randomizePositions() {
        let center = RandomConnectionStyle.center
        for _ in 0..<8 {
            var sampled: [(center: CGPoint, safeRadius: CGFloat)] = []
            for size in RandomConnectionStyle.sizes {
                let safeRadius = size * 1.08 / 2
                var position: CGPoint?
                for _ in 0..<160 {
                    let candidate = CGPoint(
                        x: .random(in: (center.x - 56 + safeRadius + 6)...(center.x + 56 - safeRadius - 4)),
                        y: .random(in: (safeRadius + 3)...(84 - safeRadius - 3)))
                    let distance = hypot(candidate.x - center.x, candidate.y - center.y)
                    guard distance >= 17 + safeRadius + 5, distance <= 54,
                        !sampled.contains(where: {
                            hypot(candidate.x - $0.center.x, candidate.y - $0.center.y) < safeRadius + $0.safeRadius + 6
                        })
                    else { continue }
                    position = candidate
                    break
                }
                guard let position else { break }
                sampled.append((position, safeRadius))
            }
            guard sampled.count == peers.count else { continue }
            positions = sampled.map(\.center)
            return
        }
    }
}

private final class RadarPeerView: UIView {
    var phase: Double = 0
    private let avatar = UIImageView()
    private let imageContext: CIContext
    private var avatarURL = ""
    private var isImageRequestActive = false
    private var hasLoadedImage = false
    private var imageGeneration = 0
    private var variants: [CGImage] = []
    private var needsVariants = true
    private var animationStart: CFTimeInterval?

    init(imageContext: CIContext) {
        self.imageContext = imageContext
        super.init(frame: .zero)
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        addSubview(avatar)
        // Ardot 5074:338 owns the halo, independently of its cropped avatar content.
        backgroundColor = UIColor(red: 0.357, green: 0.565, blue: 0.906, alpha: 0.278)
        layer.shadowColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.4).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 5
        layer.shadowOffset = .zero
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatar.frame = bounds
        avatar.layer.cornerRadius = bounds.width / 2
        layer.shadowPath = UIBezierPath(ovalIn: bounds).cgPath
    }

    func bind(avatarURL: String, loadsImage: Bool) {
        guard self.avatarURL != avatarURL else {
            if loadsImage { resumeImageRequest() }
            return
        }
        cancelImageRequest()
        self.avatarURL = avatarURL
        hasLoadedImage = false
        avatar.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        needsVariants = true
        updateVariants()
        animateColors()
        if loadsImage { resumeImageRequest() }
    }

    func resumeImageRequest() {
        guard !hasLoadedImage, !isImageRequestActive, !avatarURL.isEmpty, let url = URL(string: avatarURL) else {
            return
        }
        isImageRequestActive = true
        imageGeneration += 1
        let generation = imageGeneration
        avatar.kf.setImage(
            with: url, placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"),
            options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 20, height: 20))),
                .scaleFactor(UIScreen.main.scale),
            ]
        ) { [weak self] _ in
            guard let self, self.imageGeneration == generation else { return }
            self.isImageRequestActive = false
            self.hasLoadedImage = true
            self.needsVariants = true
            self.updateVariants()
            self.animateColors()
        }
    }

    func cancelImageRequest() {
        imageGeneration += 1
        avatar.kf.cancelDownloadTask()
        isImageRequestActive = false
    }

    func animate(start: CFTimeInterval) {
        animationStart = start
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.92, 0.92, 0, 0]
        opacity.keyTimes = RandomConnectionStyle.peerKeyTimes
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.72, 1.08, 1, 1, 0.96, 0.96]
        scale.keyTimes = RandomConnectionStyle.peerKeyTimes
        for animation in [opacity, scale] {
            animation.duration = RandomConnectionStyle.scanDuration
            animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 5)
        }
        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = RandomConnectionStyle.scanDuration
        group.repeatCount = .infinity
        group.beginTime = layer.convertTime(start + phase * RandomConnectionStyle.scanDuration, from: nil)
        layer.add(group, forKey: "discovery")
        updateVariants()
        animateColors()
    }

    func stopAnimation() {
        animationStart = nil
        layer.removeAllAnimations()
        avatar.layer.removeAllAnimations()
        alpha = 0
        transform = .identity
    }

    func showStatic() {
        stopAnimation()
        alpha = 0.8
    }

    private func animateColors() {
        guard let animationStart, variants.count == 4 else { return }
        let color = CAKeyframeAnimation(keyPath: "contents")
        color.values = [variants[0], variants[1], variants[2], variants[2], variants[3], variants[3]]
        color.keyTimes = RandomConnectionStyle.peerKeyTimes
        color.duration = RandomConnectionStyle.scanDuration
        color.repeatCount = .infinity
        color.beginTime = avatar.layer.convertTime(
            animationStart + phase * RandomConnectionStyle.scanDuration, from: nil)
        color.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 5)
        avatar.layer.add(color, forKey: "discoveryColor")
    }

    private func updateVariants() {
        guard needsVariants, animationStart != nil, let image = avatar.image, image.size.width > 0,
            image.size.height > 0
        else { return }
        // Five peers, four 20 pt textures each. Filters run on image changes, never on animation frames.
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let smallImage = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20), format: format).image { _ in
            let scale = max(20 / image.size.width, 20 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(
                in: CGRect(x: (20 - size.width) / 2, y: (20 - size.height) / 2, width: size.width, height: size.height))
        }
        guard let cgImage = smallImage.cgImage else { return }
        let input = CIImage(cgImage: cgImage)
        variants = [(0.55, 0.8), (1.0, 1.2), (1.0, 1.08), (0.65, 0.85)].map { saturation, brightness in
            let colored = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: saturation])
                .applyingFilter(
                    "CIColorMatrix",
                    parameters: [
                        "inputRVector": CIVector(x: brightness, y: 0, z: 0, w: 0),
                        "inputGVector": CIVector(x: 0, y: brightness, z: 0, w: 0),
                        "inputBVector": CIVector(x: 0, y: 0, z: brightness, w: 0),
                    ])
            return imageContext.createCGImage(colored, from: input.extent) ?? cgImage
        }
        needsVariants = false
    }
}

// Ardot 5074:290 / 5155:1 and host-match.css hostCardRadar*.
private enum RandomConnectionStyle {
    static let height: CGFloat = 142
    static let center = CGPoint(x: 89, y: 42)
    static let sizes: [CGFloat] = [18, 16, 15, 16, 17]
    static let defaultPositions = [
        CGPoint(x: 51, y: 17), CGPoint(x: 129, y: 45), CGPoint(x: 56, y: 72), CGPoint(x: 104, y: 12),
        CGPoint(x: 105, y: 74),
    ]
    static let scanDuration: TimeInterval = 4.8
    static let peerKeyTimes: [NSNumber] = [0, 0.04, 0.08, 0.22, 0.42, 1]
    static let backgroundStart = UIColor(red: 0.071, green: 0.118, blue: 0.196, alpha: 0.922)
    static let backgroundEnd = UIColor(red: 0.043, green: 0.047, blue: 0.078, alpha: 0.941)
    static let buttonStart = UIColor(red: 0.012, green: 0.282, blue: 0.722, alpha: 1)
    static let buttonEnd = UIColor(red: 0.227, green: 0.463, blue: 0.741, alpha: 1)
    static let buttonBorder = UIColor(red: 0.38, green: 0.667, blue: 1, alpha: 0.4)
}
