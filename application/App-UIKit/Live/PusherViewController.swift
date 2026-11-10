import TUILiveKit
import UIKit

final class PusherViewController: UIViewController {
    var onExitAfterAccountInvalidation: (() -> Void)?
    private let pusherView: PusherView

    init(liveID: String) {
        pusherView = PusherView(liveID: liveID)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = pusherView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        pusherView.onExit = { [weak self] in
            self?.goBack()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed, let onExitAfterAccountInvalidation {
            self.onExitAfterAccountInvalidation = nil
            DispatchQueue.main.async(execute: onExitAfterAccountInvalidation)
        }
    }

    private func goBack() {
        if let onExitAfterAccountInvalidation {
            self.onExitAfterAccountInvalidation = nil
            onExitAfterAccountInvalidation()
            return
        }
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
