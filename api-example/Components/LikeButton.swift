import UIKit
import SnapKit
import Combine
import AtomicXCore

/**
 * Like button component (Douyin-style particle animation)
 *
 * APIs involved:
 * - LikeStore.create(liveID:) - create a like management instance
 * - LikeStore.sendLike(count:completion:) - send a like
 * - LikeStore.likeEventPublisher - likeevent subscription (LikeEvent.onReceiveLikesMessage)
 *
 * Features:
 * - floating circular like button
 * - Play a Douyin-style particle animation when tapped or when likes are received from others (hearts float along a curve, scale and rotate, then fade out)
 */
class LikeButton: UIView {

    // MARK: - Properties

    private let liveID: String
    private lazy var likeStore = LikeStore.create(liveID: liveID)
    private var cancellables = Set<AnyCancellable>()

    /// heart color palette (Douyin-style multicolor gradient)
    private let heartColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.25, blue: 0.42, alpha: 1.0),   // pink
        UIColor(red: 1.0, green: 0.40, blue: 0.40, alpha: 1.0),   // coral red
        UIColor(red: 0.95, green: 0.30, blue: 0.60, alpha: 1.0),  // rose red
        UIColor(red: 0.80, green: 0.20, blue: 0.80, alpha: 1.0),  // purple
        UIColor(red: 0.40, green: 0.60, blue: 1.0, alpha: 1.0),   // blue-violet
        UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0),    // orange
        UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0),    // golden yellow
    ]

    /// heart icon size range
    private let heartSizeRange: ClosedRange<CGFloat> = 20...36

    // MARK: - UI Components

    /// like button
    private let button: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.setImage(UIImage(systemName: "heart.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemPink
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        return button
    }()

    // MARK: - Init

    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
        setupUI()
        setupBindings()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        clipsToBounds = false

        addSubview(button)

        button.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(40)
        }

        self.snp.makeConstraints { make in
            make.width.equalTo(50)
            make.height.equalTo(50)
        }
    }

    private func setupBindings() {
        // Subscribe to received like events and play the particle animation
        likeStore.likeEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .onReceiveLikesMessage(_, _, _):
                    self?.emitParticles(count: 1)
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func setupActions() {
        button.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    /// send a like
    @objc private func likeTapped() {
        likeStore.sendLike(count: 1, completion: nil)

        // button scale feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.button.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.button.transform = .identity
            }
        }

        // play particles when liking locally as well
        emitParticles(count: 1)
    }

    // MARK: - Particle Animation (Douyin-style)

    /// Emit particle heart animations
    /// - Parameter count: number of particles to emit
    private func emitParticles(count: Int) {
        for i in 0..<count {
            let delay = Double(i) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.launchSingleHeart()
            }
        }
    }

    /// Emit a single heart particle that floats along a Bézier curve
    private func launchSingleHeart() {
        let heartSize = CGFloat.random(in: heartSizeRange)
        let heartView = createHeartView(size: heartSize)

        addSubview(heartView)

        // start point: directly above the button
        let startX = button.center.x
        let startY = button.frame.minY - heartSize / 2
        heartView.center = CGPoint(x: startX, y: startY)

        // initial scale: pop in from small to large
        heartView.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)

        // end point: float upward 120~220pt, random left/right offset
        let endY = startY - CGFloat.random(in: 120...220)
        let endX = startX + CGFloat.random(in: -50...50)

        // Bézier curve control points (S S-shaped drift)
        let controlPoint1 = CGPoint(
            x: startX + CGFloat.random(in: -40...40),
            y: startY - CGFloat.random(in: 40...80)
        )
        let controlPoint2 = CGPoint(
            x: endX + CGFloat.random(in: -30...30),
            y: endY + CGFloat.random(in: 20...60)
        )

        // path animation
        let path = UIBezierPath()
        path.move(to: heartView.center)
        path.addCurve(to: CGPoint(x: endX, y: endY),
                      controlPoint1: controlPoint1,
                      controlPoint2: controlPoint2)

        let pathAnimation = CAKeyframeAnimation(keyPath: "position")
        pathAnimation.path = path.cgPath
        pathAnimation.duration = CFTimeInterval(CGFloat.random(in: 2.0...3.0))
        pathAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pathAnimation.fillMode = .forwards
        pathAnimation.isRemovedOnCompletion = false

        // rotation animation (slight sway)
        let rotationAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let maxAngle = CGFloat.random(in: 0.2...0.5)
        rotationAnimation.values = [0, maxAngle, -maxAngle, maxAngle * 0.5, 0]
        rotationAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        rotationAnimation.duration = pathAnimation.duration
        rotationAnimation.fillMode = .forwards
        rotationAnimation.isRemovedOnCompletion = false

        // combined animation
        let group = CAAnimationGroup()
        group.animations = [pathAnimation, rotationAnimation]
        group.duration = pathAnimation.duration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        heartView.layer.add(group, forKey: "particleAnimation")

        // scale + alpha (UIView animation, combined with CAAnimation)
        let totalDuration = pathAnimation.duration
        // Phase 1: pop and enlarge
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0.8, options: [], animations: {
            heartView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        })

        // Phase 2: shrink and fade out in the latter half
        UIView.animate(withDuration: totalDuration * 0.6, delay: totalDuration * 0.4,
                       options: .curveEaseIn, animations: {
            heartView.alpha = 0
            heartView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        }) { _ in
            heartView.layer.removeAllAnimations()
            heartView.removeFromSuperview()
        }
    }

    /// Create the heart icon view
    private func createHeartView(size: CGFloat) -> UIImageView {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        let heartImage = UIImage(systemName: "heart.fill", withConfiguration: config)
        let imageView = UIImageView(image: heartImage)
        imageView.tintColor = heartColors.randomElement()
        imageView.contentMode = .scaleAspectFit
        imageView.frame.size = CGSize(width: size, height: size)
        return imageView
    }
}
