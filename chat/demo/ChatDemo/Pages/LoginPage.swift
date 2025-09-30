import AtomicX
import AtomicXCore
import SwiftUI

class LoginStatusManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String = ""
    @Published var isLoggingIn: Bool = false
    @Published var loginError: String? = nil
    static let shared = LoginStatusManager()

    private init() {
        isLoggedIn = LoginStore.shared.state.value.loginStatus == .logined
        if isLoggedIn, let userInfo = LoginStore.shared.state.value.loginUserInfo {
            currentUserID = userInfo.userID
        }
    }

    func login(sdkAppID: Int32, userID: String, userSig: String, completion: @escaping (Bool) -> Void) {
        isLoggingIn = true
        loginError = nil
        LoginStore.shared.login(sdkAppID: sdkAppID, userID: userID, userSig: userSig, completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoggedIn = true
                    self.currentUserID = userID
                    self.isLoggingIn = false
                    completion(true)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.loginError = "\(LocalizedChatString("LoginFailed")): \(error.code), \(error.message)"
                    self.isLoggingIn = false
                    completion(false)
                }
            }
        })
    }

    func logout(completion: @escaping (Bool) -> Void) {
        LoginStore.shared.logout(completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.currentUserID = ""
                    self.isLoggingIn = false
                    completion(true)
                }
            case .failure(let error):
                completion(false)
            }
        })
    }
}

struct LoginPage: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var languageState: LanguageState
    @StateObject private var loginManager = LoginStatusManager.shared
    @State private var userID: String = ""
    @State private var sdkAppID: String = "1400187352"
    @State private var secretKey: String = "f442d0cca069bbcc8ced55f4f113b965999b928c78e3cd83495728133a06f4cb"
    @State private var isShowingSettings: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 60))
                    .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                    .padding(.bottom, 8)
                Text(LocalizedChatString("AppTitle"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeState.colors.textColorPrimary)
                Text(LocalizedChatString("AppSubtitle"))
                    .font(.subheadline)
                    .foregroundColor(Colors.GrayLight6)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
            VStack(spacing: 16) {
                TextField(LocalizedChatString("EnterUserID"), text: $userID)
                    .padding()
                    .background(themeState.colors.buttonColorSecondaryDefault)
                    .cornerRadius(8)
                    .foregroundColor(themeState.colors.textColorPrimary)
                if loginManager.loginError != nil {
                    Text(loginManager.loginError!)
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorTertiary)
                        .padding(.vertical, 4)
                }
                Button(action: {
                    login()
                }) {
                    if loginManager.isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(LocalizedChatString("login"))
                            .fontWeight(.semibold)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                    }
                }
                .background((userID.isEmpty || loginManager.isLoggingIn) ? themeState.colors.buttonColorPrimaryDisabled : themeState.colors.buttonColorPrimaryDefault)
                .foregroundColor(themeState.colors.textColorButton)
                .cornerRadius(8)
                .disabled(userID.isEmpty || loginManager.isLoggingIn)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func login() {
        guard let appID = Int32(sdkAppID) else {
            loginManager.loginError = LocalizedChatString("InvalidSDKAppID")
            return
        }
        let userSig = GenerateTestUserSig.genTestUserSig(userID: userID, sdkAppID: Int(appID), secretKey: secretKey)
        loginManager.login(sdkAppID: appID, userID: userID, userSig: userSig) { _ in
            loginManager.isLoggingIn = false
        }
    }
}
