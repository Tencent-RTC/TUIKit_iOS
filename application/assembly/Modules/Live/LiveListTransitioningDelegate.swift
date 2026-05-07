//
//  LiveListTransitioningDelegate.swift
//  Assembly
//
//  Created by gg on 2025/4/16.
//

import UIKit

// MARK: - LiveListPresentationController

class LiveListPresentationController: UIPresentationController {
    override var shouldRemovePresentersView: Bool {
        return true
    }
}

// MARK: - LiveListPresentAnimation

class LiveListPresentAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    let originFrame: CGRect
    private let snapshotView: UIView?

    init(originFrame: CGRect, snapshotView: UIView? = nil) {
        self.originFrame = originFrame
        self.snapshotView = snapshotView
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) else { return }
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toVC)

        containerView.addSubview(toVC.view)
        toVC.view.frame = originFrame
        toVC.view.layoutIfNeeded()
        toVC.view.clipsToBounds = true

        if let snapshotView = snapshotView {
            snapshotView.frame = containerView.bounds
            containerView.addSubview(snapshotView)
        }

        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
            toVC.view.frame = finalFrame
        }, completion: { [weak self] _ in
            guard let self else {
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }
            if let snapshotView = self.snapshotView {
                snapshotView.removeFromSuperview()
                toVC.view.addSubview(snapshotView)
                snapshotView.frame = toVC.view.bounds
                snapshotView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

// MARK: - LiveListTransitioningDelegate

class LiveListTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    let originFrame: CGRect
    private(set) var snapshotView: UIView?

    init(originFrame: CGRect, snapshotView: UIView? = nil) {
        self.originFrame = originFrame
        self.snapshotView = snapshotView
    }

    func dismissSnapshotOverlay() {
        guard let snapshotView = snapshotView else { return }
        UIView.animate(withDuration: 0.3, animations: {
            snapshotView.alpha = 0
        }, completion: { _ in
            snapshotView.removeFromSuperview()
        })
        self.snapshotView = nil
    }

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return LiveListPresentAnimation(originFrame: originFrame, snapshotView: snapshotView)
    }

    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        return LiveListPresentationController(presentedViewController: presented, presenting: presenting)
    }
}
