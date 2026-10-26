import UIKit

public final class AICallViewController: UIViewController {
    private let implementation: AICallViewControllerImpl

    public init(robotUserID: String, config: AICallConfig? = nil) {
        implementation = AICallViewControllerImpl(robotUserID: robotUserID, config: config ?? AICallConfig())
        super.init(nibName: nil, bundle: nil)
        implementation.owner = self
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    public override func viewDidLoad() {
        super.viewDidLoad()
        implementation.viewDidLoad()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        implementation.viewDidDisappear(animated)
    }
}
