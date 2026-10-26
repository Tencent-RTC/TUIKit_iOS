import AtomicXCore
import UIKit

public final class ContactsPage: UIViewController {
    private let implementation: ContactsPageImpl

    public init(
        config: ContactListConfig? = nil,
        onContactClick: ((ContactInfo) -> Void)? = nil,
        onGroupClick: ((GroupInfo) -> Void)? = nil
    ) {
        implementation = ContactsPageImpl(config: config ?? ContactListConfig(), onContactClick: onContactClick, onGroupClick: onGroupClick)
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
