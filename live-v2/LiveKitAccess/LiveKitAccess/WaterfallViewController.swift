import AtomicXCore
import TUILiveKit
import UIKit

final class WaterfallViewController: UIViewController, LiveSelectListViewDelegate {
    private let liveListView = LiveSelectListView()
    private let topBar = UIView()
    private let startLiveButton = UIButton(type: .system)
    private let versionButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureTopBar()
        configureLiveList()
        configureStartLiveButton()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Interactive pop may be cancelled; refresh only after this page actually appears.
        liveListView.reload()
    }

    private func configureTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("livekit_access.title", comment: "")
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)
        titleLabel.isUserInteractionEnabled = true
        let logPress = UILongPressGestureRecognizer(target: self, action: #selector(showLogs(_:)))
        logPress.minimumPressDuration = 2
        titleLabel.addGestureRecognizer(logPress)

        versionButton.setImage(UIImage(named: "app_ic_version"), for: .normal)
        versionButton.tintColor = .white
        versionButton.addTarget(self, action: #selector(showVersion), for: .touchUpInside)
        versionButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(versionButton)

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 37),
            titleLabel.heightAnchor.constraint(equalToConstant: 22),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topBar.topAnchor),
            versionButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            versionButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            versionButton.widthAnchor.constraint(equalToConstant: 24),
            versionButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    @objc private func showVersion() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let alert = UIAlertController(
            title: nil,
            message: String(format: NSLocalizedString("livekit_access.version", comment: ""), version),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("livekit_access.ok", comment: ""), style: .default))
        present(alert, animated: true)
    }

    @objc private func showLogs(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, presentedViewController == nil else { return }
        let navigation = UINavigationController(rootViewController: LogShareViewController())
        navigation.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            navigation.sheetPresentationController?.detents = [.medium(), .large()]
            navigation.sheetPresentationController?.prefersGrabberVisible = true
        }
        present(navigation, animated: true)
    }

    private func configureLiveList() {
        liveListView.delegate = self
        liveListView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(liveListView)
        NSLayoutConstraint.activate([
            liveListView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            liveListView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            liveListView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            liveListView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureStartLiveButton() {
        startLiveButton.setTitle(NSLocalizedString("livekit_access.start_live", comment: ""), for: .normal)
        startLiveButton.setImage(UIImage(named: "app_ic_add"), for: .normal)
        startLiveButton.tintColor = .white
        startLiveButton.setTitleColor(.white, for: .normal)
        startLiveButton.backgroundColor = UIColor(red: 0.20, green: 0.44, blue: 1.0, alpha: 1)
        startLiveButton.layer.cornerRadius = 28
        startLiveButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
        startLiveButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        startLiveButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        startLiveButton.addTarget(self, action: #selector(createLive), for: .touchUpInside)
        startLiveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startLiveButton)

        NSLayoutConstraint.activate([
            startLiveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startLiveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            startLiveButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    func liveSelectListView(_ view: LiveSelectListView, didSelect liveInfo: LiveInfo) {
        guard !liveInfo.liveID.isEmpty else { return }
        let loginUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        if !loginUserID.isEmpty, liveInfo.liveOwner.userID == loginUserID {
            LiveToast.show(NSLocalizedString("livekit_access.click_own_live_hint", comment: ""))
            return
        }
        navigationController?.pushViewController(
            PlayerViewController(liveID: liveInfo.liveID),
            animated: true
        )
    }

    @objc private func createLive() {
        let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        guard !userID.isEmpty else {
            let alert = UIAlertController(
                title: nil,
                message: NSLocalizedString("livekit_access.login_user_missing", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("livekit_access.ok", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }
        navigationController?.pushViewController(
            PusherViewController(liveID: "live_\(userID)"),
            animated: true
        )
    }

    @objc private func goBack() {
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        }
    }

}
