import UIKit

public final class RoomSettingsViewController: UIViewController, RouterContext {

    private lazy var rootView: RoomSettingsView = {
        let view = RoomSettingsView(mode: mode)
        view.routerContext = self
        return view
    }()

    private let mode: RoomSettingsView.Mode

    public convenience init() {
        self.init(mode: .default)
    }

    public init(mode: RoomSettingsView.Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = rootView
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    public override var shouldAutorotate: Bool { false }
}
