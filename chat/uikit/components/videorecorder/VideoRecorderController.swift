import UIKit

public final class VideoRecorderController: UIViewController {
    private let implementation: VideoRecorderControllerImpl

    public init(config: VideoRecorderConfig? = nil,
         onVideoCaptured: @escaping (_ path: String?, _ durationMs: Int, _ thumbnailPath: String?) -> Void,
         onPhotoCaptured: @escaping (_ path: String?) -> Void) {
        implementation = VideoRecorderControllerImpl(
            config: config,
            onVideoCaptured: onVideoCaptured,
            onPhotoCaptured: onPhotoCaptured
        )
        super.init(nibName: nil, bundle: nil)
        implementation.owner = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        implementation.viewDidLoad()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        implementation.viewWillAppear(animated)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        implementation.viewWillDisappear(animated)
    }
}
