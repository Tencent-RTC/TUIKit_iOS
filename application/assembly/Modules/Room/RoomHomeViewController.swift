import TUIRoomKit
import UIKit
import AtomicXCore

public final class RoomHomeViewController: UIViewController, RouterContext {

    public var onLoggedOut: (() -> Void)? {
        get { rootView.onLoggedOut }
        set { rootView.onLoggedOut = newValue }
    }

    private lazy var rootView: RoomHomeView = {
        let view = RoomHomeView()
        view.routerContext = self
        return view
    }()

    public init() {
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
