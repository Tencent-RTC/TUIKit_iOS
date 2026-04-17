//
//  LiveListTransitioningDelegate.swift
//  TUILiveKit
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

    /// - Parameters:
    ///   - originFrame: cell 在屏幕上的 frame
    ///   - snapshotView: single column 模式下传入 presenting VC 的截图，用于遮盖转场过程
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

        // single column 模式：在 containerView 最上层添加截图遮罩
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
            // 转场完成后，将截图遮罩转移到 presented VC 的 view 上保留，等待外部在进房成功后移除
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

    /// - Parameters:
    ///   - originFrame: cell 在屏幕上的 frame
    ///   - snapshotView: single column 模式下传入 presenting VC 的截图，用于遮盖转场黑屏
    init(originFrame: CGRect, snapshotView: UIView? = nil) {
        self.originFrame = originFrame
        self.snapshotView = snapshotView
    }

    /// 进房成功后调用，淡出并移除截图遮罩
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
