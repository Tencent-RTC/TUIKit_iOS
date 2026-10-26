import AtomicXCore
import UIKit

public final class ChatPage: UIViewController {
    private let implementation: ChatPageImpl

    public init(
        conversation: ConversationInfo,
        locateMessage: MessageInfo? = nil,
        messageListConfig: ChatMessageListConfig? = nil,
        messageInputConfig: ChatMessageInputConfig? = nil,
        isShowMoreButton: Bool = true,
        showsNavigationBar: Bool = true,
        onBack: (() -> Void)? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMoreClick: (() -> Void)? = nil
    ) {
        implementation = ChatPageImpl(
            conversation: conversation, locateMessage: locateMessage,
            messageListConfig: messageListConfig ?? ChatMessageListConfig(isShowRightAvatar: true),
            messageInputConfig: messageInputConfig ?? ChatMessageInputConfig(),
            isShowMoreButton: isShowMoreButton, showsNavigationBar: showsNavigationBar,
            onBack: onBack, onUserClick: onUserClick, onMoreClick: onMoreClick
        )
        super.init(nibName: nil, bundle: nil)
        implementation.owner = self
    }
    
    public var topBannerView: UIView? {
        get { implementation.topBannerView }
        set { implementation.topBannerView = newValue }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        implementation.viewDidLoad()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        implementation.viewDidLayoutSubviews()
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
