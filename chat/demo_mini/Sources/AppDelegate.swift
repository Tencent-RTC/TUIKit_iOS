import AtomicXCore
import TUIChatKit
import RTCRoomEngine
import TUICallKit_Swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // 以下三个变量分别是：登录用户 ID、单聊测试对象 ID（对方用户）、群聊测试群 ID，可替换为你自己的。
    // 注意：单聊对象必须与登录用户互为好友，测试群必须真实存在且登录用户已在群内，否则发送消息、音视频通话都会失败。
    // 建议先跑通功能完整的 ChatDemo(用相同的sdkappid)，在其中添加好友、创建群聊后，再将对应的 ID 填写到这里。
    // 也可以直接使用本 Demo：在通讯录中即可添加好友、创建群聊，但是只有在本应用下(相同的sdkappid)登录过的账号才可以被添加为好友。
    private static let userID = "test1"
    private static let c2cChatUserID = "test2"
    private static let chatGroupID = "testGroup"

    private static var userSig: String {
        GenerateTestUserSig.genTestUserSig(identifier: userID)
    }

    private let navigationController = HiddenBarNavigationController()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        showHome()
        login()
        window?.makeKeyAndVisible()
        CustomLinkMessageRegistrar.register()
        return true
    }

    private var hasValidConfiguration: Bool {
        GenerateTestUserSig.sdkAppID > 0
            && !GenerateTestUserSig.secretKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func requireConfiguration() -> Bool {
        guard hasValidConfiguration else {
            guard navigationController.presentedViewController == nil else { return false }
            let alert = UIAlertController(
                title: NSLocalizedString("ConfigurationRequired", comment: ""),
                message: NSLocalizedString("ConfigurationGuide", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            navigationController.present(alert, animated: true)
            return false
        }
        return true
    }

    private func login() {
        guard hasValidConfiguration else { return }
        LoginStore.shared.login(sdkAppID: GenerateTestUserSig.sdkAppID, userID: Self.userID, userSig: Self.userSig) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.initCallEngine()
                case .failure(let error):
                    print("login failed: \(error.code) \(error.message)")
                }
            }
        }
    }

    private func showHome() {
        let homePage = HomeViewController(entries: [
            ("ShowConversationList", { [weak self] in self?.showConversationList() }),
            ("ShowC2CChat", { [weak self] in self?.showC2CChat() }),
            ("ShowGroupChat", { [weak self] in self?.showGroupChat() }),
            ("ShowContacts", { [weak self] in self?.showContacts() }),
            ("StartVideoCall", { [weak self] in self?.startVideoCall() }),
        ])
        navigationController.viewControllers = [homePage]
        window?.rootViewController = navigationController
    }

    private func showConversationList() {
        guard requireConfiguration() else { return }
        let conversationsPage = ConversationsPage(onConversationClick: { [weak self] info in
            self?.showChat(info.conversation)
        })
        navigationController.pushViewController(conversationsPage, animated: true)
    }

    private func showC2CChat() {
        guard requireConfiguration() else { return }
        showChat(Self.makeC2CConversation(userID: Self.c2cChatUserID, title: String(format: NSLocalizedString("C2CChatTitle", comment: ""), Self.c2cChatUserID)))
    }

    private func showGroupChat() {
        guard requireConfiguration() else { return }
        showChat(Self.makeGroupConversation(groupID: Self.chatGroupID, title: String(format: NSLocalizedString("GroupChatTitle", comment: ""), Self.chatGroupID)))
    }

    private func showContacts() {
        guard requireConfiguration() else { return }
        let contactsPage = ContactsPage(
            onContactClick: { [weak self] item in
                self?.showChat(Self.makeC2CConversation(userID: item.userID,
                                                        title: item.friendRemark ?? item.nickname ?? item.userID,
                                                        avatarURL: item.avatarURL))
            },
            onGroupClick: { [weak self] item in
                self?.showChat(Self.makeGroupConversation(groupID: item.groupID,
                                                          title: item.groupName ?? item.groupID,
                                                          avatarURL: item.avatarURL))
            }
        )
        navigationController.pushViewController(contactsPage, animated: true)
    }

    private static func makeC2CConversation(userID: String, title: String, avatarURL: String? = nil) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(userID))
        conversation.type = .c2c
        conversation.title = title
        conversation.avatarURL = avatarURL
        return conversation
    }

    private static func makeGroupConversation(groupID: String, title: String, avatarURL: String? = nil) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(groupID))
        conversation.type = .group
        conversation.title = title
        conversation.avatarURL = avatarURL
        return conversation
    }

    private func showChat(_ info: ConversationInfo) {
        let inputConfig = ChatMessageInputConfig(
            isShowVideoCall: true,
            isShowAudioCall: true,
            actionCustomizer: { editor in
                editor.add(Self.makeCustomLinkInputAction(conversationID: info.conversationID))
            }
        )
        let chatPage = ChatPage(conversation: info, messageInputConfig: inputConfig, onBack: { [weak self] in
            self?.navigationController.popViewController(animated: true)
        })
        navigationController.pushViewController(chatPage, animated: true)
    }

    private static func makeCustomLinkInputAction(conversationID: String) -> MessageInputMenuAction {
        MessageInputMenuAction(
            ID: "chatDemoMini.customLink",
            title: LocalizedChatString("DemoChatCustomMessageMenuTitle"),
            iconName: "",
            icon: UIImage(systemName: "paperplane.fill")?
                .withTintColor(TUIChatKitTheme.colors.textColorSecondary, renderingMode: .alwaysOriginal),
            onClick: {
                sendCustomLinkMessage(conversationID: conversationID)
            }
        )
    }

    private func initCallEngine() {
        TUICallEngine.createInstance().`init`(GenerateTestUserSig.sdkAppID, userId: Self.userID, userSig: Self.userSig) {
            TUICallEngine.createInstance().enableMultiDeviceAbility(enable: true) {
            } fail: { code, message in
                print("enableMultiDeviceAbility failed: \(code), \(message ?? "")")
            }
            TUICallKit.createInstance().enableIncomingBanner(enable: true)
        } fail: { code, message in
            print("initCallEngine failed: \(code), \(message ?? "")")
        }
    }

    private func startVideoCall() {
        guard requireConfiguration() else { return }
        TUICallKit.createInstance().calls(userIdList: [Self.c2cChatUserID], mediaType: .video, params: nil, completion: nil)
    }
}

private final class HomeViewController: UIViewController {
    private let entries: [(key: String, handler: () -> Void)]

    init(entries: [(key: String, handler: () -> Void)]) {
        self.entries = entries
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let buttons = entries.map { entry in
            let button = UIButton(type: .system, primaryAction: UIAction(title: NSLocalizedString(entry.key, comment: "")) { _ in entry.handler() })
            button.accessibilityIdentifier = entry.key
            return button
        }
        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .vertical
        stackView.spacing = 16
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

private final class HiddenBarNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
