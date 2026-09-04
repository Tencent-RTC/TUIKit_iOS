import UIKit
import SnapKit
import AtomicXCore

final class ForwardContactPickerViewController: UIViewController {
    private static let topBarHeight: CGFloat = 56

    private static let actionButtonFontSize: CGFloat = 16

    private static let topBarHorizontalInset = CGFloat(SpacingScheme.bubbleSpacing)

    private let contacts: [ContactInfo]

    private let initialSelectedUserIDs: Set<String>

    private let onConfirm: ([ContactInfo]) -> Void

    private let pickerView = UserPickerView()

    init(contacts: [ContactInfo],
         preSelectedUserIDs: Set<String>,
         onConfirm: @escaping ([ContactInfo]) -> Void) {
        self.contacts = contacts
        self.initialSelectedUserIDs = preSelectedUserIDs
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        pickerView.configure(userList: Self.userPickerItems(from: contacts), maxCount: 0)
        pickerView.setInitialSelectedIDs(initialSelectedUserIDs)
    }

    private static func userPickerItems(from contacts: [ContactInfo]) -> [UserPickerItem] {
        return contacts.map { contact in
            UserPickerItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: displayName(for: contact)
            )
        }
    }

    private static func displayName(for contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return contact.userID
    }

    private func setupUI() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorOperate

        let topBar = UIView()
        topBar.backgroundColor = colors.bgColorOperate
        view.addSubview(topBar)
        topBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.topBarHeight)
        }

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.titleLabel?.font = FontScheme.caption1Regular
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        topBar.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.topBarHorizontalInset)
            make.centerY.equalToSuperview()
        }

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("RelayTargetSelectFromContacts")
        titleLabel.font = FontScheme.caption1Bold
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(LocalizedChatString("Confirm"), for: .normal)
        confirmButton.setTitleColor(colors.textColorLink, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: Self.actionButtonFontSize, weight: .semibold)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        topBar.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.topBarHorizontalInset)
            make.centerY.equalToSuperview()
        }

        view.addSubview(pickerView)
        pickerView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @objc private func handleCancel() {
        closePage()
    }

    @objc private func handleConfirm() {
        let selectedIDs = Set(pickerView.selectedItems.map(\.userID))
        let result = contacts.filter { selectedIDs.contains($0.userID) }
        closePage { [weak self] in
            self?.onConfirm(result)
        }
    }
}
