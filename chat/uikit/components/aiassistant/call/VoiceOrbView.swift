import UIKit

final class VoiceOrbView: UIView {
    private let bgGradientLayer = CAGradientLayer()
    private var blobLayers: [CAShapeLayer] = []
    private let coreLayer = CAGradientLayer()
    private let glowLayer = CAGradientLayer()

    private var displayLink: CADisplayLink?
    private var state: AICallState = .idle

    private var currentLevel: Float = 0
    private var targetLevel: Float = 0
    private var phase: Float = 0
    private var spinAngle: Float = 0
    private var elapsed: TimeInterval = 0
    private var lastTimestamp: TimeInterval = 0

    private var currentAlphaMul: Float = 0.55
    private var currentWaveAmp: Float = 0
    private var currentLevelGain: Float = 0
    private var currentBreathAmp: Float = 0
    private var currentGlowAlpha: Float = 0

    private let blobColors: [UIColor] = [
        UIColor(red: 0x3B / 255.0, green: 0x4A / 255.0, blue: 0x8F / 255.0, alpha: 1),
        UIColor(red: 0x4C / 255.0, green: 0x3A / 255.0, blue: 0x86 / 255.0, alpha: 1),
        UIColor(red: 0x2F / 255.0, green: 0x6C / 255.0, blue: 0x8E / 255.0, alpha: 1),
    ]
    private let blobAlphas: [Float] = [102 / 255, 88 / 255, 96 / 255]
    private let blobOffsets: [Float] = [0.32, 0.34, 0.30]
    private let blobSpeeds: [Float] = [0.9, -0.7, 1.15]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayers() {
        bgGradientLayer.type = .radial
        bgGradientLayer.colors = [
            UIColor(red: 0x5C / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0, alpha: 0.94).cgColor,
            UIColor(red: 0x5C / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0, alpha: 0).cgColor,
        ]
        bgGradientLayer.locations = [0, 1]
        bgGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        bgGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(bgGradientLayer)

        for index in 0 ..< 3 {
            let blob = CAShapeLayer()
            blob.fillColor = blobColors[index].cgColor
            blob.shadowColor = blobColors[index].cgColor
            blob.shadowRadius = 45
            blob.shadowOpacity = 0.9
            blob.shadowOffset = .zero
            layer.addSublayer(blob)
            blobLayers.append(blob)
        }

        glowLayer.type = .radial
        glowLayer.colors = [
            UIColor(white: 1, alpha: 0.85).cgColor,
            UIColor(red: 0x5C / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0, alpha: 0).cgColor,
        ]
        glowLayer.locations = [0, 1]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.opacity = 0
        layer.addSublayer(glowLayer)

        coreLayer.type = .radial
        coreLayer.colors = [
            UIColor(white: 1, alpha: 0.95).cgColor,
            UIColor(red: 0x8F / 255.0, green: 0xA5 / 255.0, blue: 0xFF / 255.0, alpha: 0.55).cgColor,
            UIColor(red: 0x5C / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0, alpha: 0.18).cgColor,
        ]
        coreLayer.locations = [0, 0.55, 1]
        coreLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        coreLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(coreLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = min(bounds.width, bounds.height) * 0.86
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        bgGradientLayer.frame = CGRect(
            x: center.x - size * 0.65, y: center.y - size * 0.65,
            width: size * 1.3, height: size * 1.3
        )
        glowLayer.frame = bgGradientLayer.frame
        coreLayer.frame = CGRect(
            x: center.x - size * 0.31, y: center.y - size * 0.31,
            width: size * 0.62, height: size * 0.62
        )
        blobLayers.forEach { $0.frame = bounds }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    func setState(_ newState: AICallState) {
        state = newState
    }

    func setLevel(_ level: Float) {
        targetLevel = max(0, min(level, 1))
    }

    private func startAnimating() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt: Float = lastTimestamp == 0 ? 0 : Float(link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp
        elapsed += TimeInterval(dt)
        renderState(dt: dt)
    }

    private func renderState(dt: Float) {
        let targets: (alpha: Float, wave: Float, gain: Float, breath: Float, glow: Float)
        switch state {
        case .idle:
            targets = (0.55, 0, 0, 0.018, 0)
            targetLevel = max(0, targetLevel - dt * 6)
        case .listening:
            targets = (1.0, 1.0, 1.25, 0.018, 0)
        case .thinking:
            targets = (0.95, 0.55, 1.0, 0.014, 0)
        case .speaking:
            targets = (1.08, 1.3, 1.6, 0.02, 0.35)
        }

        let blend = min(1, dt * 10)
        currentLevel += (targetLevel - currentLevel) * blend
        currentAlphaMul += (targets.alpha - currentAlphaMul) * blend
        currentWaveAmp += (targets.wave - currentWaveAmp) * blend
        currentLevelGain += (targets.gain - currentLevelGain) * blend
        currentBreathAmp += (targets.breath - currentBreathAmp) * blend
        currentGlowAlpha += (targets.glow - currentGlowAlpha) * blend

        phase += dt * 2 * .pi * 2.4
        if state == .thinking {
            spinAngle += dt * 18
        }

        let breath = 1 + currentBreathAmp * Float(sin(2 * Float.pi * 0.28 * Float(elapsed)))
        let glowPulse = currentGlowAlpha > 0
            ? currentGlowAlpha * (0.7 + 0.3 * sinf(2 * .pi * 1.2 * Float(elapsed)))
            : 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let size = Float(min(bounds.width, bounds.height)) * 0.86
        let baseRadius = size / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let levelScale = 1 + 0.55 * powf(currentLevel * currentLevelGain, 1.3) * currentWaveAmp

        for (index, blob) in blobLayers.enumerated() {
            let layerPhase = phase * blobSpeeds[index] + Float(index) * (2 * .pi / 3)
            blob.path = makeBlobPath(
                center: center,
                radius: baseRadius * blobOffsets[index] * 2.2,
                phase: layerPhase,
                scale: breath * (1 + (levelScale - 1) * (0.8 + 0.2 * Float(index))),
                rotation: spinAngle * .pi / 180
            )
            blob.opacity = blobAlphas[index] * currentAlphaMul
        }

        bgGradientLayer.opacity = currentAlphaMul * 0.9
        coreLayer.opacity = min(1, currentAlphaMul * 1.05)
        glowLayer.opacity = glowPulse

        CATransaction.commit()
    }

    private func makeBlobPath(center: CGPoint, radius: Float, phase: Float, scale: Float, rotation: Float) -> CGPath {
        let path = UIBezierPath()
        let steps = 96
        for i in 0 ... steps {
            let theta = Float(i) / Float(steps) * 2 * .pi
            let modulation = 1
                + 0.06 * sinf(3 * theta + phase)
                + 0.035 * sinf(5 * theta - 1.7 * phase)
                + 0.02 * sinf(8 * theta + 0.9 * phase)
            let r = radius * modulation * scale
            let rotated = theta + rotation
            let point = CGPoint(
                x: center.x + CGFloat(r * cosf(rotated)),
                y: center.y + CGFloat(r * sinf(rotated))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        return path.cgPath
    }
}
