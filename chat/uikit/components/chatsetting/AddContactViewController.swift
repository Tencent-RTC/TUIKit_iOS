import AtomicXCore
import Combine
import SnapKit
import UIKit

final class AddContactViewController: ChatSettingBaseViewController {
    private enum Step {
        case detail
        case form
    }

    private static let infoCardAvatarSize = ChatAvatarSize.l

    private static let cardHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let toastBottomOffset: CGFloat = 200

    private static let addFriendNeedConfirmCode = 30539

    private static let addFriendInvalidParamsCode = 30001

    private static let addFriendExistFlag = "Err_SNS_FriendAdd_Friend_Exist"

    private static let infoCardVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let infoCardAvatarNameGap: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let infoCardLineGap: CGFloat = 2

    private static let actionCardHeight: CGFloat = 52

    private static let sectionSpacerHeight: CGFloat = 10

    private static let sectionTitleTopPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let sectionTitleBottomPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let inputCardPadding: CGFloat = 14

    private static let inputCardMinHeight: CGFloat = 120

    private static let remarkRowHeight: CGFloat = 52

    private static let remarkLabelValueGap: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let signatureMaxLineCount: Int = 2

    private static let toastDuration: TimeInterval = 2

    private let userID: String

    private let onAddFriendSuccess: (() -> Void)?

    private let contactStore = ContactStore.shared

    private var contactInfo: ContactInfo?

    private var currentStep: Step = .detail

    private var cancellables = Set<AnyCancellable>()

    private let contentContainer = UIView()

    private let avatarView: ChatAvatarView = {
        let size = AddContactViewController.infoCardAvatarSize
        let radius: CGFloat
        switch AppBuilderConfig.shared.avatarShape {
        case .circular:
            radius = size.size / 2
        case .rounded:
            radius = size.roundedRectCornerRadius
        case .square:
            radius = 0
        }
        return ChatAvatarView(cornerRadius: radius, fontSize: size.placeholderFontSize)
    }()

    private let nameLabel = UILabel()

    private let userIDLabel = UILabel()

    private let signatureLabel = UILabel()

    private let formScrollView = UIScrollView()

    private let formStack = UIStackView()

    private let wordingTextView = UITextView()

    private let remarkTextField = UITextField()

    private var displayName: String {
        if let contactInfo = contactInfo {
            return chatSettingContactDisplayName(contactInfo)
        }
        return userID
    }

    // MARK: - Layout Constants（对齐 Android dp 值）

    init(
        userID: String,
        contactInfo: ContactInfo? = nil,
        onAddFriendSuccess: (() -> Void)? = nil
    ) {
        self.userID = userID
        self.contactInfo = contactInfo
        self.onAddFriendSuccess = onAddFriendSuccess
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setNavTitle(LocalizedChatString("ContactListAddContact"))
        view.addSubview(contentContainer)
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(contentTopItem)
            make.leading.trailing.bottom.equalToSuperview()
        }
        view.backgroundColor = TUIChatKitTheme.colors.bgColorDefault
        contentContainer.backgroundColor = TUIChatKitTheme.colors.bgColorDefault
        onBack = { [weak self] in
            self?.handleStepBack()
        }
        showDetailStep()
        if contactInfo == nil {
            fetchUserInfo()
        }
        subscribeKeyboard()
    }

    // MARK: - Keyboard（对齐 Android SOFT_INPUT_ADJUST_RESIZE）

    private func handleStepBack() {
        switch currentStep {
        case .form:
            showDetailStep()
        case .detail:
            if let navigationController = navigationController {
                navigationController.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
        }
    }

    private func showDetailStep() {
        currentStep = .detail
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        view.endEditing(true)

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 0
        contentContainer.addSubview(container)
        container.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        container.addArrangedSubview(makeInfoCard())
        container.addArrangedSubview(makeSectionSpacer())
        container.addArrangedSubview(makeActionCard(
            title: LocalizedChatString("ContactListAddContact"),
            action: #selector(handleAddContactTapped)
        ))
        refreshInfoCard()
    }

    @objc private func handleAddContactTapped() {
        showFormStep()
    }

    private func showFormStep() {
        currentStep = .form
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        formScrollView.keyboardDismissMode = .onDrag
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        backgroundTap.cancelsTouchesInView = false
        formScrollView.addGestureRecognizer(backgroundTap)
        remarkTextField.returnKeyType = .done
        remarkTextField.delegate = self

        formScrollView.addSubview(formStack)
        formStack.axis = .vertical
        formStack.spacing = 0
        contentContainer.addSubview(formScrollView)
        formScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        formStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        formStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        formStack.addArrangedSubview(makeInfoCard())
        formStack.addArrangedSubview(makeSectionTitle(LocalizedChatString("ContactListFillValidationMessage")))
        formStack.addArrangedSubview(makeWordingInputCard())
        formStack.addArrangedSubview(makeSectionSpacer())
        formStack.addArrangedSubview(makeRemarkRow())
        formStack.addArrangedSubview(makeSectionSpacer())
        formStack.addArrangedSubview(makeActionCard(
            title: LocalizedChatString("Send"),
            action: #selector(handleSendTapped)
        ))
        refreshInfoCard()
        applyFormDefaults()
    }

    private func applyFormDefaults() {
        let selfInfo = LoginStore.shared.state.value.loginUserInfo
        let selfDisplayName = (selfInfo?.nickname?.isEmpty == false ? selfInfo?.nickname : selfInfo?.userID) ?? ""
        wordingTextView.text = String(format: LocalizedChatString("ContactListAddWordingIAm"), selfDisplayName)
        remarkTextField.text = displayName
    }

    @objc private func handleBackgroundTapped() {
        view.endEditing(true)
    }

    @objc private func handleSendTapped() {
        let wording = wordingTextView.text ?? ""
        var remark = (remarkTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if remark.isEmpty {
            remark = contactInfo?.nickname ?? userID
        }
        contactStore.addFriend(
            userID: userID,
            remark: remark,
            addWording: wording.isEmpty ? nil : wording
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    WindowToastManager.shared.show(
                        LocalizedChatString("ContactListAddFriendSuccess"),
                        type: .success,
                        duration: Self.toastDuration,
                        position: .bottom(Self.toastBottomOffset),
                        trailingIcon: UIImage(named: "AppIcon")
                    )
                    self.onAddFriendSuccess?()
                    if let navigationController = self.navigationController {
                        navigationController.popViewController(animated: true)
                    } else {
                        self.dismiss(animated: true)
                    }
                case .failure(let error):
                    if error.code == Self.addFriendNeedConfirmCode {
                        WindowToastManager.shared.show(
                            LocalizedChatString("FriendRequestSent"),
                            type: .success,
                            duration: Self.toastDuration,
                            position: .bottom(Self.toastBottomOffset),
                            trailingIcon: UIImage(named: "AppIcon")
                        )
                        self.onAddFriendSuccess?()
                        if let navigationController = self.navigationController {
                            navigationController.popViewController(animated: true)
                        } else {
                            self.dismiss(animated: true)
                        }
                    } else if error.code == Self.addFriendInvalidParamsCode && error.message == Self.addFriendExistFlag {
                        WindowToastManager.shared.show(
                            LocalizedChatString("AlreadyFriendTip"),
                            type: .info,
                            duration: Self.toastDuration,
                            position: .bottom(Self.toastBottomOffset),
                            trailingIcon: UIImage(named: "AppIcon")
                        )
                    } else {
                        WindowToastManager.shared.show(
                            LocalizedChatString("ContactListAddFriendFailed"),
                            type: .error,
                            duration: Self.toastDuration,
                            position: .bottom(Self.toastBottomOffset)
                        )
                    }
                }
            }
        }
    }

    private func makeInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        card.addSubview(avatarView)
        let textStack = UIStackView(arrangedSubviews: [nameLabel, userIDLabel, signatureLabel])
        textStack.axis = .vertical
        textStack.spacing = 0
        textStack.setCustomSpacing(Self.infoCardLineGap, after: nameLabel)
        textStack.setCustomSpacing(Self.infoCardLineGap, after: userIDLabel)
        card.addSubview(textStack)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.cardHorizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.infoCardAvatarSize.size)
            make.top.greaterThanOrEqualToSuperview().offset(Self.infoCardVerticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.infoCardVerticalPadding)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.infoCardAvatarNameGap)
            make.trailing.equalToSuperview().offset(-Self.cardHorizontalPadding)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Self.infoCardVerticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.infoCardVerticalPadding)
        }
        let colors = TUIChatKitTheme.colors
        nameLabel.font = FontScheme.caption1Bold
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        userIDLabel.font = FontScheme.caption3Regular
        userIDLabel.textColor = colors.textColorSecondary
        userIDLabel.lineBreakMode = .byTruncatingTail
        signatureLabel.font = FontScheme.caption3Regular
        signatureLabel.textColor = colors.textColorSecondary
        signatureLabel.numberOfLines = Self.signatureMaxLineCount
        signatureLabel.lineBreakMode = .byTruncatingTail
        return card
    }

    private func refreshInfoCard() {
        avatarView.configure(avatarURL: contactInfo?.avatarURL, fallbackName: displayName)
        nameLabel.text = displayName
        userIDLabel.text = labelValueText(LocalizedChatString("ProfileUserID"), userID)
        let aboutMe = contactInfo?.aboutMe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let signatureText = aboutMe.isEmpty ? LocalizedChatString("ContactListNoContent") : aboutMe
        signatureLabel.text = labelValueText(LocalizedChatString("ProfileSignature"), signatureText)
    }

    private func labelValueText(_ label: String, _ value: String) -> String {
        let isChinese = LanguageHelper.getCurrentLanguage().hasPrefix("zh")
        return isChinese ? "\(label)：\(value)" : "\(label): \(value)"
    }

    private func makeSectionSpacer() -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = TUIChatKitTheme.colors.bgColorDefault
        spacer.snp.makeConstraints { make in
            make.height.equalTo(Self.sectionSpacerHeight)
        }
        return spacer
    }

    private func makeSectionTitle(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = TUIChatKitTheme.colors.bgColorDefault
        let label = UILabel()
        label.text = text
        label.font = FontScheme.caption2Regular
        label.textColor = TUIChatKitTheme.colors.textColorSecondary
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: Self.sectionTitleTopPadding,
                left: Self.cardHorizontalPadding,
                bottom: Self.sectionTitleBottomPadding,
                right: Self.cardHorizontalPadding
            ))
        }
        return container
    }

    private func makeActionCard(title: String, action: Selector) -> UIView {
        let row = UIControl()
        row.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        let label = UILabel()
        label.text = title
        label.font = FontScheme.caption1Regular
        label.textColor = TUIChatKitTheme.colors.textColorLink
        label.textAlignment = .center
        row.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(Self.actionCardHeight)
        }
        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    private func makeWordingInputCard() -> UIView {
        let card = UIView()
        card.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        card.addSubview(wordingTextView)
        wordingTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.inputCardPadding)
            make.height.greaterThanOrEqualTo(Self.inputCardMinHeight - Self.inputCardPadding * 2)
        }
        wordingTextView.font = FontScheme.caption1Regular
        wordingTextView.textColor = TUIChatKitTheme.colors.textColorPrimary
        wordingTextView.backgroundColor = .clear
        wordingTextView.textContainer.lineFragmentPadding = 0
        wordingTextView.textContainerInset = .zero
        return card
    }

    private func makeRemarkRow() -> UIView {
        let row = UIView()
        row.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        let label = UILabel()
        label.text = LocalizedChatString("ContactListRemark")
        label.font = FontScheme.caption1Regular
        label.textColor = TUIChatKitTheme.colors.textColorPrimary
        row.addSubview(label)
        row.addSubview(remarkTextField)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.cardHorizontalPadding)
            make.centerY.equalToSuperview()
        }
        remarkTextField.snp.makeConstraints { make in
            make.leading.equalTo(label.snp.trailing).offset(Self.remarkLabelValueGap)
            make.trailing.equalToSuperview().offset(-Self.cardHorizontalPadding)
            make.centerY.equalToSuperview()
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(Self.remarkRowHeight)
        }
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        remarkTextField.font = FontScheme.caption1Regular
        remarkTextField.textColor = TUIChatKitTheme.colors.textColorPrimary
        remarkTextField.textAlignment = LanguageHelper.isRTL ? .left : .right
        return row
    }

    private func fetchUserInfo() {
        contactStore.getContactInfo(
            userIDList: [userID],
            completion: AddContactInfoHandler(
                onSuccess: { [weak self] contactInfoList in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.contactInfo = contactInfoList.first
                        self.refreshInfoCard()
                        if self.currentStep == .form {
                            self.applyFormDefaults()
                        }
                    }
                },
                onFailure: { _, _ in }
            )
        )
    }

    private func subscribeKeyboard() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.adjustScrollInsetForKeyboard(notification)
            }
            .store(in: &cancellables)
    }

    private func adjustScrollInsetForKeyboard(_ notification: Notification) {
        guard currentStep == .form,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardTop = view.convert(frame, from: nil).origin.y
        let bottomOverlap = max(0, view.bounds.height - keyboardTop)
        formScrollView.contentInset.bottom = bottomOverlap
        formScrollView.verticalScrollIndicatorInsets.bottom = bottomOverlap
    }
}

extension AddContactViewController: UITextFieldDelegate {

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class AddContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
