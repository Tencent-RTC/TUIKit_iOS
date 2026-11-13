import AtomicXCore
import Combine
import UIKit

/// G2 "more settings" page.
final class CallSettingsViewController: UIViewController {

    private let settingsView = CallSettingsView()
    private var cancellables = Set<AnyCancellable>()

    override func loadView() {
        view = settingsView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = CallAccessText.settingsTitle
        configureNavigationBar()
        observeProfile()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = CallAccessTheme.pageBackground
        appearance.shadowColor = nil
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(hex: 0x181A1C),
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.backButtonDisplayMode = .minimal
    }

    private func observeProfile() {
        LoginStore.shared.state
            .subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loginState in
                self?.settingsView.updateProfile(loginState.loginUserInfo)
            }
            .store(in: &cancellables)
    }
}
