import UIKit
import AtomicXCore
import Combine

final class LikeAnimationView: UIView {
    private enum Constants {
        static let mainSize: CGFloat = 52
        static let mainDuration: TimeInterval = 0.66
        static let auxiliarySize: CGFloat = 24
        static let maximumAuxiliaryCount = 14
        static let buttonSize: CGFloat = 36
        static let maximumButtonCount = 14
        static let reactionAssetNames = [
            "livekit_like_thumb",
            "livekit_like_thumb",
            "livekit_like_heart",
            "livekit_like_heart",
            "livekit_like_double_heart",
            "livekit_like_fire",
            "livekit_like_sparkle",
        ]
    }

    private var auxiliaryViews: [UIImageView] = []
    private var buttonViews: [UIImageView] = []
    private var likeStore: LikeStore?
    private var likeCancellables = Set<AnyCancellable>()
    private var auxiliaryOriginProvider: (() -> CGPoint)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func activate(liveID: String, auxiliaryOriginProvider: @escaping () -> CGPoint) {
        deactivate()
        self.auxiliaryOriginProvider = auxiliaryOriginProvider
        let store = LikeStore.create(liveID: liveID)
        likeStore = store
        store.likeEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                if case let .onReceiveLikesMessage(eventLiveID, totalLikesReceived, _) = event,
                   eventLiveID == liveID {
                    let origin = self.auxiliaryOriginProvider?() ?? .zero
                    self.showReceivedLikes(
                        count: Int(min(totalLikesReceived, 6)),
                        auxiliaryOrigin: origin
                    )
                }
            }
            .store(in: &likeCancellables)
    }

    func deactivate() {
        likeCancellables.removeAll()
        likeStore = nil
        auxiliaryOriginProvider = nil
    }

    func showStageLike(at point: CGPoint, auxiliaryOrigin: CGPoint) {
        let assetName = randomAssetName()
        showMainReaction(at: point, assetName: assetName)
        showAuxiliaryReaction(from: auxiliaryOrigin, assetName: assetName)
    }

    func showReceivedLikes(count: Int, auxiliaryOrigin: CGPoint) {
        let animationCount = min(6, max(1, count))
        for index in 0..<animationCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.12) { [weak self] in
                guard let self, self.window != nil else { return }
                self.showAuxiliaryReaction(from: auxiliaryOrigin, assetName: self.randomAssetName())
            }
        }
    }

    func showButtonLike(from origin: CGPoint) {
        showButtonReaction(from: origin, assetName: randomAssetName())
    }

    func removeAllAnimations() {
        layer.removeAllAnimations()
        subviews.forEach {
            $0.layer.removeAllAnimations()
            $0.removeFromSuperview()
        }
        auxiliaryViews.removeAll()
        buttonViews.removeAll()
    }

    private func showMainReaction(at point: CGPoint, assetName: String) {
        guard let image = LiveKitResources.image(named: assetName) else { return }
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(
            x: point.x - Constants.mainSize * 0.5,
            y: point.y - Constants.mainSize,
            width: Constants.mainSize,
            height: Constants.mainSize
        )
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = 0.3
        imageView.layer.shadowOffset = CGSize(width: 0, height: 5)
        imageView.layer.shadowRadius = 7
        imageView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.62)
        imageView.layer.position = CGPoint(
            x: imageView.frame.midX,
            y: imageView.frame.minY + Constants.mainSize * 0.62
        )
        addSubview(imageView)

        let transforms = CAKeyframeAnimation(keyPath: "transform")
        transforms.values = [
            transform(scale: 0.04, rotation: -28, translationY: 0),
            transform(scale: 1, rotation: -28, translationY: 0),
            transform(scale: 1, rotation: 8, translationY: 0),
            transform(scale: 1, rotation: -4, translationY: 0),
            transform(scale: 1.18, rotation: -4, translationY: -6),
        ].map(NSValue.init(caTransform3D:))
        transforms.keyTimes = [0, 0.30303, 0.51515, 0.65152, 1]
        transforms.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.2, 0.82, 0.32, 1),
            CAMediaTimingFunction(controlPoints: 0.18, 0.72, 0.24, 1),
            CAMediaTimingFunction(controlPoints: 0.24, 0.76, 0.3, 1),
            CAMediaTimingFunction(name: .easeOut),
        ]

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 1, 1, 1, 0]
        opacity.keyTimes = transforms.keyTimes

        let group = CAAnimationGroup()
        group.animations = [transforms, opacity]
        group.duration = Constants.mainDuration
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        imageView.layer.add(group, forKey: "livekit.mainLike")

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.mainDuration) { [weak imageView] in
            imageView?.removeFromSuperview()
        }
    }

    private func showAuxiliaryReaction(from origin: CGPoint, assetName: String) {
        guard let image = LiveKitResources.image(named: assetName) else { return }
        if auxiliaryViews.count >= Constants.maximumAuxiliaryCount {
            let earliest = auxiliaryViews.removeFirst()
            earliest.layer.removeAllAnimations()
            earliest.removeFromSuperview()
        }

        let originOffsetX = CGFloat.random(in: -8...8)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(
            x: origin.x + originOffsetX - Constants.auxiliarySize * 0.5,
            y: origin.y - Constants.auxiliarySize * 0.5,
            width: Constants.auxiliarySize,
            height: Constants.auxiliarySize
        )
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = 0.24
        imageView.layer.shadowOffset = CGSize(width: 0, height: 3)
        imageView.layer.shadowRadius = 5
        addSubview(imageView)
        auxiliaryViews.append(imageView)

        let rise = CGFloat.random(in: 120...140)
        let x1 = -CGFloat.random(in: 4...6)
        let x2 = -CGFloat.random(in: 1...3)
        let x3 = -CGFloat.random(in: 5...7)
        let x4 = -CGFloat.random(in: 3...5)

        let transform = CAKeyframeAnimation(keyPath: "transform.translation")
        transform.values = [
            NSValue(cgSize: .zero),
            NSValue(cgSize: CGSize(width: x1, height: -rise * 0.34)),
            NSValue(cgSize: CGSize(width: x2, height: -rise * 0.66)),
            NSValue(cgSize: CGSize(width: x3, height: -rise * 0.78)),
            NSValue(cgSize: CGSize(width: x4, height: -rise)),
        ]
        transform.keyTimes = [0, 0.34, 0.66, 0.78, 1]

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.38, 0.38, 0.38, 0.38, 0]
        opacity.keyTimes = transform.keyTimes

        let duration = TimeInterval.random(in: 1.8...2.05)
        let group = CAAnimationGroup()
        group.animations = [transform, opacity]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        imageView.layer.add(group, forKey: "livekit.auxiliaryLike")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak imageView] in
            guard let self, let imageView else { return }
            imageView.removeFromSuperview()
            self.auxiliaryViews.removeAll { $0 === imageView }
        }
    }

    private func showButtonReaction(from origin: CGPoint, assetName: String) {
        guard let image = LiveKitResources.image(named: assetName) else { return }
        if buttonViews.count >= Constants.maximumButtonCount {
            let earliest = buttonViews.removeFirst()
            earliest.layer.removeAllAnimations()
            earliest.removeFromSuperview()
        }

        let originOffsetX = CGFloat.random(in: -5...5)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(
            x: origin.x + originOffsetX - Constants.buttonSize * 0.5,
            y: origin.y - Constants.buttonSize * 0.5,
            width: Constants.buttonSize,
            height: Constants.buttonSize
        )
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = 0.28
        imageView.layer.shadowOffset = CGSize(width: 0, height: 3)
        imageView.layer.shadowRadius = 5
        addSubview(imageView)
        buttonViews.append(imageView)

        let rise = CGFloat.random(in: 120...150)
        let x1 = -CGFloat.random(in: 4...6)
        let x2 = -CGFloat.random(in: 1...3)
        let x3 = -CGFloat.random(in: 5...7)
        let x4 = -CGFloat.random(in: 3...5)

        let transform = CAKeyframeAnimation(keyPath: "transform")
        transform.values = [
            buttonTransform(x: 0, y: 0, scale: 0.2),
            buttonTransform(x: 0, y: -70, scale: 1),
            buttonTransform(x: x1, y: -(70 + rise * 0.34), scale: 1),
            buttonTransform(x: x2, y: -(70 + rise * 0.66), scale: 1),
            buttonTransform(x: x3, y: -(70 + rise * 0.78), scale: 1),
            buttonTransform(x: x4, y: -(70 + rise), scale: 1),
        ].map(NSValue.init(caTransform3D:))
        transform.keyTimes = [0, 0.125, 0.4225, 0.7025, 0.8075, 1]
        transform.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.16, 0.78, 0.24, 1),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .linear),
        ]

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 1, 0.66, 0.34, 0.22, 0]
        opacity.keyTimes = transform.keyTimes

        let duration = TimeInterval.random(in: 1.5...1.7)
        let group = CAAnimationGroup()
        group.animations = [transform, opacity]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        imageView.layer.add(group, forKey: "livekit.buttonLike")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak imageView] in
            guard let self, let imageView else { return }
            imageView.removeFromSuperview()
            self.buttonViews.removeAll { $0 === imageView }
        }
    }

    private func randomAssetName() -> String {
        Constants.reactionAssetNames.randomElement() ?? "livekit_like_heart"
    }

    private func transform(scale: CGFloat, rotation: CGFloat, translationY: CGFloat) -> CATransform3D {
        var value = CATransform3DMakeTranslation(0, translationY, 0)
        value = CATransform3DRotate(value, rotation * .pi / 180, 0, 0, 1)
        return CATransform3DScale(value, scale, scale, 1)
    }

    private func buttonTransform(x: CGFloat, y: CGFloat, scale: CGFloat) -> CATransform3D {
        var value = CATransform3DMakeScale(scale, scale, 1)
        value.m41 = x
        value.m42 = y
        return value
    }
}
