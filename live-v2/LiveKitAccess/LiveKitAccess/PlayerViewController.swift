import TUILiveKit
import UIKit

final class PlayerViewController: UIViewController {
    private let liveListView: LiveListView
    private let listStore = LiveSelectListStore()

    init(liveID: String) {
        liveListView = LiveListView(liveID: liveID)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = liveListView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        liveListView.onLoadMore = { [weak self] in self?.listStore.loadMore() }
        listStore.onStateChanged = { [weak self] state in
            self?.liveListView.setData(state.liveList)
        }
        listStore.refresh()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    private func goBack() {
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension PlayerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}
