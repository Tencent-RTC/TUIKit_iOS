import AtomicX
import AtomicXCore
import SwiftUI

struct ColorOption: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    let color: Color
    init(name: String, hex: String) {
        self.name = name
        self.hex = hex
        self.color = Color(hexString: hex)
    }
}

extension ThemeConfig {
    var displayName: String {
        let modeName: String
        switch mode {
        case .system:
            modeName = LocalizedChatString("ThemeNameSystem")
        case .light:
            modeName = LocalizedChatString("ThemeNameLight")
        case .dark:
            modeName = LocalizedChatString("ThemeNameDark")
        }
        if let primaryColor = primaryColor {
            return "\(modeName) + \(primaryColor)"
        } else {
            return modeName
        }
    }
}

let presetColors = [
    ColorOption(name: LocalizedChatString("ColorRed"), hex: "#E54545"),
    ColorOption(name: LocalizedChatString("ColorOrange"), hex: "#FF7200"),
    ColorOption(name: LocalizedChatString("ColorYellow"), hex: "#7ff879"),
    ColorOption(name: LocalizedChatString("ColorGreen"), hex: "#0ABF77"),
    ColorOption(name: LocalizedChatString("ColorBlue"), hex: "#1C66E5"),
    ColorOption(name: LocalizedChatString("ColorPurple"), hex: "#AF52DE")
]

struct SettingsPage: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var appStyleSettings: AppStyleSettings
    @EnvironmentObject var languageState: LanguageState
    @ObservedObject private var loginManager = LoginStatusManager.shared
    @State private var loginStore = LoginStore.shared
    @State private var allowType: AllowType? = nil
    @State private var showStylePicker = false
    @State private var themeListExpanded = false
    @State private var primaryColorListExpanded = false
    @State private var languageListExpanded = false
    @State private var approveListExpanded = false
    @State private var showProfileDetail = false

    // State variables for real-time updates
    @State private var nickname: String? = nil
    @State private var avatarURL: String? = nil
    @State private var selfSignature: String? = nil

    private func getNickName() -> String {
        if let nickname = nickname, !nickname.isEmpty {
            return nickname
        }
        return loginManager.currentUserID
    }

    private func getSelfSignature() -> String {
        return selfSignature ?? LocalizedChatString("NoSelfSignature")
    }

    var body: some View {
        VStack {
            headerView
            List {
                Section(header: Text(LocalizedChatString("PersonalInfo")).foregroundColor(themeState.colors.textColorSecondary)) {
                    Button(action: {
                        showProfileDetail = true
                    }) {
                        HStack {
                            Avatar(url: self.avatarURL, name: getNickName(), size: .xl)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(getNickName())")
                                    .font(.headline)
                                    .foregroundColor(themeState.colors.textColorPrimary)
                                Text("\(LocalizedChatString("ProfileAccount")): \(loginManager.currentUserID)")
                                    .font(.caption)
                                    .foregroundColor(themeState.colors.textColorSecondary)
                                Text("\(LocalizedChatString("ProfileSignature")): \(getSelfSignature())")
                                    .font(.caption)
                                    .foregroundColor(themeState.colors.textColorSecondary)
                            }
                            .padding(.vertical, 10)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listRowBackground(themeState.colors.listColorDefault)
                Section(header: Text(LocalizedChatString("Settings")).foregroundColor(themeState.colors.textColorSecondary)) {
                    AddMeApproveView()
                    themeSelectionView()
                    languageSelectionView()
                }
                .listRowBackground(themeState.colors.listColorDefault)
                Section {
                    Button(action: {
                        loginManager.logout { success in
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }) {
                        Text(LocalizedChatString("logout"))
                            .foregroundColor(themeState.colors.textColorError)
                    }
                }
                .listRowBackground(themeState.colors.listColorDefault)
            }
            .background(themeState.colors.bgColorDefault)
            .listStyle(InsetGroupedListStyle())
        }
        .id("SettingsPage-\(languageState.currentLanguage)")
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.allowType))) { allowType in
            self.allowType = allowType
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.nickname))) { nickname in
            self.nickname = nickname
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.avatarURL))) { avatarURL in
            self.avatarURL = avatarURL
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.selfSignature))) { selfSignature in
            self.selfSignature = selfSignature
        }
        .onAppear {
            // Initialize with current values
            self.nickname = loginStore.state.value.loginUserInfo?.nickname
            self.avatarURL = loginStore.state.value.loginUserInfo?.avatarURL
            self.selfSignature = loginStore.state.value.loginUserInfo?.selfSignature
        }
        .fullScreenCover(isPresented: $showProfileDetail) {
            NavigationView {
                ProfileDetailView()
                    .environmentObject(themeState)
                    .environmentObject(languageState)
                    .navigationBarItems(
                        leading: Button(LocalizedChatString("Cancel")) {
                            showProfileDetail = false
                        }
                        .foregroundColor(themeState.colors.textColorLink)
                    )
            }
        }
    }

    @ViewBuilder
    private func AddMeApproveView() -> some View {
        Button(action: { withAnimation { approveListExpanded.toggle() } }) {
            HStack {
                Text(LocalizedChatString("MeFriendRequest"))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(getCurrentApproveDisplayName())
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .id("approve_display_\(allowType?.rawValue ?? -1)")
                Image(systemName: approveListExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        if approveListExpanded {
            Group {
                createApproveOption(title: LocalizedChatString("AllowTypeAcceptOne"), allowType: .allowAny)
                createApproveOption(title: LocalizedChatString("AllowTypeNeedConfirm"), allowType: .needConfirm)
                createApproveOption(title: LocalizedChatString("AllowTypeDeclineAll"), allowType: .denyAny)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func themeSelectionView() -> some View {
        themeModeSelectionView()
        primaryColorSelectionView()
    }

    @ViewBuilder
    private func themeModeSelectionView() -> some View {
        Button(action: { withAnimation { themeListExpanded.toggle() } }) {
            HStack {
                Text(LocalizedChatString("SelectThemeMode"))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(getCurrentModeDisplayName())
                    .foregroundColor(themeState.colors.textColorSecondary)
                Image(systemName: themeListExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        if themeListExpanded {
            Group {
                createThemeModeOption(title: LocalizedChatString("ThemeNameLight"), color: .gray.opacity(0.2), mode: .light)
                createThemeModeOption(title: LocalizedChatString("ThemeNameDark"), color: .black, mode: .dark)
                createThemeModeOption(title: LocalizedChatString("ThemeNameSystem"), color: .blue, mode: .system)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func primaryColorSelectionView() -> some View {
        Button(action: { withAnimation { primaryColorListExpanded.toggle() } }) {
            HStack {
                Text(LocalizedChatString("SelectPrimaryColor"))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(getCurrentPrimaryColorDisplayName())
                    .foregroundColor(themeState.colors.textColorSecondary)
                Image(systemName: primaryColorListExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        if primaryColorListExpanded {
            Group {
                createDefaultColorOption()
                if themeState.hasCustomPrimaryColor {
                    createClearColorOption()
                }
                ForEach(presetColors) { colorOption in
                    createCustomThemeOption(colorOption: colorOption)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func getCurrentApproveDisplayName() -> String {
        guard let allowType = allowType else {
            return ""
        }
        switch allowType {
        case .allowAny:
            return LocalizedChatString("AllowTypeAcceptOne")
        case .needConfirm:
            return LocalizedChatString("AllowTypeNeedConfirm")
        case .denyAny:
            return LocalizedChatString("AllowTypeDeclineAll")
        }
    }

    @ViewBuilder
    private func createApproveOption(title: String, allowType: AllowType) -> some View {
        Button(action: {
            setAllowType(allowType)
            approveListExpanded = false
        }) {
            HStack {
                Text(title)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if allowType == self.allowType {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .id("approve_option_\(allowType.rawValue)")
    }

    private func setAllowType(_ allowType: AllowType) {
        if var info = loginStore.state.value.loginUserInfo {
            info.allowType = allowType
            LoginStore.shared.setSelfInfo(userProfile: info, completion: nil)
        }
    }

    private func getCurrentModeDisplayName() -> String {
        switch themeState.currentMode {
        case .system:
            return LocalizedChatString("ThemeNameSystem")
        case .light:
            return LocalizedChatString("ThemeNameLight")
        case .dark:
            return LocalizedChatString("ThemeNameDark")
        }
    }

    private func getCurrentPrimaryColorDisplayName() -> String {
        if let primaryColor = themeState.currentPrimaryColor {
            return primaryColor
        } else {
            return LocalizedChatString("DefaultColor")
        }
    }

    @ViewBuilder
    private func createDefaultColorOption() -> some View {
        Button(action: {
            themeState.clearPrimaryColor()
            primaryColorListExpanded = false
        }) {
            HStack {
                Circle().fill(.blue).frame(width: 20, height: 20)
                Text(LocalizedChatString("DefaultColor"))
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if !themeState.hasCustomPrimaryColor {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func createThemeModeOption(title: String, color: Color, mode: ThemeMode) -> some View {
        Button(action: {
            themeState.setThemeMode(mode)
            themeListExpanded = false
        }) {
            HStack {
                Circle().fill(color).frame(width: 20, height: 20)
                Text(title)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if themeState.currentMode == mode && !themeState.hasCustomPrimaryColor {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func createClearColorOption() -> some View {
        Button(action: {
            themeState.clearPrimaryColor()
            primaryColorListExpanded = false
        }) {
            HStack {
                Circle().fill(.gray).frame(width: 20, height: 20)
                Text(LocalizedChatString("ClearCustomColor"))
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if !themeState.hasCustomPrimaryColor {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func createCustomThemeOption(colorOption: ColorOption) -> some View {
        Button(action: {
            themeState.setPrimaryColor(colorOption.hex)
            primaryColorListExpanded = false
        }) {
            HStack {
                Circle().fill(colorOption.color).frame(width: 20, height: 20)
                Text(colorOption.name)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if themeState.currentPrimaryColor == colorOption.hex {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func languageSelectionView() -> some View {
        Button(action: { withAnimation { languageListExpanded.toggle() } }) {
            HStack {
                Text(LocalizedChatString("SelectLanguage"))
                    .foregroundColor(themeState.colors.textColorPrimary)
                Spacer()
                Text(languageState.getCurrentLanguageName())
                    .foregroundColor(themeState.colors.textColorSecondary)
                Image(systemName: languageListExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        if languageListExpanded {
            Group {
                ForEach(languageState.supportedLanguages) { language in
                    createLanguageOption(language: language)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func createLanguageOption(language: LanguageOption) -> some View {
        Button(action: {
            languageState.setLanguage(language.code)
            languageListExpanded = false
        }) {
            HStack {
                Text(language.nativeName)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if languageState.currentLanguage == language.code {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var headerView: some View {
        HStack {
            Text(LocalizedChatString("TabSettings"))
                .font(.system(size: 34, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(themeState.colors.textColorPrimary)
                .background(themeState.colors.listColorDefault)
                .padding(.leading, 16)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

enum Theme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case custom = "Custom"
}

struct ThemePicker: View {
    @Binding var selectedTheme: Theme
    @EnvironmentObject var themeState: ThemeState
    var body: some View {
        NavigationView {
            List {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button(action: {
                        selectedTheme = theme
                    }) {
                        HStack {
                            Text(theme.rawValue)
                            if selectedTheme == theme {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(LocalizedChatString("SelectTheme"), displayMode: .inline)
        }
    }
}

struct ProfileDetailView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var languageState: LanguageState
    @ObservedObject private var loginManager = LoginStatusManager.shared
    @State private var loginStore = LoginStore.shared
    @State private var showingAvatarPicker = false
    @State private var showingNicknameSheet = false
    @State private var showingSignatureSheet = false
    @State private var showingGenderActionSheet = false
    @State private var showingGenderSheet = false
    @State private var showingDatePicker = false
    @State private var gender: Gender? = nil
    @State private var selectedDate = Date()
    @State private var birthday: UInt32? = nil
    @State private var nickname: String?
    @State private var avatar: String?
    @State private var selfSignature: String?

    private func getNickName() -> String {
        if let nickname = loginStore.state.value.loginUserInfo?.nickname, !nickname.isEmpty {
            return nickname
        }
        return loginManager.currentUserID
    }

    private func getGenderText() -> String {
        guard let gender = gender else {
            return LocalizedChatString("Unsetted")
        }
        switch gender {
        case .male:
            return LocalizedChatString("Male")
        case .female:
            return LocalizedChatString("Female")
        case .unknown:
            return LocalizedChatString("Unknown")
        }
    }

    private func getBirthdayText() -> String {
        let birthday = birthday ?? loginStore.state.value.loginUserInfo?.birthday
        guard let birthday = birthday else {
            return LocalizedChatString("Unsetted")
        }
        let date = Date(timeIntervalSince1970: TimeInterval(birthday))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Button(action: {
                    showingAvatarPicker = true
                }) {
                    Avatar(url: self.avatar, name: self.getNickName(), size: .xxl)
                }

                Button(action: {
                    showingNicknameSheet = true
                }) {
                    Text(self.getNickName())
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(themeState.colors.textColorLink)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 30)

            List {
                Section {
                    HStack {
                        Text(LocalizedChatString("ProfileAccount"))
                            .foregroundColor(themeState.colors.textColorPrimary)
                        Spacer()
                        Text(loginManager.currentUserID)
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    .listRowBackground(themeState.colors.listColorDefault)

                    Button(action: {
                        showingSignatureSheet = true
                    }) {
                        HStack {
                            Text(LocalizedChatString("ProfileSignature"))
                                .foregroundColor(themeState.colors.textColorPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(themeState.colors.listColorDefault)

                    Button(action: {
                        showingGenderActionSheet = true
                    }) {
                        HStack {
                            Text(LocalizedChatString("ProfileGender"))
                                .foregroundColor(themeState.colors.textColorPrimary)
                            Spacer()
                            Text(getGenderText())
                                .foregroundColor(themeState.colors.textColorSecondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(themeState.colors.listColorDefault)

                    Button(action: {
                        if let birthday = loginStore.state.value.loginUserInfo?.birthday {
                            selectedDate = Date(timeIntervalSince1970: TimeInterval(birthday))
                        }
                        showingDatePicker = true
                    }) {
                        HStack {
                            Text(LocalizedChatString("ProfileBirthday"))
                                .foregroundColor(themeState.colors.textColorPrimary)
                            Spacer()
                            Text(getBirthdayText())
                                .foregroundColor(themeState.colors.textColorSecondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(themeState.colors.listColorDefault)
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .background(themeState.colors.bgColorDefault)
        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.avatarURL))) { avatarURL in
            self.avatar = avatarURL
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.nickname))) { nickname in
            self.nickname = nickname
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.selfSignature))) { selfSignature in
            self.selfSignature = selfSignature
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.gender))) { gender in
            self.gender = gender
        }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.birthday))) { birthday in
            self.birthday = birthday
        }
        .onAppear {
            // Initialize with current values
            self.avatar = loginStore.state.value.loginUserInfo?.avatarURL
            self.nickname = loginStore.state.value.loginUserInfo?.nickname
            self.selfSignature = loginStore.state.value.loginUserInfo?.selfSignature
            self.gender = loginStore.state.value.loginUserInfo?.gender
            self.birthday = loginStore.state.value.loginUserInfo?.birthday
        }
        .modifier(GenderActionSheetModifier(isPresented: $showingGenderActionSheet, onGenderSelected: updateGender))
        .background(
            NavigationLink(
                destination: AvatarSelector(
                    imageUrlList: createUserAvatarUrlList(),
                    column: 4,
                    onComplete: { selectedImageUrl in
                        if let userID = loginStore.state.value.loginUserInfo?.userID {
                            let user = UserProfile(userID: userID, nickname: nil, avatarURL: selectedImageUrl)
                            loginStore.setSelfInfo(userProfile: user, completion: nil)
                        }
                    }
                ),
                isActive: $showingAvatarPicker
            ) {
                EmptyView()
            }
            .hidden()
        )
        .sheet(isPresented: $showingNicknameSheet) {
            nicknameEditSheet(
                currentNickname: self.nickname ?? "",
                onSave: { newNickname in
                    if let userID = loginStore.state.value.loginUserInfo?.userID {
                        let user = UserProfile(userID: userID, nickname: newNickname)
                        loginStore.setSelfInfo(userProfile: user, completion: nil)
                    }
                }
            )
            .modifier(SheetModifier())
        }
        .sheet(isPresented: $showingSignatureSheet) {
            selfSignatureEditSheet(
                currentSignature: loginStore.state.value.loginUserInfo?.selfSignature ?? "",
                onSave: { selfSignature in
                    if let userID = loginStore.state.value.loginUserInfo?.userID {
                        var user = UserProfile(userID: userID)
                        user.selfSignature = selfSignature
                        loginStore.setSelfInfo(userProfile: user, completion: nil)
                    }
                }
            )
            .modifier(SheetModifier())
        }
        .sheet(isPresented: $showingDatePicker) {
            birthdayEditSheet(
                currentDate: selectedDate,
                onSave: { newDate in
                    updateBirthday(newDate)
                }
            )
            .environmentObject(languageState)
            .modifier(SheetModifier())
        }
    }

    private func createUserAvatarUrlList() -> [String] {
        return (1 ... 27).map { index in
            "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\(index).png"
        }
    }

    private func updateGender(_ genderRawValue: Int) {
        let gender: Gender
        switch genderRawValue {
        case 1:
            gender = .male
        case 2:
            gender = .female
        default:
            gender = .unknown
        }

        if let userID = loginStore.state.value.loginUserInfo?.userID {
            var user = UserProfile(userID: userID)
            user.gender = gender
            loginStore.setSelfInfo(userProfile: user, completion: nil)
        }
    }

    private func updateBirthday(_ date: Date) {
        let birthday = UInt32(date.timeIntervalSince1970)
        if let userID = loginStore.state.value.loginUserInfo?.userID {
            var user = UserProfile(userID: userID)
            user.birthday = birthday
            loginStore.setSelfInfo(userProfile: user, completion: nil)
        }
    }
}

private struct nicknameEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newNickname: String = ""
    let currentNickname: String
    let onSave: (String) -> Void

    var body: some View {
        TextEditSheet(
            title: LocalizedChatString("ProfileEditName"),
            currentText: currentNickname,
            placeholder: LocalizedChatString("ProfileEditName"),
            helpText: LocalizedChatString("ProfileEditNameDesc"),
            onSave: onSave
        )
    }
}

private struct selfSignatureEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newSignature: String = ""
    let currentSignature: String
    let onSave: (String) -> Void

    var body: some View {
        TextEditSheet(
            title: LocalizedChatString("ProfileEditSignture"),
            currentText: currentSignature,
            placeholder: LocalizedChatString("ProfileEditSignture"),
            helpText: LocalizedChatString("ProfileEditNameDesc"),
            onSave: onSave
        )
    }
}

private struct birthdayEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var languageState: LanguageState
    @State private var selectedDate: Date
    let currentDate: Date
    let onSave: (Date) -> Void

    init(currentDate: Date, onSave: @escaping (Date) -> Void) {
        self.currentDate = currentDate
        self.onSave = onSave
        self._selectedDate = State(initialValue: currentDate)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.secondary)

                Spacer()

                Button(LocalizedChatString("Save")) {
                    onSave(selectedDate)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            .environment(\.locale, Locale(identifier: languageState.currentLanguage))
        }
    }
}

private struct GenderActionSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onGenderSelected: (Int) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .confirmationDialog(LocalizedChatString("ProfileEditGender"), isPresented: $isPresented, titleVisibility: .visible) {
                    Button(LocalizedChatString("Male")) {
                        onGenderSelected(1)
                    }
                    Button(LocalizedChatString("Female")) {
                        onGenderSelected(2)
                    }
                    Button(LocalizedChatString("Cancel"), role: .cancel) {}
                }
        } else {
            content
                .actionSheet(isPresented: $isPresented) {
                    ActionSheet(
                        title: Text(LocalizedChatString("ProfileEditGender")),
                        buttons: [
                            .default(Text(LocalizedChatString("Male"))) {
                                onGenderSelected(1)
                            },
                            .default(Text(LocalizedChatString("Female"))) {
                                onGenderSelected(2)
                            },
                            .cancel(Text(LocalizedChatString("Cancel")))
                        ]
                    )
                }
        }
    }
}

private struct SheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(false)
        } else {
            content
        }
    }
}
