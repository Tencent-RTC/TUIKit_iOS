import AtomicXCore
import SnapKit
import UIKit

final class AddFriendViewController: ChatSettingBaseViewController {
    private let impl = AddFriendViewControllerImpl()

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("ContactListAddContact"))
        view.addSubview(impl)
        impl.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        impl.onAddContact = { [weak self] contact in
            self?.pushAddContact(contact)
        }
    }

    private func pushAddContact(_ contact: ContactInfo) {
        let detail = AddContactViewController(
            userID: contact.userID,
            contactInfo: contact,
            onAddFriendSuccess: { [weak self] in
                guard let self = self, let navigationController = self.navigationController else { return }
                navigationController.viewControllers.removeAll { $0 === self }
            }
        )
        navigationController?.pushViewController(detail, animated: true)
    }
}
