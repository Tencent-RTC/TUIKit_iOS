import AtomicXCore
import TencentCloudAIDeskCustomer
import TUIChatKit
import UIKit

enum CustomerServiceManager {
    static let customerServiceUserID = "@customer_service_account"

    static let customerServiceConversationID = "c2c_@customer_service_account"

    private static let srcWelcome = "7"

    private static let customerServicePluginKey = "customerServicePlugin"

    private static var summaryRegistered = false

    static func initAndStart(sdkAppID: Int32, userID: String, userSig: String) {
        TencentCloudCustomerManager.shared().initWithProfile(
            sdkAppID,
            userID: userID,
            userSig: userSig,
            nickName: nil,
            avatar: nil
        ) { error in
            if let error = error {
                print("[CustomerService] init failed: \(error)")
                return
            }
            TencentCloudCustomerManager.shared().setShowHumanService(true)
            sendWelcomeMessageAndPin()
        }
    }

    static func openCustomerServiceChat(from viewController: UIViewController) {
        // SDK 内部的 push 不会隐藏底部 TabBar，这里拿到聊天 VC 自行 push，
        // 通过 hidesBottomBarWhenPushed 让客服聊天页全屏覆盖底部栏（对齐 Android）
        guard let navigationController = viewController.navigationController,
              let chatViewController = TencentCloudCustomerManager.shared().getCustomerServiceViewController()
        else {
            TencentCloudCustomerManager.shared().pushCustomerServiceChat(from: viewController)
            return
        }
        chatViewController.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(chatViewController, animated: true)
    }

    static func registerSummary() {
        guard !summaryRegistered else { return }
        summaryRegistered = true
        MessageListView.registerCustomMessageSummary(matcher: { payload in
            guard let data = payload.customData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json[customerServicePluginKey] != nil else { return nil }
            return LocalizedChatString("DemoCustomerServiceSummary")
        })
    }

    private static func sendWelcomeMessageAndPin() {
        let payload: [String: Any] = [
            "src": srcWelcome,
            customerServicePluginKey: 0,
            "triggeredContent": ["language": currentLanguageTag()],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let customPayload = CustomSendMessagePayload(customData: json, description: "")
        MessageInputStore.create(conversationID: customerServiceConversationID)
            .sendMessage(payload: .custom(customPayload), option: nil) { result in
                switch result {
                case .success:
                    pinCustomerServiceConversation()
                case .failure(let error):
                    print("[CustomerService] send welcome message failed: \(error.code) \(error.message)")
                }
            }
    }

    private static func pinCustomerServiceConversation() {
        ConversationListStore.create().pinConversation(
            conversationID: customerServiceConversationID,
            pin: true
        ) { result in
            if case .failure(let error) = result {
                print("[CustomerService] pin conversation failed: \(error.code) \(error.message)")
            }
        }
    }

    private static func currentLanguageTag() -> String {
        let language = LanguageHelper.getCurrentLanguage()
        if language.hasPrefix("zh") {
            return language
        }
        return Locale.current.languageCode ?? "en"
    }
}
