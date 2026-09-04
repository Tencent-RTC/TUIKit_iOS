import AtomicXCore
import TUIChatKit
import Combine
import ImSDK_Plus
import SnapKit
import UIKit

final class SettingsViewController: UIViewController {
    private static let horizontalPadding: CGFloat = 16

    private static let headerHeight: CGFloat = 44

    private static let groupSpacerHeight: CGFloat = 10

    private static let dividerHeight: CGFloat = 0.5

    private static let rowVerticalPadding: CGFloat = 12

    private static let arrowSpacing: CGFloat = 8

    private static let logoutCornerRadius: CGFloat = 8

    private static let entryRowMinHeight: CGFloat = 48

    private static let primaryColorPreviewSize: CGFloat = 24

    private let scrollView = UIScrollView()

    private let contentStack = UIStackView()

    private let headerLabel = UILabel()

    private let headerBackgroundView = UIView()

    private let profileRow = UIControl()

    private let avatarView = ChatAvatarView(size: .l, isRound: true)

    private let nicknameLabel = UILabel()

    private let userIDLabel = UILabel()

    private let signatureLabel = UILabel()

    private let themeValueLabel = UILabel()

    private let primaryColorPreview = UIView()

    private let languageValueLabel = UILabel()

    private let approveValueLabel = UILabel()

    private let translateValueLabel = UILabel()

    private let readReceiptSwitch = UISwitch()

    private let readReceiptDescLabel = UILabel()

    private let callsTabSwitch = UISwitch()

    private let logoutButton = UIButton(type: .custom)

    private var cancellables = Set<AnyCancellable>()

    private var allowType: AllowType?

    private static let translateLanguageOptions: [(code: String, name: String)] = [
        ("zh", "简体中文"), ("zh-TW", "繁體中文"), ("en", "English"), ("ja", "日本語"),
        ("ko", "한국어"), ("fr", "Français"), ("es", "Español"), ("it", "Italiano"),
        ("de", "Deutsch"), ("tr", "Türkçe"), ("ru", "Русский"), ("pt", "Português"),
        ("vi", "Tiếng Việt"), ("id", "Bahasa Indonesia"), ("th", "ภาษาไทย"),
        ("ms", "Bahasa Melayu"), ("hi", "हिन्दी")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        bindLoginState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStaticValues()
    }

    // MARK: - Actions

    private func constructViewHierarchy() {
        view.addSubview(headerBackgroundView)
        view.addSubview(headerLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        contentStack.axis = .vertical
        contentStack.spacing = 0

        contentStack.addArrangedSubview(makeProfileSection())
        contentStack.addArrangedSubview(makeGroupSpacer())
        let groupOne = UIStackView()
        groupOne.axis = .vertical
        groupOne.spacing = 0
        groupOne.addArrangedSubview(makeEntryRow(title: LocalizedChatString("SelectThemeMode"), valueLabel: themeValueLabel, action: #selector(handleThemeTapped)))
        groupOne.addArrangedSubview(makeRowDivider())
        groupOne.addArrangedSubview(makePrimaryColorRow())
        groupOne.addArrangedSubview(makeRowDivider())
        groupOne.addArrangedSubview(makeEntryRow(title: LocalizedChatString("SelectLanguage"), valueLabel: languageValueLabel, action: #selector(handleLanguageTapped)))
        contentStack.addArrangedSubview(groupOne)
        contentStack.addArrangedSubview(makeGroupSpacer())
        let groupTwo = UIStackView()
        groupTwo.axis = .vertical
        groupTwo.spacing = 0
        groupTwo.addArrangedSubview(makeEntryRow(title: LocalizedChatString("MeFriendRequest"), valueLabel: approveValueLabel, action: #selector(handleApproveTapped)))
        groupTwo.addArrangedSubview(makeRowDivider())
        groupTwo.addArrangedSubview(makeReadReceiptRow())
        groupTwo.addArrangedSubview(makeRowDivider())
        groupTwo.addArrangedSubview(makeCallsTabRow())
        groupTwo.addArrangedSubview(makeRowDivider())
        groupTwo.addArrangedSubview(makeEntryRow(title: LocalizedChatString("TranslateMessage"), valueLabel: translateValueLabel, action: #selector(handleTranslateTapped)))
        groupTwo.addArrangedSubview(makeRowDivider())
        groupTwo.addArrangedSubview(makeEntryRow(title: LocalizedChatString("VoiceMessageSettings"), valueLabel: nil, action: #selector(handleVoiceTapped)))
        contentStack.addArrangedSubview(groupTwo)
        contentStack.addArrangedSubview(makeGroupSpacer())
        let groupThree = UIStackView()
        groupThree.axis = .vertical
        groupThree.spacing = 0
        groupThree.addArrangedSubview(makeEntryRow(title: LocalizedChatString("AboutTencentIM"), valueLabel: nil, action: #selector(handleAboutTapped)))
        contentStack.addArrangedSubview(groupThree)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        contentStack.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(makeLogoutSection())
    }

    private func activateConstraints() {
        headerLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.headerHeight)
        }
        headerBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(headerLabel.snp.bottom)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(headerLabel.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorTopBar
        headerBackgroundView.backgroundColor = colors.bgColorOperate
        headerLabel.backgroundColor = colors.bgColorOperate
        headerLabel.text = LocalizedChatString("TabSettings")
        headerLabel.font = .systemFont(ofSize: 17, weight: .bold)
        headerLabel.textColor = colors.textColorPrimary
        headerLabel.textAlignment = .center
        scrollView.backgroundColor = .clear
        navigationItem.backButtonDisplayMode = .minimal
    }

    private func bindInteraction() {
        profileRow.addTarget(self, action: #selector(handleProfileTapped), for: .touchUpInside)
        readReceiptSwitch.addTarget(self, action: #selector(handleReadReceiptChanged), for: .valueChanged)
        callsTabSwitch.addTarget(self, action: #selector(handleCallsTabChanged), for: .valueChanged)
        logoutButton.addTarget(self, action: #selector(handleLogoutTapped), for: .touchUpInside)
    }

    private func bindLoginState() {
        let state = LoginStore.shared.state
        state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.nickname))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshProfile() }
            .store(in: &cancellables)
        state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.avatarURL))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshProfile() }
            .store(in: &cancellables)
        state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.selfSignature))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshProfile() }
            .store(in: &cancellables)
        state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.allowType))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allowType in
                self?.allowType = allowType
                self?.refreshApproveValue()
            }
            .store(in: &cancellables)
        refreshProfile()
        allowType = LoginStore.shared.state.value.loginUserInfo?.allowType
        refreshApproveValue()
    }

    private func makeProfileSection() -> UIView {
        profileRow.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        let textColumn = UIStackView()
        textColumn.axis = .vertical
        textColumn.spacing = 2
        nicknameLabel.font = .systemFont(ofSize: 18)
        nicknameLabel.textColor = TUIChatKitTheme.colors.textColorPrimary
        nicknameLabel.lineBreakMode = .byTruncatingTail
        userIDLabel.font = .systemFont(ofSize: 13)
        userIDLabel.textColor = TUIChatKitTheme.colors.textColorTertiary
        signatureLabel.font = .systemFont(ofSize: 13)
        signatureLabel.textColor = TUIChatKitTheme.colors.textColorTertiary
        signatureLabel.lineBreakMode = .byTruncatingTail
        textColumn.addArrangedSubview(nicknameLabel)
        textColumn.addArrangedSubview(userIDLabel)
        textColumn.addArrangedSubview(signatureLabel)
        avatarView.isUserInteractionEnabled = false
        textColumn.isUserInteractionEnabled = false
        profileRow.addSubview(avatarView)
        profileRow.addSubview(textColumn)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ChatAvatarSize.l.size)
        }
        textColumn.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        return profileRow
    }

    private func makeEntryRow(title: String, valueLabel: UILabel?, action: Selector) -> UIView {
        let colors = TUIChatKitTheme.colors
        let row = UIControl()
        row.backgroundColor = colors.bgColorOperate
        row.addTarget(self, action: action, for: .touchUpInside)
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.entryRowMinHeight)
        }
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let arrowImageView = UIImageView(image: AtomicXChatResources.image(named: "contact_info_arrow_right")?.withRenderingMode(.alwaysTemplate))
        arrowImageView.tintColor = colors.textColorTertiary
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.setContentHuggingPriority(.required, for: .horizontal)
        row.addSubview(titleLabel)
        row.addSubview(arrowImageView)
        if let valueLabel = valueLabel {
            valueLabel.font = .systemFont(ofSize: 16)
            valueLabel.textColor = colors.textColorPrimary
            valueLabel.lineBreakMode = .byTruncatingTail
            valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addSubview(valueLabel)
            valueLabel.snp.makeConstraints { make in
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-Self.arrowSpacing)
                make.centerY.equalToSuperview()
            }
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        return row
    }

    private func makePrimaryColorRow() -> UIView {
        let colors = TUIChatKitTheme.colors
        let row = UIControl()
        row.backgroundColor = colors.bgColorOperate
        row.addTarget(self, action: #selector(handlePrimaryColorTapped), for: .touchUpInside)
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.entryRowMinHeight)
        }
        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("SelectThemeColor")
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let arrowImageView = UIImageView(image: AtomicXChatResources.image(named: "contact_info_arrow_right")?.withRenderingMode(.alwaysTemplate))
        arrowImageView.tintColor = colors.textColorTertiary
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.setContentHuggingPriority(.required, for: .horizontal)
        refreshPrimaryColorPreview()
        row.addSubview(titleLabel)
        row.addSubview(arrowImageView)
        row.addSubview(primaryColorPreview)
        primaryColorPreview.snp.makeConstraints { make in
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-Self.arrowSpacing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.primaryColorPreviewSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        return row
    }

    private func makeReadReceiptRow() -> UIView {
        let colors = TUIChatKitTheme.colors
        let container = UIView()
        container.backgroundColor = colors.bgColorOperate
        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("MessageReadReceipt")
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        readReceiptSwitch.onTintColor = colors.switchColorOn
        readReceiptSwitch.isOn = UserDefaults.standard.bool(forKey: "com.atomicx.enableReadReceipt")
        readReceiptDescLabel.font = .systemFont(ofSize: 12)
        readReceiptDescLabel.textColor = colors.textColorTertiary
        readReceiptDescLabel.numberOfLines = 0
        refreshReadReceiptDesc()
        container.addSubview(titleLabel)
        container.addSubview(readReceiptSwitch)
        container.addSubview(readReceiptDescLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
        }
        readReceiptSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
        }
        readReceiptDescLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        return container
    }

    private func makeCallsTabRow() -> UIView {
        let colors = TUIChatKitTheme.colors
        let container = UIView()
        container.backgroundColor = colors.bgColorOperate
        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("SettingsShowCalls")
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        callsTabSwitch.onTintColor = colors.switchColorOn
        callsTabSwitch.isOn = HomeTabBarController.isCallsTabVisible
        container.addSubview(titleLabel)
        container.addSubview(callsTabSwitch)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        callsTabSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
        }
        return container
    }

    private func makeGroupSpacer() -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        spacer.snp.makeConstraints { make in
            make.height.equalTo(Self.groupSpacerHeight)
        }
        return spacer
    }

    private func makeRowDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = TUIChatKitTheme.colors.strokeColorPrimary
        divider.snp.makeConstraints { make in
            make.height.equalTo(Self.dividerHeight)
        }
        return divider
    }

    private func makeLogoutSection() -> UIView {
        let container = UIView()
        container.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        logoutButton.setTitle(LocalizedChatString("logout"), for: .normal)
        logoutButton.setTitleColor(TUIChatKitTheme.colors.textColorError, for: .normal)
        logoutButton.titleLabel?.font = .systemFont(ofSize: 16)
        logoutButton.backgroundColor = TUIChatKitTheme.colors.bgColorInput
        logoutButton.layer.cornerRadius = Self.logoutCornerRadius
        container.addSubview(logoutButton)
        logoutButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.greaterThanOrEqualTo(44)
        }
        return container
    }

    private func refreshProfile() {
        let userInfo = LoginStore.shared.state.value.loginUserInfo
        let nickname = userInfo?.nickname ?? ""
        let displayName = nickname.isEmpty ? DemoLoginManager.shared.currentUserID : nickname
        nicknameLabel.text = displayName
        let userID = userInfo?.userID ?? DemoLoginManager.shared.currentUserID
        userIDLabel.text = "ID：\(userID)"
        let signature = userInfo?.selfSignature ?? ""
        signatureLabel.text = "\(LocalizedChatString("MeSignaturePrefix"))：\(signature.isEmpty ? LocalizedChatString("NoSelfSignature") : signature)"
        avatarView.configure(avatarURL: userInfo?.avatarURL, fallbackName: displayName)
    }

    private func refreshStaticValues() {
        switch ThemeState.shared.currentMode {
        case .system:
            themeValueLabel.text = LocalizedChatString("ThemeNameSystem")
        case .light:
            themeValueLabel.text = LocalizedChatString("ThemeNameLight")
        case .dark:
            themeValueLabel.text = LocalizedChatString("ThemeNameDark")
        }
        languageValueLabel.text = DemoLanguageManager.shared.currentLanguageName()
        refreshPrimaryColorPreview()
        refreshApproveValue()
        refreshTranslateValue()
    }

    private func currentPrimaryColorHex() -> String {
        return ThemeState.shared.currentPrimaryColor ?? PrimaryColorPickerViewController.defaultPrimaryHex
    }

    private func refreshPrimaryColorPreview() {
        primaryColorPreview.backgroundColor = UIColor(demoHex: currentPrimaryColorHex())
        primaryColorPreview.layer.cornerRadius = Self.primaryColorPreviewSize / 2
        primaryColorPreview.layer.borderWidth = 1.5
        primaryColorPreview.layer.borderColor = TUIChatKitTheme.colors.strokeColorPrimary.cgColor
    }

    @objc private func handlePrimaryColorTapped() {
        let picker = PrimaryColorPickerViewController(selectedHex: currentPrimaryColorHex()) { [weak self] hex in
            ThemeState.shared.setPrimaryColor(hex)
            self?.refreshPrimaryColorPreview()
        }
        present(picker, animated: true)
    }

    private func refreshApproveValue() {
        guard let allowType = allowType else {
            approveValueLabel.text = ""
            return
        }
        switch allowType {
        case .allowAny:
            approveValueLabel.text = LocalizedChatString("AllowTypeAcceptOne")
        case .needConfirm:
            approveValueLabel.text = LocalizedChatString("AllowTypeNeedConfirm")
        case .denyAny:
            approveValueLabel.text = LocalizedChatString("AllowTypeDeclineAll")
        }
    }

    private func refreshTranslateValue() {
        var currentCode = AppBuilderConfig.shared.translateTargetLanguage
        if currentCode == "zh-Hans" {
            currentCode = "zh"
        } else if currentCode == "zh-Hant" {
            currentCode = "zh-TW"
        }
        translateValueLabel.text = Self.translateLanguageOptions.first { $0.code == currentCode }?.name ?? currentCode
    }

    private func refreshReadReceiptDesc() {
        readReceiptDescLabel.text = readReceiptSwitch.isOn
            ? LocalizedChatString("MessageReadReceiptEnabledDesc")
            : LocalizedChatString("MessageReadReceiptDisabledDesc")
    }

    @objc private func handleProfileTapped() {
        let controller = ProfileDetailViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func handleThemeTapped() {
        presentActionSheet(options: [
            (LocalizedChatString("ThemeNameSystem"), { ThemeState.shared.setThemeMode(.system) }),
            (LocalizedChatString("ThemeNameLight"), { ThemeState.shared.setThemeMode(.light) }),
            (LocalizedChatString("ThemeNameDark"), { ThemeState.shared.setThemeMode(.dark) })
        ]) { [weak self] in
            self?.refreshStaticValues()
        }
    }

    @objc private func handleLanguageTapped() {
        presentActionSheet(options: DemoLanguageManager.shared.supportedLanguages.map { language in
            (language.nativeName, { DemoLanguageManager.shared.setLanguage(language.code) })
        }) { [weak self] in
            self?.refreshStaticValues()
        }
    }

    @objc private func handleApproveTapped() {
        presentActionSheet(options: [
            (LocalizedChatString("AllowTypeAcceptOne"), { self.setAllowType(.allowAny) }),
            (LocalizedChatString("AllowTypeDeclineAll"), { self.setAllowType(.denyAny) }),
            (LocalizedChatString("AllowTypeNeedConfirm"), { self.setAllowType(.needConfirm) })
        ])
    }

    @objc private func handleTranslateTapped() {
        presentActionSheet(options: Self.translateLanguageOptions.map { option in
            (option.name, {
                AppBuilderConfig.shared.translateTargetLanguage = option.code
                UserDefaults.standard.set(option.code, forKey: "com.atomicx.translateTargetLanguage")
            })
        }) { [weak self] in
            self?.refreshTranslateValue()
        }
    }

    @objc private func handleVoiceTapped() {
        let controller = VoiceMessageSettingViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func handleAboutTapped() {
        let controller = AboutViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func handleReadReceiptChanged() {
        UserDefaults.standard.set(readReceiptSwitch.isOn, forKey: "com.atomicx.enableReadReceipt")
        AppBuilderConfig.shared.enableReadReceipt = readReceiptSwitch.isOn
        refreshReadReceiptDesc()
    }

    @objc private func handleCallsTabChanged() {
        (tabBarController as? HomeTabBarController)?.setCallsTabVisible(callsTabSwitch.isOn)
    }

    @objc private func handleLogoutTapped() {
        DemoLoginManager.shared.logout { _ in }
    }

    private func setAllowType(_ allowType: AllowType) {
        if var info = LoginStore.shared.state.value.loginUserInfo {
            info.allowType = allowType
            LoginStore.shared.setSelfInfo(userProfile: info, completion: nil)
        }
    }

    private func presentActionSheet(options: [(String, () -> Void)], completion: (() -> Void)? = nil) {
        let panel = BottomOptionSheetPanel(optionTitles: options.map { $0.0 }) { selectedIndex in
            options[selectedIndex].1()
            completion?()
        }
        panel.modalPresentationStyle = .overFullScreen
        present(panel, animated: false)
    }
}

// MARK: - Profile Detail

final class ProfileDetailViewController: UIViewController, SystemNavigationBarPage {
    private static let horizontalPadding: CGFloat = 16

    private static let rowVerticalPadding: CGFloat = 12

    private static let dividerHeight: CGFloat = 0.5

    private static let headerTopMargin: CGFloat = 16

    private static let entryTopMargin: CGFloat = 36

    private static let entryRowMinHeight: CGFloat = 48

    private static let defaultBirthdayText = "1970-01-01"

    private let scrollView = UIScrollView()

    private let contentStack = UIStackView()

    private let avatarButton = UIControl()

    private let avatarView = ChatAvatarView(size: .xxl, isRound: true)

    private let displayNameLabel = UILabel()

    private let accountValueLabel = UILabel()

    private let nicknameValueLabel = UILabel()

    private let signatureValueLabel = UILabel()

    private let genderValueLabel = UILabel()

    private let birthdayValueLabel = UILabel()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        bindLoginState()
    }

    private func constructViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.addArrangedSubview(makeHeaderSection())
        let entryContainer = UIStackView()
        entryContainer.axis = .vertical
        entryContainer.spacing = 0
        entryContainer.addArrangedSubview(makeInfoRow(title: LocalizedChatString("ProfileAccount"), valueLabel: accountValueLabel, showArrow: false, action: nil))
        entryContainer.addArrangedSubview(makeInfoRow(title: LocalizedChatString("ProfileNickname"), valueLabel: nicknameValueLabel, showArrow: true, action: #selector(handleNicknameTapped)))
        entryContainer.addArrangedSubview(makeInfoRow(title: LocalizedChatString("ProfileStatus"), valueLabel: signatureValueLabel, showArrow: true, action: #selector(handleSignatureTapped)))
        entryContainer.addArrangedSubview(makeInfoRow(title: LocalizedChatString("ProfileGender"), valueLabel: genderValueLabel, showArrow: true, action: #selector(handleGenderTapped)))
        entryContainer.addArrangedSubview(makeInfoRow(title: LocalizedChatString("ProfileBirthday"), valueLabel: birthdayValueLabel, showArrow: true, action: #selector(handleBirthdayTapped), showDivider: false))
        let entryWrapper = UIView()
        entryWrapper.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        entryWrapper.addSubview(entryContainer)
        entryContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(Self.entryTopMargin)
            make.bottom.equalToSuperview()
        }
        contentStack.addArrangedSubview(entryWrapper)
    }

    private func activateConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func setupViewStyle() {
        view.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        title = LocalizedChatString("ProfileDetails")
    }

    private func bindInteraction() {
        avatarButton.addTarget(self, action: #selector(handleAvatarTapped), for: .touchUpInside)
    }

    private func bindLoginState() {
        let state = LoginStore.shared.state
        state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshValues() }
            .store(in: &cancellables)
        refreshValues()
    }

    private func makeHeaderSection() -> UIView {
        let container = UIView()
        avatarButton.addSubview(avatarView)
        avatarView.isUserInteractionEnabled = false
        avatarView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        displayNameLabel.font = .systemFont(ofSize: 16)
        displayNameLabel.textColor = TUIChatKitTheme.colors.textColorPrimary
        displayNameLabel.textAlignment = .center
        displayNameLabel.numberOfLines = 3
        container.addSubview(avatarButton)
        container.addSubview(displayNameLabel)
        avatarButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.headerTopMargin)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(ChatAvatarSize.xxl.size)
        }
        displayNameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarButton.snp.bottom).offset(Self.horizontalPadding)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.bottom.equalToSuperview()
        }
        return container
    }

    private func makeInfoRow(title: String, valueLabel: UILabel, showArrow: Bool, action: Selector?, showDivider: Bool = true) -> UIView {
        let colors = TUIChatKitTheme.colors
        let row = UIControl()
        row.backgroundColor = .clear
        if let action = action {
            row.addTarget(self, action: action, for: .touchUpInside)
        }
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabel.font = .systemFont(ofSize: 16)
        valueLabel.textColor = colors.textColorPrimary
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.textAlignment = LanguageHelper.isRTL ? .left : .right
        row.addSubview(titleLabel)
        row.addSubview(valueLabel)
        let divider = UIView()
        divider.backgroundColor = colors.strokeColorPrimary
        divider.isHidden = !showDivider
        row.addSubview(divider)
        divider.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.entryRowMinHeight)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        if showArrow {
            let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
            arrowImageView.tintColor = colors.textColorTertiary
            arrowImageView.contentMode = .scaleAspectFit
            arrowImageView.setContentHuggingPriority(.required, for: .horizontal)
            row.addSubview(arrowImageView)
            valueLabel.snp.makeConstraints { make in
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
            }
            arrowImageView.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
                make.centerY.equalToSuperview()
            }
        } else {
            valueLabel.snp.makeConstraints { make in
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
                make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
                make.centerY.equalToSuperview()
            }
        }
        return row
    }

    private func refreshValues() {
        let userInfo = LoginStore.shared.state.value.loginUserInfo
        let userID = userInfo?.userID ?? DemoLoginManager.shared.currentUserID
        let nickname = userInfo?.nickname ?? ""
        let displayName = nickname.isEmpty ? userID : nickname
        displayNameLabel.text = displayName
        avatarView.configure(avatarURL: userInfo?.avatarURL, fallbackName: displayName)
        accountValueLabel.text = userID
        nicknameValueLabel.text = nickname
        signatureValueLabel.text = userInfo?.selfSignature ?? ""
        switch userInfo?.gender {
        case .male:
            genderValueLabel.text = LocalizedChatString("Male")
        case .female:
            genderValueLabel.text = LocalizedChatString("Female")
        default:
            genderValueLabel.text = LocalizedChatString("GenderSecret")
        }
        birthdayValueLabel.text = Self.birthdayDisplayText(userInfo?.birthday)
    }

    private static func birthdayDisplayText(_ birthday: UInt32?) -> String {
        guard let birthday = birthday, birthday > 0 else { return defaultBirthdayText }
        let raw = String(birthday)
        guard raw.count == 8 else { return defaultBirthdayText }
        let year = raw.prefix(4)
        let month = raw.dropFirst(4).prefix(2)
        let day = raw.dropFirst(6).prefix(2)
        return "\(year)-\(month)-\(day)"
    }

    private static func birthdayDate(_ birthday: UInt32?) -> Date {
        guard let birthday = birthday, birthday > 0 else { return Date() }
        let raw = String(birthday)
        guard raw.count == 8,
              let year = Int(raw.prefix(4)),
              let month = Int(raw.dropFirst(4).prefix(2)),
              let day = Int(raw.dropFirst(6).prefix(2)) else { return Date() }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    @objc private func handleAvatarTapped() {
        let imageUrlList = (1 ... 26).map { "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\($0).png" }
        let picker = AvatarPickerPanel(imageUrlList: imageUrlList) { selectedImageUrl in
            guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID else { return }
            let user = UserProfile(userID: userID, nickname: nil, avatarURL: selectedImageUrl)
            LoginStore.shared.setSelfInfo(userProfile: user, completion: nil)
        }
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: false)
    }

    @objc private func handleNicknameTapped() {
        presentTextEditDialog(
            title: LocalizedChatString("ProfileEditName"),
            currentText: LoginStore.shared.state.value.loginUserInfo?.nickname ?? ""
        ) { newNickname in
            let trimmed = newNickname.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let userID = LoginStore.shared.state.value.loginUserInfo?.userID else { return }
            let user = UserProfile(userID: userID, nickname: newNickname)
            LoginStore.shared.setSelfInfo(userProfile: user, completion: nil)
        }
    }

    @objc private func handleSignatureTapped() {
        presentTextEditDialog(
            title: LocalizedChatString("ProfileEditSignture"),
            currentText: LoginStore.shared.state.value.loginUserInfo?.selfSignature ?? ""
        ) { newSignature in
            guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID else { return }
            var user = UserProfile(userID: userID)
            user.selfSignature = newSignature
            LoginStore.shared.setSelfInfo(userProfile: user, completion: nil)
        }
    }

    @objc private func handleGenderTapped() {
        let options: [(String, () -> Void)] = [
            (LocalizedChatString("Male"), { self.updateGender(.male) }),
            (LocalizedChatString("Female"), { self.updateGender(.female) }),
            (LocalizedChatString("GenderSecret"), { self.updateGender(.unknown) })
        ]
        let panel = BottomOptionSheetPanel(optionTitles: options.map { $0.0 }) { selectedIndex in
            options[selectedIndex].1()
        }
        panel.modalPresentationStyle = .overFullScreen
        present(panel, animated: false)
    }

    @objc private func handleBirthdayTapped() {
        let initialDate = Self.birthdayDate(LoginStore.shared.state.value.loginUserInfo?.birthday)
        let panel = BirthdayPickerViewController(initialDate: initialDate) { [weak self] newDate in
            self?.updateBirthday(newDate)
        }
        panel.modalPresentationStyle = .overFullScreen
        present(panel, animated: false)
    }

    private func updateGender(_ gender: Gender) {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID else { return }
        var user = UserProfile(userID: userID)
        user.gender = gender
        LoginStore.shared.setSelfInfo(userProfile: user, completion: nil)
    }

    private func updateBirthday(_ date: Date) {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        var user = UserProfile(userID: userID)
        user.birthday = UInt32(formatter.string(from: date))
        LoginStore.shared.setSelfInfo(userProfile: user, completion: nil)
    }

    private func presentTextEditDialog(title: String, currentText: String, onSave: @escaping (String) -> Void) {
        let dialog = TextInputDialogViewController(title: title, initialText: currentText) { text in
            onSave(text)
        }
        present(dialog, animated: true)
    }
}

// MARK: - Birthday Picker Panel

private final class BirthdayPickerViewController: UIViewController {
    private static let panelCornerRadius: CGFloat = 12

    private static let panelHeight: CGFloat = 300

    private let backgroundDimView = UIView()

    private let panelView = UIView()

    private let cancelButton = UIButton(type: .custom)

    private let saveButton = UIButton(type: .custom)

    private let datePicker = UIDatePicker()

    private let onSave: (Date) -> Void

    init(initialDate: Date, onSave: @escaping (Date) -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        datePicker.date = initialDate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let colors = TUIChatKitTheme.colors
        backgroundDimView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        panelView.backgroundColor = colors.bgColorOperate
        panelView.layer.cornerRadius = Self.panelCornerRadius
        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        saveButton.setTitle(LocalizedChatString("Save"), for: .normal)
        saveButton.setTitleColor(colors.textColorLink, for: .normal)
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: DemoLanguageManager.shared.currentLanguage)

        view.addSubview(backgroundDimView)
        view.addSubview(panelView)
        panelView.addSubview(cancelButton)
        panelView.addSubview(saveButton)
        panelView.addSubview(datePicker)
        backgroundDimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        panelView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.panelHeight)
        }
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
        }
        saveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(12)
        }
        datePicker.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(saveButton.snp.bottom).offset(8)
            make.bottom.lessThanOrEqualToSuperview()
        }

        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCancel))
        backgroundDimView.addGestureRecognizer(tap)
    }

    @objc private func handleCancel() {
        dismiss(animated: false)
    }

    @objc private func handleSave() {
        onSave(datePicker.date)
        dismiss(animated: false)
    }
}

private final class AvatarPickerPanel: UIViewController {
    private static let panelCornerRadius: CGFloat = 16

    private static let panelHeightRatio: CGFloat = 0.6

    private static let headerPadding: CGFloat = 16

    private static let headerVerticalPadding: CGFloat = 14

    private static let gridPadding: CGFloat = 12

    private static let cellPadding: CGFloat = 8

    private static let columnCount: CGFloat = 4

    private let imageUrlList: [String]

    private let onSelect: (String) -> Void

    private let panelView = UIView()

    private let titleLabel = UILabel()

    private let closeButton = UIButton(type: .custom)

    private var collectionView: UICollectionView!

    init(imageUrlList: [String], onSelect: @escaping (String) -> Void) {
        self.imageUrlList = imageUrlList
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        panelView.backgroundColor = colors.bgColorOperate
        panelView.layer.cornerRadius = Self.panelCornerRadius
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.clipsToBounds = true
        titleLabel.text = LocalizedChatString("ChooseAvatar")
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18)
        closeButton.setTitleColor(colors.textColorSecondary, for: .normal)

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: Self.gridPadding, left: Self.gridPadding, bottom: Self.gridPadding, right: Self.gridPadding)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(AvatarPickerCell.self, forCellWithReuseIdentifier: AvatarPickerCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(panelView)
        panelView.addSubview(titleLabel)
        panelView.addSubview(closeButton)
        panelView.addSubview(collectionView)
        panelView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(UIScreen.main.bounds.height * Self.panelHeightRatio)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.headerPadding)
            make.top.equalToSuperview().offset(Self.headerVerticalPadding)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.headerPadding)
            make.centerY.equalTo(titleLabel)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.headerVerticalPadding)
            make.leading.trailing.bottom.equalToSuperview()
        }

        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleClose))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleClose() {
        dismiss(animated: false)
    }
}

extension AvatarPickerPanel: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        imageUrlList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AvatarPickerCell.reuseIdentifier, for: indexPath) as? AvatarPickerCell else {
            return UICollectionViewCell()
        }
        cell.configure(imageUrl: imageUrlList[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect(imageUrlList[indexPath.item])
        dismiss(animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSpacing = Self.gridPadding * 2
        let itemWidth = floor((collectionView.bounds.width - totalSpacing) / Self.columnCount)
        return CGSize(width: itemWidth, height: itemWidth)
    }
}

private final class AvatarPickerCell: UICollectionViewCell {
    static let reuseIdentifier = "AvatarPickerCell"

    private let avatarView = ChatAvatarView(size: .xl, isRound: true)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(avatarView)
        let padding: CGFloat = 8
        avatarView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(ChatAvatarSize.xl.size)
            make.leading.greaterThanOrEqualToSuperview().offset(padding)
            make.trailing.lessThanOrEqualToSuperview().offset(-padding)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(imageUrl: String) {
        avatarView.configure(avatarURL: imageUrl, fallbackName: "")
    }
}

// MARK: - About

final class AboutViewController: UIViewController {
    private static let privacyURL = "https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272"

    private static let userAgreementURL = "https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html"

    private static let personalInformationURL = "https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e"

    private static let thirdPartySharingURL = "https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246"

    private static let contactUsURL = "https://cloud.tencent.com/document/product/269/59590"

    private static let icpBeianURL = "https://beian.miit.gov.cn"

    private static let headerHeight: CGFloat = 56

    private static let horizontalPadding: CGFloat = 16

    private static let rowVerticalPadding: CGFloat = 12

    private static let dividerHeight: CGFloat = 0.5

    private static let groupSpacerHeight: CGFloat = 10

    private static let entryRowMinHeight: CGFloat = 48

    private let backButton = UIButton(type: .custom)

    private let titleLabel = UILabel()

    private let contentStack = UIStackView()

    private let footerStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    private func constructViewHierarchy() {
        let header = UIView()
        header.addSubview(backButton)
        header.addSubview(titleLabel)
        view.addSubview(header)
        header.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.headerHeight)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let spacer = UIView()
        spacer.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        spacer.snp.makeConstraints { make in
            make.height.equalTo(Self.groupSpacerHeight)
        }

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("AboutSDKVersion"), value: V2TIMManager.sharedInstance().getVersion(), showArrow: false, url: nil))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("AboutPrivacyRegulations"), value: "", showArrow: true, url: Self.privacyURL))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("AboutUserAgreement"), value: "", showArrow: true, url: Self.userAgreementURL))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("AboutDisclaimer"), value: "", showArrow: true, url: nil, isDisclaimer: true))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("AboutPersonalInformationCollectionList"), value: "", showArrow: true, url: Self.personalInformationURL))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("About3PartySharingList"), value: "", showArrow: true, url: Self.thirdPartySharingURL))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeInfoRow(title: LocalizedChatString("AboutContactUs"), value: "", showArrow: true, url: Self.contactUsURL))

        footerStack.axis = .vertical
        footerStack.spacing = 10
        footerStack.alignment = .center
        let icpButton = UIButton(type: .custom)
        icpButton.setTitle("ICP备案号：粤B2-20090059-2674A >", for: .normal)
        icpButton.setTitleColor(TUIChatKitTheme.colors.textColorTertiary, for: .normal)
        icpButton.titleLabel?.font = .systemFont(ofSize: 12)
        icpButton.addTarget(self, action: #selector(handleICPTapped), for: .touchUpInside)
        let copyrightLineOne = UILabel()
        copyrightLineOne.text = "腾讯公司 版权所有"
        copyrightLineOne.font = .systemFont(ofSize: 12)
        copyrightLineOne.textColor = TUIChatKitTheme.colors.textColorTertiary
        let copyrightLineTwo = UILabel()
        copyrightLineTwo.text = "Copyright © 2020-2024 Tencent. All Rights Reserved."
        copyrightLineTwo.font = .systemFont(ofSize: 12)
        copyrightLineTwo.textColor = TUIChatKitTheme.colors.textColorTertiary
        footerStack.addArrangedSubview(icpButton)
        footerStack.addArrangedSubview(copyrightLineOne)
        footerStack.addArrangedSubview(copyrightLineTwo)

        view.addSubview(spacer)
        view.addSubview(contentStack)
        view.addSubview(footerStack)
        spacer.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(spacer.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        footerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-34)
            make.top.greaterThanOrEqualTo(contentStack.snp.bottom).offset(20)
        }
    }

    private func activateConstraints() {}

    private func setupViewStyle() {
        view.backgroundColor = TUIChatKitTheme.colors.bgColorTopBar
        titleLabel.text = LocalizedChatString("AboutTencentIM")
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = TUIChatKitTheme.colors.textColorPrimary
        let backImage = AtomicXChatResources.image(named: "contact_info_back")?.withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "chevron.left")?.withRenderingMode(.alwaysTemplate)
        backButton.setImage(backImage, for: .normal)
        backButton.tintColor = TUIChatKitTheme.colors.textColorPrimary
        backButton.addTarget(self, action: #selector(handleBackTapped), for: .touchUpInside)
    }

    private func makeInfoRow(title: String, value: String, showArrow: Bool, url: String?, isDisclaimer: Bool = false) -> UIView {
        let colors = TUIChatKitTheme.colors
        let row = UIControl()
        row.backgroundColor = colors.bgColorOperate
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = colors.textColorSecondary
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.entryRowMinHeight)
        }
        row.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
        }
        var trailingAnchorView: UIView = titleLabel
        if showArrow {
            let arrowImageView = UIImageView(image: AtomicXChatResources.image(named: "contact_info_arrow_right")?.withRenderingMode(.alwaysTemplate))
            arrowImageView.tintColor = colors.textColorTertiary
            arrowImageView.contentMode = .scaleAspectFit
            arrowImageView.setContentHuggingPriority(.required, for: .horizontal)
            row.addSubview(arrowImageView)
            arrowImageView.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
                make.centerY.equalToSuperview()
            }
            trailingAnchorView = arrowImageView
        }
        if !value.isEmpty {
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = .systemFont(ofSize: 16)
            valueLabel.textColor = colors.textColorPrimary
            row.addSubview(valueLabel)
            valueLabel.snp.makeConstraints { make in
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Self.horizontalPadding)
                make.centerY.equalToSuperview()
                if showArrow {
                    make.trailing.equalTo(trailingAnchorView.snp.leading).offset(-8)
                } else {
                    make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
                }
            }
        }
        if isDisclaimer {
            row.addTarget(self, action: #selector(handleDisclaimerTapped), for: .touchUpInside)
        } else if let url = url {
            row.addAction(UIAction { _ in
                guard let target = URL(string: url) else { return }
                UIApplication.shared.open(target)
            }, for: .touchUpInside)
        }
        return row
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = TUIChatKitTheme.colors.strokeColorPrimary
        divider.snp.makeConstraints { make in
            make.height.equalTo(Self.dividerHeight)
        }
        return divider
    }

    @objc private func handleBackTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleICPTapped() {
        guard let url = URL(string: Self.icpBeianURL) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func handleDisclaimerTapped() {
        let alert = UIAlertController(
            title: LocalizedChatString("AboutDisclaimer"),
            message: LocalizedChatString("AboutDisclaimerText"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizedChatString("Accept"), style: .destructive))
        present(alert, animated: true)
    }
}

// MARK: - Primary Color Picker

private extension UIColor {
    convenience init(demoHex: String) {
        var hex = demoHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        guard hex.count == 6, Scanner(string: hex).scanHexInt64(&value) else {
            self.init(red: 0x1C / 255.0, green: 0x66 / 255.0, blue: 0xE5 / 255.0, alpha: 1)
            return
        }
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255.0,
                  green: CGFloat((value >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(value & 0xFF) / 255.0,
                  alpha: 1)
    }

    var demoHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }
}

final class GradientSliderBarView: UIView {
    private static let spectrumHeight: CGFloat = 24

    private static let shadowPadding: CGFloat = 4

    private static let thumbBezel: CGFloat = 3

    private static let thumbRingWidth: CGFloat = 1

    var progress: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    var thumbColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    var onProgressChanged: ((CGFloat) -> Void)?

    private let sliderGradientLayer = CAGradientLayer()

    private var gradientColors: [UIColor] = [.black, .white] {
        didSet { applyGradientColors() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        semanticContentAttribute = .forceLeftToRight
        sliderGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        sliderGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(sliderGradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: Self.spectrumHeight + Self.shadowPadding * 2)
    }

    func setGradientColors(_ colors: [UIColor]) {
        guard colors.count >= 2 else { return }
        gradientColors = colors
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let trackRect = trackRectForLayout()
        sliderGradientLayer.frame = trackRect
        sliderGradientLayer.cornerRadius = trackRect.height / 2
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let trackRect = trackRectForLayout()
        let thumbRadius = trackRect.height / 2
        let usableWidth = max(trackRect.width - thumbRadius * 2, 0)
        let thumbX = trackRect.minX + thumbRadius + progress * usableWidth
        let thumbY = trackRect.midY
        let thumbRect = CGRect(x: thumbX - thumbRadius, y: thumbY - thumbRadius, width: thumbRadius * 2, height: thumbRadius * 2)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.16).cgColor)
        UIColor.white.setFill()
        context.fillEllipse(in: thumbRect)
        context.restoreGState()
        thumbColor.setFill()
        context.fillEllipse(in: thumbRect.insetBy(dx: Self.thumbBezel, dy: Self.thumbBezel))
        UIColor.black.withAlphaComponent(0.16).setStroke()
        let ringPath = UIBezierPath(ovalIn: thumbRect.insetBy(dx: Self.thumbRingWidth / 2, dy: Self.thumbRingWidth / 2))
        ringPath.lineWidth = Self.thumbRingWidth
        ringPath.stroke()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches)
    }

    private func handleTouch(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self) else { return }
        let trackRect = trackRectForLayout()
        let thumbRadius = trackRect.height / 2
        let usableWidth = max(trackRect.width - thumbRadius * 2, 1)
        let clampedX = min(max(point.x, trackRect.minX + thumbRadius), trackRect.maxX - thumbRadius)
        progress = (clampedX - trackRect.minX - thumbRadius) / usableWidth
        onProgressChanged?(progress)
    }

    private func trackRectForLayout() -> CGRect {
        return CGRect(x: 0, y: Self.shadowPadding, width: bounds.width, height: bounds.height - Self.shadowPadding * 2)
    }

    private func applyGradientColors() {
        sliderGradientLayer.colors = gradientColors.map { $0.cgColor }
        setNeedsDisplay()
    }
}

final class PrimaryColorPickerViewController: UIViewController {
    static let defaultPrimaryHex = "#1C66E5"

    private static let contentPadding: CGFloat = 16

    private static let cornerRadius: CGFloat = 12

    private static let horizontalMargin: CGFloat = 36

    private static let previewSize: CGFloat = 48

    private static let sliderBottomSpacing: CGFloat = 12

    private static let sliderLastBottomSpacing: CGFloat = 16

    private static let titleBottomSpacing: CGFloat = 12

    private static let previewBottomSpacing: CGFloat = 8

    private static let hexBottomSpacing: CGFloat = 12

    private static let buttonMinWidth: CGFloat = 72

    private static let buttonMinHeight: CGFloat = 44

    private let onColorSelected: (String) -> Void

    private var hue: CGFloat = 0

    private var saturation: CGFloat = 0

    private var brightness: CGFloat = 0

    private let containerView = UIView()

    private let previewView = UIView()

    private let hexLabel = UILabel()

    private let hueBar = GradientSliderBarView()

    private let saturationBar = GradientSliderBarView()

    private let brightnessBar = GradientSliderBarView()

    init(selectedHex: String, onColorSelected: @escaping (String) -> Void) {
        self.onColorSelected = onColorSelected
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        UIColor(demoHex: selectedHex).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        hue *= 360
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        setupViewStyle()
        bindInteraction()
        refreshDependentBars()
        notifyPreviewChanged()
    }

    private func constructViewHierarchy() {
        let dimView = UIControl()
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)
        view.addSubview(dimView)
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Self.horizontalMargin)
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        containerView.backgroundColor = colors.bgColorDialog
        containerView.layer.cornerRadius = Self.cornerRadius
        containerView.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        containerView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.contentPadding)
        }

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("SelectThemeColorTitle")
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(Self.titleBottomSpacing, after: titleLabel)

        previewView.layer.cornerRadius = Self.previewSize / 2
        previewView.layer.borderWidth = 1.5
        previewView.layer.borderColor = colors.strokeColorPrimary.cgColor
        let previewContainer = UIView()
        previewContainer.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.previewSize)
            make.top.bottom.equalToSuperview()
        }
        stack.addArrangedSubview(previewContainer)
        stack.setCustomSpacing(Self.previewBottomSpacing, after: previewContainer)

        hexLabel.font = .systemFont(ofSize: 13)
        hexLabel.textColor = colors.textColorSecondary
        hexLabel.textAlignment = .center
        stack.addArrangedSubview(hexLabel)
        stack.setCustomSpacing(Self.hexBottomSpacing, after: hexLabel)

        addLabeledSlider(stack: stack, title: LocalizedChatString("ThemeColorHue"), bar: hueBar)
        addLabeledSlider(stack: stack, title: LocalizedChatString("ThemeColorSaturation"), bar: saturationBar)
        addLabeledSlider(stack: stack, title: LocalizedChatString("ThemeColorBrightness"), bar: brightnessBar, last: true)

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.alignment = .center
        let resetButton = makeButton(title: LocalizedChatString("ThemeColorReset"), color: colors.textColorSecondary, bold: false, action: #selector(handleResetTapped))
        let cancelButton = makeButton(title: LocalizedChatString("Cancel"), color: colors.textColorSecondary, bold: false, action: #selector(handleCancelTapped))
        let confirmButton = makeButton(title: LocalizedChatString("Confirm"), color: colors.textColorLink, bold: true, action: #selector(handleConfirmTapped))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonRow.addArrangedSubview(resetButton)
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(confirmButton)
        stack.addArrangedSubview(buttonRow)

        hueBar.progress = hue / 360
        saturationBar.progress = saturation
        brightnessBar.progress = brightness
    }

    private func addLabeledSlider(stack: UIStackView, title: String, bar: GradientSliderBarView, last: Bool = false) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 11)
        label.textColor = TUIChatKitTheme.colors.textColorSecondary
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(4, after: label)
        stack.addArrangedSubview(bar)
        stack.setCustomSpacing(last ? Self.sliderLastBottomSpacing : Self.sliderBottomSpacing, after: bar)
    }

    private func makeButton(title: String, color: UIColor, bold: Bool, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: bold ? .bold : .regular)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(Self.buttonMinWidth)
            make.height.greaterThanOrEqualTo(Self.buttonMinHeight)
        }
        return button
    }

    private func bindInteraction() {
        hueBar.setGradientColors(hueGradientColors())
        hueBar.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            self.hue = progress * 360
            self.refreshDependentBars()
            self.notifyPreviewChanged()
        }
        saturationBar.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            self.saturation = progress
            self.brightnessBar.setGradientColors(self.brightnessGradientColors())
            self.notifyPreviewChanged()
        }
        brightnessBar.onProgressChanged = { [weak self] progress in
            guard let self = self else { return }
            self.brightness = progress
            self.saturationBar.setGradientColors(self.saturationGradientColors())
            self.notifyPreviewChanged()
        }
    }

    private func currentColor() -> UIColor {
        return UIColor(hue: hue / 360, saturation: saturation, brightness: brightness, alpha: 1)
    }

    private func hueGradientColors() -> [UIColor] {
        return (0 ... 6).map { UIColor(hue: CGFloat($0) / 6, saturation: 1, brightness: 1, alpha: 1) }
    }

    private func saturationGradientColors() -> [UIColor] {
        return [
            UIColor(hue: hue / 360, saturation: 0, brightness: brightness, alpha: 1),
            UIColor(hue: hue / 360, saturation: 1, brightness: brightness, alpha: 1)
        ]
    }

    private func brightnessGradientColors() -> [UIColor] {
        return [
            .black,
            UIColor(hue: hue / 360, saturation: saturation, brightness: 1, alpha: 1)
        ]
    }

    private func refreshDependentBars() {
        saturationBar.setGradientColors(saturationGradientColors())
        brightnessBar.setGradientColors(brightnessGradientColors())
    }

    private func notifyPreviewChanged() {
        let color = currentColor()
        previewView.backgroundColor = color
        hexLabel.text = color.demoHexString
        hueBar.thumbColor = color
        saturationBar.thumbColor = color
        brightnessBar.thumbColor = color
    }

    @objc private func handleResetTapped() {
        UIColor(demoHex: Self.defaultPrimaryHex).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        hue *= 360
        hueBar.progress = hue / 360
        saturationBar.progress = saturation
        brightnessBar.progress = brightness
        refreshDependentBars()
        notifyPreviewChanged()
    }

    @objc private func handleCancelTapped() {
        dismiss(animated: true)
    }

    @objc private func handleConfirmTapped() {
        onColorSelected(currentColor().demoHexString)
        dismiss(animated: true)
    }
}

// MARK: - Bottom Option Sheet

private final class BottomOptionSheetPanel: UIViewController {
    private static let panelCornerRadius: CGFloat = 16

    private static let rowHeight: CGFloat = 56

    private static let horizontalMargin: CGFloat = 8

    private static let groupSpacing: CGFloat = 8

    private static let bottomMargin: CGFloat = 8

    private static let separatorHeight: CGFloat = 0.5

    private static let titleFontSize: CGFloat = 16

    private static let dimAlpha: CGFloat = 0.4

    private static let animationDuration: TimeInterval = 0.25

    private static let maxPanelRatio: CGFloat = 0.75

    private let optionTitles: [String]

    private let onSelect: (Int) -> Void

    private let dimView = UIControl()

    private let contentView = UIView()

    private let optionsGroupView = UIView()

    private let optionsScrollView = UIScrollView()

    private let optionsContentView = UIView()

    private let cancelButton = UIButton(type: .custom)

    init(optionTitles: [String], onSelect: @escaping (Int) -> Void) {
        self.optionTitles = optionTitles
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        activateConstraints()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyMaxHeightLimit()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playPresentAnimationIfNeeded()
    }

    private func setupViews() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(Self.dimAlpha)
        dimView.alpha = 0
        dimView.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        optionsGroupView.backgroundColor = colors.bgColorOperate
        optionsGroupView.layer.cornerRadius = Self.panelCornerRadius
        optionsGroupView.clipsToBounds = true
        optionsScrollView.showsVerticalScrollIndicator = true
        optionsScrollView.alwaysBounceVertical = false
        optionsScrollView.contentInsetAdjustmentBehavior = .never

        cancelButton.backgroundColor = colors.bgColorOperate
        cancelButton.layer.cornerRadius = Self.panelCornerRadius
        cancelButton.clipsToBounds = true
        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: Self.titleFontSize, weight: .semibold)
        cancelButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        view.addSubview(dimView)
        view.addSubview(contentView)
        contentView.addSubview(optionsGroupView)
        optionsGroupView.addSubview(optionsScrollView)
        optionsScrollView.addSubview(optionsContentView)
        contentView.addSubview(cancelButton)
        buildOptionRows()
    }

    private func buildOptionRows() {
        let colors = TUIChatKitTheme.colors
        var previousRow: UIView?
        for (index, title) in optionTitles.enumerated() {
            let row = UIButton(type: .custom)
            row.tag = index
            row.setTitle(title, for: .normal)
            row.setTitleColor(colors.textColorLink, for: .normal)
            row.titleLabel?.font = .systemFont(ofSize: Self.titleFontSize)
            row.addTarget(self, action: #selector(handleOptionTapped(_:)), for: .touchUpInside)
            optionsContentView.addSubview(row)
            row.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(Self.rowHeight)
                if let previousRow = previousRow {
                    make.top.equalTo(previousRow.snp.bottom)
                } else {
                    make.top.equalToSuperview()
                }
            }
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = colors.strokeColorPrimary
                optionsContentView.addSubview(separator)
                separator.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalTo(row.snp.top)
                    make.height.equalTo(Self.separatorHeight)
                }
            }
            previousRow = row
        }
        if let lastRow = previousRow {
            optionsContentView.snp.makeConstraints { make in
                make.bottom.equalTo(lastRow.snp.bottom)
            }
        }
    }

    private func activateConstraints() {
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.horizontalMargin)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Self.bottomMargin)
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top)
        }
        optionsGroupView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        optionsScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        optionsContentView.snp.makeConstraints { make in
            make.edges.equalTo(optionsScrollView.contentLayoutGuide)
            make.width.equalTo(optionsScrollView.frameLayoutGuide)
        }
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(optionsGroupView.snp.bottom).offset(Self.groupSpacing)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.rowHeight)
        }
    }

    private func applyMaxHeightLimit() {
        let availableHeight = view.bounds.height
            - view.safeAreaInsets.top
            - view.safeAreaInsets.bottom
            - Self.bottomMargin
        let cancelAreaHeight = Self.rowHeight + Self.groupSpacing
        let maxOptionsHeight = min(
            view.bounds.height * Self.maxPanelRatio,
            availableHeight - cancelAreaHeight
        )
        guard maxOptionsHeight > 0 else { return }
        let contentHeight = CGFloat(optionTitles.count) * Self.rowHeight
        optionsGroupView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(contentHeight).priority(.high)
            make.height.lessThanOrEqualTo(maxOptionsHeight)
        }
    }

    private func playPresentAnimationIfNeeded() {
        guard dimView.alpha == 0 else { return }
        view.layoutIfNeeded()
        contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height + Self.bottomMargin)
        UIView.animate(withDuration: Self.animationDuration) {
            self.dimView.alpha = 1
            self.contentView.transform = .identity
        }
    }

    @objc private func handleOptionTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index >= 0, index < optionTitles.count else { return }
        dismissPanel { [weak self] in
            self?.onSelect(index)
        }
    }

    @objc private func handleDismiss() {
        dismissPanel(completion: nil)
    }

    private func dismissPanel(completion: (() -> Void)?) {
        UIView.animate(withDuration: Self.animationDuration) {
            self.dimView.alpha = 0
            self.contentView.transform = CGAffineTransform(
                translationX: 0,
                y: self.contentView.bounds.height + Self.bottomMargin
            )
        } completion: { _ in
            self.dismiss(animated: false) {
                completion?()
            }
        }
    }
}
