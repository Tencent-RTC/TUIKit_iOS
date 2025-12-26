//
//  CoHostSoundWaveView.swift
//  Pods
//
//  Created by ssc on 2025/9/24.
//

class CoHostSoundWaveView: UIView {
    private var isAnimating = false
    private let rippleDuration: CFTimeInterval = 2

    private func setupRippleLayers() {
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let layers = [
            createRippleLayer(color: .seatWaveColor, lineWidth: 5.0),
            createRippleLayer(color: .seatWaveColor, lineWidth: 5.0)
        ]
        layers.forEach {
            $0.opacity = 0
            self.layer.addSublayer($0)
        }
    }

    private func createRippleLayer(color: UIColor, lineWidth: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = self.bounds
        layer.path = UIBezierPath(roundedRect: self.bounds,
                                  cornerRadius: self.bounds.width/2).cgPath
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = color.cgColor
        layer.lineWidth = lineWidth

        return layer
    }

    func startRippleAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        layoutIfNeeded()
        setupRippleLayers()

        guard let layers = self.layer.sublayers, layers.count >= 2 else { return }

        let innerScaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        innerScaleAnimation.fromValue = 0.2
        innerScaleAnimation.toValue = 1.0
        innerScaleAnimation.duration = rippleDuration

        let innerFadeInAnimation = CABasicAnimation(keyPath: "opacity")
        innerFadeInAnimation.fromValue = 0
        innerFadeInAnimation.toValue = 1
        innerFadeInAnimation.duration = rippleDuration * 0.2

        let innerLineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        innerLineWidthAnimation.fromValue = 20
        innerLineWidthAnimation.toValue = 2
        innerLineWidthAnimation.duration = rippleDuration

        let innerFadeOutAnimation = CABasicAnimation(keyPath: "opacity")
        innerFadeOutAnimation.fromValue = 1
        innerFadeOutAnimation.toValue = 0.2
        innerFadeOutAnimation.duration = rippleDuration * 0.6
        innerFadeOutAnimation.beginTime = rippleDuration * 0.4

        let firstInnerGroup = CAAnimationGroup()
        firstInnerGroup.animations = [innerScaleAnimation, innerFadeInAnimation, innerLineWidthAnimation, innerFadeOutAnimation]
        firstInnerGroup.duration = rippleDuration
        firstInnerGroup.repeatCount = .infinity
        firstInnerGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let secondInnerGroup = firstInnerGroup.copy() as? CAAnimationGroup
        secondInnerGroup?.beginTime = CACurrentMediaTime() + rippleDuration * 0.4

        layers[0].add(firstInnerGroup, forKey: "innerRipple1")
        layers[1].add(secondInnerGroup ?? firstInnerGroup, forKey: "innerRipple2")
    }

    private func createRippleAnimation(fromScale: CGFloat, toScale: CGFloat, duration: CFTimeInterval) -> CABasicAnimation {
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = fromScale
        anim.toValue = toScale
        anim.duration = duration
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return anim
    }

    func stopRippleAnimation() {
        isAnimating = false
        self.layer.sublayers?.forEach {
            $0.removeAllAnimations()
        }
    }
}
