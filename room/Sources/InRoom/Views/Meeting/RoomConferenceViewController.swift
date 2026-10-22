import UIKit
import AtomicXCore

public final class RoomConferenceViewController: UIViewController, RouterContext {

    private lazy var rootView: RoomConferenceView = {
        let view = RoomConferenceView(roomID: roomID)
        view.routerContext = self
        view.onRoomLeft = { [weak self] in
            self?.pop(animated: true)
        }
        return view
    }()

    private let roomID: String

    public init(roomID: String) {
        self.roomID = roomID
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
