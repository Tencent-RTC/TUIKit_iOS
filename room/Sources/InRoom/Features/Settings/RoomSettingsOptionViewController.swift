import UIKit

final class RoomSettingsOptionsViewController: UIViewController, RouterContext {

    private lazy var rootView: RoomSettingsOptionsView = {
        let view = RoomSettingsOptionsView(mode: mode)
        view.routerContext = self
        return view
    }()

    private let mode: RoomSettingsOptionsView.Mode

    init(mode: RoomSettingsOptionsView.Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = rootView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }
}
