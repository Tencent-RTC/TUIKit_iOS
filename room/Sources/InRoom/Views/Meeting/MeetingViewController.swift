import UIKit
import AtomicXCore

public final class MeetingViewController: UIViewController, RouterContext {

    private lazy var rootView: MeetingView = {
        let view = MeetingView(roomID: roomID, behavior: behavior, config: config)
        view.routerContext = self
        view.onRoomLeft = { [weak self] in
            self?.pop(animated: true)
        }
        return view
    }()

    private let roomID: String
    private let behavior: RoomBehavior
    private let config: RoomConnectConfig

    public init(roomID: String, behavior: RoomBehavior, config: RoomConnectConfig) {
        self.roomID = roomID
        self.behavior = behavior
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
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
