import SnapKit
import UIKit

final class CreateGroupConversationViewController: UIViewController, SystemNavigationBarPage {
    private let onComplete: (String?, String?, String?) -> Void

    private let impl = CreateGroupConversationViewControllerImpl()

    init(onComplete: @escaping (String?, String?, String?) -> Void) {
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewStyle()
        view.addSubview(impl)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        impl.onConfirm = { [weak self] members in
            self?.pushConfigGroupInfo(members: members)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        title = LocalizedChatString("CreateGroupTitle")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: AtomicXChatResources.image(named: "contact_info_back") ?? UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(handleCancel)
        )
        navigationItem.leftBarButtonItem?.tintColor = colors.textColorPrimary
    }

    private func pushConfigGroupInfo(members: [UserPickerItem]) {
        guard let navigationController = navigationController else { return }
        let config = ConfigGroupInfoViewController(
            members: members,
            onComplete: { [weak self] createdGroupID, groupName, conversationId in
                self?.navigationController?.popViewController(animated: false)
                self?.onComplete(createdGroupID, groupName, conversationId)
            },
            onBack: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        navigationController.pushViewController(config, animated: true)
    }

    @objc private func handleCancel() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
