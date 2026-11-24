import UIKit

final class VoiceOrbView: UIView {
    private enum Style {
        static let pointCount = 48
        static let baseRadiusRatio: CGFloat = 0.78
        static let glowRadiusRatio: CGFloat = 0.82
        static let blobRadiusRatio: CGFloat = 0.95
        static let highlightRadiusRatio: CGFloat = 0.75
        static let shadeRadiusRatio: CGFloat = 0.9
        static let maximumFrameInterval: TimeInterval = 0.05
        static let referenceFrameRate: Double = 60
        static let levelAttack: Double = 0.38
        static let levelRelease: Double = 0.10
        static let levelTolerance: Double = 0.002
        static let energyResponse: Double = 3
        static let boostResponse: Double = 10
        static let baseColor = color(0x5B3CFF)
        static let glowColors = [
            color(0x9B87FF, alpha: 0.9), color(0x9B87FF, alpha: 0.8),
            color(0x9B87FF, alpha: 0.6), color(0x5AD8FF, alpha: 0.32),
            color(0x5AD8FF, alpha: 0.12), color(0x5AD8FF, alpha: 0)
        ]
        static let glowLocations: [CGFloat] = [0, 0.6, 0.78, 0.87, 0.94, 1]
        static let blobColors = [color(0x2EC5FF), color(0x6AF2C6), color(0xFF6FD8), color(0xB36BFF)]
        static let blobSpeeds: [Double] = [0.9, -0.7, 0.6, -1.1]
        static let blobPhases: [Double] = [0, 1.6, 3.2, 4.7]
        static let highlightColors = [color(0xFFFFFF, alpha: 179.0 / 255), color(0xFFFFFF, alpha: 0.2), color(0xFFFFFF, alpha: 0)]
        static let shadeColors = [color(0x100A40, alpha: 85.0 / 255), color(0x100A40, alpha: 0)]
        static let lightLocations: [CGFloat] = [0, 0.45, 1]

        static func color(_ rgb: UInt32, alpha: CGFloat = 1) -> CGColor {
            UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                    green: CGFloat((rgb >> 8) & 0xFF) / 255,
                    blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha).cgColor
        }
    }

    private final class AnimationTarget: NSObject {
        weak var owner: VoiceOrbView?

        init(owner: VoiceOrbView) {
            self.owner = owner
        }

        @objc func tick(_ link: CADisplayLink) {
            owner?.tick(link)
        }
    }

    private let glowLayer = CALayer()
    private let bodyLayer = CALayer()
    private let bodyMask = CAShapeLayer()
    private let blobLayers = Style.blobColors.map { _ in CALayer() }
    private let highlightLayer = CALayer()
    private let shadeLayer = CALayer()
    private var displayLink: CADisplayLink?
    private var state: AICallState = .idle
    private var targetLevel: Double = 0
    private var displayedLevel: Double = 0
    private var smoothEnergy: Double = 0.2
    private var smoothBoost: Double = 0
    private var animationTime: Double = 0
    private var lastTimestamp: TimeInterval = 0
    private var gradientDiameter: CGFloat = 0
    private var gradientScale: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(glowLayer)
        layer.addSublayer(bodyLayer)
        bodyLayer.backgroundColor = Style.baseColor
        bodyMask.fillColor = UIColor.white.cgColor
        bodyLayer.mask = bodyMask
        blobLayers.forEach { bodyLayer.addSublayer($0) }
        bodyLayer.addSublayer(highlightLayer)
        bodyLayer.addSublayer(shadeLayer)
        NotificationCenter.default.addObserver(self, selector: #selector(pauseAnimation),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAnimation),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAnimation),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override var isHidden: Bool {
        didSet {
            if isHidden { stopAnimating() } else { startAnimating() }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildGradientsIfNeeded()
        renderFrame()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            setNeedsLayout()
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    func setState(_ newState: AICallState) {
        guard state != newState else { return }
        state = newState
        if newState != .speaking {
            targetLevel = 0
            displayedLevel = 0
        }
        if UIAccessibility.isReduceMotionEnabled {
            smoothEnergy = targetEnergy
            smoothBoost = 0
            renderFrame()
        }
    }

    func setLevel(_ level: Float) {
        targetLevel = state == .speaking && level.isFinite ? Double(min(max(level, 0), 1)) : 0
    }

    private var targetEnergy: Double {
        switch state {
        case .idle: return 0.2
        case .listening: return 0.4
        case .thinking: return 0.7
        case .speaking: return 0.55 + 0.35 * displayedLevel
        }
    }

    private func startAnimating() {
        guard displayLink == nil, window != nil, !isHidden,
              UIApplication.shared.applicationState != .background,
              !UIAccessibility.isReduceMotionEnabled else { return }
        lastTimestamp = 0
        let target = AnimationTarget(owner: self)
        let link = CADisplayLink(target: target, selector: #selector(AnimationTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    @objc private func pauseAnimation() {
        stopAnimating()
    }

    @objc private func resumeAnimation() {
        stopAnimating()
        startAnimating()
        setNeedsLayout()
    }

    private func tick(_ link: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 0 : min(max(link.timestamp - lastTimestamp, 0), Style.maximumFrameInterval)
        lastTimestamp = link.timestamp
        let level = state == .speaking ? targetLevel : 0
        let response = level > displayedLevel ? Style.levelAttack : Style.levelRelease
        displayedLevel += (level - displayedLevel) * (1 - pow(1 - response, dt * Style.referenceFrameRate))
        if abs(displayedLevel - level) < Style.levelTolerance { displayedLevel = level }
        smoothEnergy += (targetEnergy - smoothEnergy) * (1 - exp(-dt * Style.energyResponse))
        let boost = state == .speaking ? displayedLevel : 0
        smoothBoost += (boost - smoothBoost) * (1 - exp(-dt * Style.boostResponse))
        animationTime += dt * (0.5 + 1.3 * smoothEnergy)
        renderFrame()
    }

    private func rebuildGradientsIfNeeded() {
        let diameter = min(bounds.width, bounds.height)
        let scale = window?.screen.scale ?? traitCollection.displayScale
        guard diameter > 0, scale > 0, diameter != gradientDiameter || scale != gradientScale else { return }
        gradientDiameter = diameter
        gradientScale = scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let maxRadius = diameter / 2
        let baseRadius = maxRadius * Style.baseRadiusRatio
        glowLayer.contents = Self.radialImage(colors: Style.glowColors, locations: Style.glowLocations,
                                             diameter: maxRadius * Style.glowRadiusRatio * 2, scale: scale)
        for (index, blob) in blobLayers.enumerated() {
            let color = Style.blobColors[index]
            blob.contents = Self.radialImage(colors: [color, color.copy(alpha: 0.55)!, color.copy(alpha: 0)!],
                                            locations: Style.lightLocations, diameter: baseRadius * Style.blobRadiusRatio * 2, scale: scale)
        }
        highlightLayer.contents = Self.radialImage(colors: Style.highlightColors, locations: Style.lightLocations,
                                                  diameter: baseRadius * Style.highlightRadiusRatio * 2, scale: scale)
        shadeLayer.contents = Self.radialImage(colors: Style.shadeColors, locations: [0, 1],
                                              diameter: baseRadius * Style.shadeRadiusRatio * 2, scale: scale)
    }

    private static func radialImage(colors: [CGColor], locations: [CGFloat], diameter: CGFloat, scale: CGFloat) -> CGImage? {
        let pixels = Int(ceil(diameter * scale))
        guard pixels > 0,
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                      bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else { return nil }
        let center = CGPoint(x: CGFloat(pixels) / 2, y: CGFloat(pixels) / 2)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: CGFloat(pixels) / 2, options: [])
        return context.makeImage()
    }

    private func renderFrame() {
        let maxRadius = min(bounds.width, bounds.height) / 2
        guard maxRadius > 0 else { return }
        let baseRadius = maxRadius * Style.baseRadiusRatio
        let t = animationTime
        let radius = baseRadius * CGFloat(0.86 + 0.018 * sin(t * 1.6) + 0.1 * smoothBoost)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let localCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let glowScale = CGFloat(1 + 0.03 * (sin(t * 1.2) + 1) + 0.12 * smoothBoost)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = Self.frame(center: center, radius: maxRadius * Style.glowRadiusRatio * glowScale)
        glowLayer.opacity = Float(0.8 + 0.2 * smoothEnergy)
        bodyLayer.frame = bounds
        bodyMask.frame = bodyLayer.bounds
        bodyMask.path = Self.bodyPath(center: localCenter, radius: radius, time: t, energy: smoothEnergy)
        for (index, blob) in blobLayers.enumerated() {
            let angle = t * Style.blobSpeeds[index] + Style.blobPhases[index]
            let orbit = radius * CGFloat(0.42 + 0.08 * sin(t * 0.7 + Double(index)))
            let blobCenter = CGPoint(x: localCenter.x + CGFloat(cos(angle)) * orbit,
                                     y: localCenter.y + CGFloat(sin(angle)) * orbit * 0.9)
            blob.frame = Self.frame(center: blobCenter, radius: radius * Style.blobRadiusRatio)
        }
        highlightLayer.frame = Self.frame(center: CGPoint(x: localCenter.x - radius * 0.3, y: localCenter.y - radius * 0.38),
                                          radius: radius * Style.highlightRadiusRatio)
        shadeLayer.frame = Self.frame(center: CGPoint(x: localCenter.x + radius * 0.38, y: localCenter.y + radius * 0.5),
                                      radius: radius * Style.shadeRadiusRatio)
        CATransaction.commit()
    }

    private static func frame(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private static func bodyPath(center: CGPoint, radius: CGFloat, time: Double, energy: Double) -> CGPath {
        let amplitude = radius * CGFloat(0.01 + 0.03 * energy)
        let points = (0..<Style.pointCount).map { index -> CGPoint in
            let theta = Double(index) * 2 * .pi / Double(Style.pointCount)
            let modulation = 0.6 * sin(2 * theta + time * 1.3) + 0.4 * sin(3 * theta - time * 0.9)
            let r = radius + amplitude * CGFloat(modulation)
            return CGPoint(x: center.x + r * CGFloat(cos(theta)), y: center.y + r * CGFloat(sin(theta)))
        }
        let path = CGMutablePath()
        let first = points[0]
        let last = points[Style.pointCount - 1]
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for (index, point) in points.enumerated() {
            let next = points[(index + 1) % Style.pointCount]
            path.addQuadCurve(to: CGPoint(x: (point.x + next.x) / 2, y: (point.y + next.y) / 2), control: point)
        }
        path.closeSubpath()
        return path
    }
}
