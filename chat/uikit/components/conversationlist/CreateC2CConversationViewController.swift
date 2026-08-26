import SnapKit
import UIKit

final class CreateC2CConversationViewController: UIViewController, SystemNavigationBarPage {
    private let onUserSelected: (AZOrderedListItem) -> Void

    private let impl = CreateC2CConversationViewControllerImpl()

    init(onUserSelected: @escaping (AZOrderedListItem) -> Void) {
        self.onUserSelected = onUserSelected
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
        impl.onUserSelected = { [weak self] item in
            self?.onUserSelected(item)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = colors.bgColorOperate
        title = LocalizedChatString("ChatsNewChatText")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: AtomicXChatResources.image(named: "contact_info_back")?
                .withRenderingMode(.alwaysTemplate)
                ?? UIImage(systemName: "chevron.left")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)),
            style: .plain,
            target: self,
            action: #selector(handleCancel)
        )
        navigationItem.leftBarButtonItem?.tintColor = colors.textColorPrimary
    }

    @objc private func handleCancel() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
