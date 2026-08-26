import AtomicXCore
import SnapKit
import UIKit

final class JoinGroupViewController: ChatSettingBaseViewController {
    var onEnterGroupChat: ((GroupInfo) -> Void)?

    private let impl = JoinGroupViewControllerImpl()

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("ContactsJoinGroupTitle"))
        view.addSubview(impl)
        impl.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        impl.onEnterGroupChat = { [weak self] group in
            self?.onEnterGroupChat?(group)
        }
        impl.onJoinGroup = { [weak self] group in
            self?.pushJoinGroupDetail(group)
        }
    }

    private func pushJoinGroupDetail(_ group: GroupInfo) {
        let detail = JoinGroupDetailViewController(groupInfo: group) { [weak self] in
            self?.dismissFlow()
        }
        navigationController?.pushViewController(detail, animated: true)
    }

    private func dismissFlow() {
        guard let navigationController = navigationController,
              let index = navigationController.viewControllers.firstIndex(of: self),
              index > 0 else {
            dismiss(animated: true)
            return
        }
        navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
    }
}
