import AtomicXCore
import TUIChatKit
import Combine
import TUICallKit_Swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let administratorConversationID = "c2c_administrator"

    private static let welcomeMessageDelay: TimeInterval = 1

    private var cancellables = Set<AnyCancellable>()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAppConfiguration()
        CustomLinkMessageManager.register()
        CustomerServiceManager.registerSummary()
        ChatCallEventSubscriber.shared.ensureSubscribed()
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

public final class ChatCallEventSubscriber: NSObject {
    public static let shared = ChatCallEventSubscriber()

    private static let startCallEventName = Notification.Name("tuicallkit.startCall")
    private static let startJoinEventName = Notification.Name("tuicallkit.startJoin")
    private static let keyParticipantIDs = "participantIds"
    private static let keyMediaType = "mediaType"
    private static let keyChatGroupID = "chatGroupId"
    private static let keyTimeout = "timeout"
    private static let keyCallID = "callId"

    private var isSubscribed = false

    private override init() {
        super.init()
    }

    public func ensureSubscribed() {
        guard !isSubscribed else { return }
        isSubscribed = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleStartCallEvent(_:)),
                                               name: Self.startCallEventName,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleStartJoinEvent(_:)),
                                               name: Self.startJoinEventName,
                                               object: nil)
    }

    @objc private func handleStartCallEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let participantIDs = userInfo[Self.keyParticipantIDs] as? [String],
              !participantIDs.isEmpty else { return }
        let mediaType: CallMediaType = (userInfo[Self.keyMediaType] as? String) == "video" ? .video : .audio
        let chatGroupID = userInfo[Self.keyChatGroupID] as? String ?? ""
        let timeout = userInfo[Self.keyTimeout] as? Int ?? 30

        var callParams = CallParams()
        callParams.chatGroupId = chatGroupID
        callParams.timeout = timeout
        TUICallKit.createInstance().calls(userIdList: participantIDs, mediaType: mediaType, params: callParams, completion: nil)
    }

    @objc private func handleStartJoinEvent(_ notification: Notification) {
        guard let callID = notification.userInfo?[Self.keyCallID] as? String, !callID.isEmpty else { return }
        TUICallKit.createInstance().join(callId: callID, completion: nil)
    }
}
