import AtomicXCore
import ChatUIKit
import Combine
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let administratorConversationID = "c2c_administrator"

    private static let welcomeMessageDelay: TimeInterval = 1

    private var cancellables = Set<AnyCancellable>()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAppConfiguration()
        CustomLinkMessageManager.register()
        setupLoginObserver()

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    private func setupLoginObserver() {
        LoginStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
            .sink { [weak self] loginStatus in
                guard let self = self else { return }
                if loginStatus == .logined {
                    self.scheduleWelcomeMessage()
                }
            }
            .store(in: &cancellables)
    }

    private func scheduleWelcomeMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.welcomeMessageDelay) {
            let inputStore = MessageInputStore.create(conversationID: Self.administratorConversationID)
            let payload = TextSendMessagePayload(text: LocalizedChatString("DemoWelcomeMessage"))
            inputStore.sendMessage(payload: .text(payload), option: nil, completion: nil)
        }
    }

    private func setupAppConfiguration() {
        if let configPath = Bundle.main.path(forResource: "appConfig", ofType: "json") {
            print("appConfig.json existed: \(configPath)")
            AppBuilderHelper.setJsonPath(path: configPath)
        } else {
            print("appConfig.json not found")
        }

        syncUserSettingsToAppConfig()
    }

    private func syncUserSettingsToAppConfig() {

        let readReceiptKey = "com.atomicx.enableReadReceipt"
        if UserDefaults.standard.object(forKey: readReceiptKey) != nil {
            AppBuilderConfig.shared.enableReadReceipt = UserDefaults.standard.bool(forKey: readReceiptKey)
        }

        let translateKey = "com.atomicx.translateTargetLanguage"
        if let saved = UserDefaults.standard.string(forKey: translateKey), !saved.isEmpty {
            AppBuilderConfig.shared.translateTargetLanguage = saved
        } else if AppBuilderConfig.shared.translateTargetLanguage.isEmpty {

            var systemLanguage = LanguageHelper.getCurrentLanguage()
            if systemLanguage == "zh-Hans" {
                systemLanguage = "zh"
            } else if systemLanguage == "zh-Hant" {
                systemLanguage = "zh-TW"
            }
            AppBuilderConfig.shared.translateTargetLanguage = systemLanguage
        }
    }
}
