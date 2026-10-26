import AtomicXCore
import UIKit

public struct NavigationInfo {
    public let conversation: ConversationInfo
    public let locateMessage: MessageInfo?

    public init(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        self.conversation = conversation
        self.locateMessage = locateMessage
    }
}

public final class ConversationsPage: UIViewController {
    private let implementation: ConversationsPageImpl

    public init(
        config: ConversationActionConfig? = nil,
        onConversationClick: ((NavigationInfo) -> Void)? = nil
    ) {
        implementation = ConversationsPageImpl(config: config ?? ConversationActionConfig(), onConversationClick: onConversationClick)
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
