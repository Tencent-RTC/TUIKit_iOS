import UIKit

public final class GroupChatSettingViewController: CustomNavigationBarViewController {
    private let implementation: GroupChatSettingViewControllerImpl

    public init(
        groupID: String,
        config: GroupChatSettingConfig? = nil,
        onSendMessageClick: (() -> Void)? = nil,
        onGroupDelete: (() -> Void)? = nil,
        onGroupMemberClick: ((String) -> Void)? = nil
    ) {
        implementation = GroupChatSettingViewControllerImpl(
            groupID: groupID,
            config: config ?? GroupChatSettingConfig(isShowHeader: nil),
            onSendMessageClick: onSendMessageClick,
            onGroupDelete: onGroupDelete,
            onGroupMemberClick: onGroupMemberClick
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

    func openMemberDetail(userID: String) {
        implementation.openMemberDetail(userID: userID)
    }
}
