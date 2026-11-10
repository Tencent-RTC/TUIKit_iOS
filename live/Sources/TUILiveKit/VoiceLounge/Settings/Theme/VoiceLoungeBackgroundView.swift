import ImageIO
import UIKit

final class VoiceLoungeBackgroundView: UIView {
    private let staticImageView = UIImageView()
    private let gifLayer = CALayer()

    private var displayLink: CADisplayLink?
    private var imageSource: CGImageSource?
    private var frameDelays: [CFTimeInterval] = []
    private var frameIndex = 0
    private var accumulated: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var currentBackgroundID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ background: VoiceLoungeBackground) {
        guard background.id != currentBackgroundID else { return }
        currentBackgroundID = background.id
        stopAnimation()

        staticImageView.image = background.image
        staticImageView.isHidden = false
        gifLayer.isHidden = true
        gifLayer.contents = nil

        if let url = background.gifURL, let data = try? Data(contentsOf: url) { startAnimation(data: data) }
    }

    private func setupViews() {
        addSubview(staticImageView)
        layer.addSublayer(gifLayer)
    }

    private func setupConstraints() {}

    private func setupStyles() {
        staticImageView.contentMode = .scaleAspectFill
        staticImageView.clipsToBounds = true
        gifLayer.contentsGravity = .resizeAspectFill
        gifLayer.masksToBounds = true
        gifLayer.isHidden = true
    }

    private func setupBindings() {}

    override func layoutSubviews() {
        super.layoutSubviews()
        staticImageView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gifLayer.frame = bounds
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
        } else if imageSource != nil, displayLink == nil {
            startDisplayLink()
        }
    }

    private func startAnimation(data: Data) {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            if let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) { staticImageView.image = UIImage(cgImage: cg) }
            return
        }
        imageSource = source
        frameDelays = (0..<count).map { Self.frameDelay(source: source, index: $0) }
        frameIndex = 0
        accumulated = 0

        renderFrame(at: 0)
        gifLayer.isHidden = false
        staticImageView.isHidden = true

        if window != nil { startDisplayLink() }
    }

    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        imageSource = nil
        frameDelays = []
    }

    private func renderFrame(at index: Int) {
        guard let source = imageSource, let cg = CGImageSourceCreateImageAtIndex(source, index, nil) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gifLayer.contents = cg
        CATransaction.commit()
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> CFTimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }

    deinit { displayLink?.invalidate() }
}

extension VoiceLoungeBackgroundView {
    @objc private func step(_ link: CADisplayLink) {
        guard !frameDelays.isEmpty else { return }
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        accumulated += link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp

        var advanced = false
        while accumulated >= frameDelays[frameIndex] {
            accumulated -= frameDelays[frameIndex]
            frameIndex = (frameIndex + 1) % frameDelays.count
            advanced = true
        }
        if advanced { renderFrame(at: frameIndex) }
    }
}
