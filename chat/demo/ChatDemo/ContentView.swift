import AtomicX
import AtomicXCore
import Combine
import SwiftUI

public enum RootPage {
    case login
    case home
}

struct ContentView: View {
    @StateObject private var themeState = ThemeState()
    @StateObject private var appStyleSettings = AppStyleSettings()
    @StateObject private var languageState = LanguageState()
    @State private var currentPage: RootPage = .login
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            Group {
                switch currentPage {
                case .login:
                    LoginPage()
                case .home:
                    HomePage()
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(themeState)
        .environmentObject(appStyleSettings)
        .environmentObject(languageState)
        .preferredColorScheme(getPreferredColorScheme())
        .environment(\.layoutDirection, getLayoutDirection())
        .onAppear {
            languageState.setLanguage(languageState.currentLanguage)
            setupLoginStatusObserver()
        }
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch themeState.currentMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            if themeState.isDarkMode {
                return .dark
            }
            else {
                return .light
            }
        }
    }
    
    private func getLayoutDirection() -> LayoutDirection {
        // Right-to-left languages
        let rtlLanguages = ["ar", "he", "fa", "ur"]
        return rtlLanguages.contains(languageState.currentLanguage) ? .rightToLeft : .leftToRight
    }
    
    private func setupLoginStatusObserver() {
        let currentLoginStatus = LoginStore.shared.state.value.loginStatus
        if currentLoginStatus == .logined {
            currentPage = .home
        } else {
            currentPage = .login
        }

        LoginStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
            .sink { loginStatus in
                DispatchQueue.main.async {
                    handleLoginStatusChange(loginStatus)
                }
            }
            .store(in: &cancellables)
    }

    private func handleLoginStatusChange(_ loginStatus: LoginStatus) {
        switch loginStatus {
        case .logined:
            if currentPage == .login {
                currentPage = .home
            }
        case .unlogin:
            currentPage = .login
        }
    }
}
