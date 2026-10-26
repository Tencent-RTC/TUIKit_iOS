import UIKit

public final class C2CChatSettingViewController: CustomNavigationBarViewController {
    private let implementation: C2CChatSettingViewControllerImpl

    public init(
        userID: String,
        config: C2CChatSettingConfig? = nil,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil
    ) {
        implementation = C2CChatSettingViewControllerImpl(
            userID: userID,
            config: config ?? C2CChatSettingConfig(isShowHeader: nil),
            onSendMessageClick: onSendMessageClick,
            onContactDelete: onContactDelete
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
}
