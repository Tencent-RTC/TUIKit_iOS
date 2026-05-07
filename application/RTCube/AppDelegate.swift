//
//  AppDelegate.swift
//  RTCube
//

import AtomicX
#if !OPEN_SOURCE
import Bugly
#endif
import Login
import Network
#if !OPEN_SOURCE
import TCMediaX
import TEBeautyKitWrapper
#endif
import TUICore
import TXLiteAVSDK_Professional
import UIKit
import UserNotifications
#if !OPEN_SOURCE
import XMagic
import YTCommonXMagic
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var networkMonitor: NWPathMonitor?

    @objc var window: UIWindow? {
        for scene in UIApplication.shared.connectedScenes where scene.activationState == .foregroundActive {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            if let firstWindow = windowScene.windows.first {
                return firstWindow
            }
        }
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               let w = windowScene.windows.first
            {
                return w
            }
        }
        return nil
    }

    // MARK: - Application Lifecycle

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        #if DEBUG
        setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 1)
        #endif

        syncAppLanguageToTUIGlobalization()

        ThemeStore.shared.setMode(.light)

        AppLifecycleRegistry.shared.applicationDidFinishLaunching(application)

        setupLicence()
        startNetworkMonitorForLicence()

        registerPushLifecycleHandler()
        registerRemoteNotifications(with: application)

        setupIMListeners()

        #if !OPEN_SOURCE
        registerBuglyIfNeeded()
        #endif

        registerAnalytics(with: launchOptions)

        setupNavigationBarAppearance()

        return true
    }

    // MARK: - Orientation Control

    static var allowedOrientations: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask
    {
        return AppDelegate.allowedOrientations
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    // MARK: - URL Handling

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if AppLifecycleRegistry.shared.handleOpenURL(url, options: options) {
            return true
        }
        #if !DEBUG
        if AppAnalytics.handleSchemeURL(url) {
            return true
        }
        #endif
        return false
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        return AppLifecycleRegistry.shared.handleOpenURL(url)
    }
}

extension AppDelegate {
    func syncAppLanguageToTUIGlobalization() {
        guard let appLanguage = Bundle.main.preferredLocalizations.first else { return }
        let tuiLanguage: String
        if appLanguage.hasPrefix("zh") {
            if appLanguage.contains("Hant") || appLanguage.contains("TW") || appLanguage.contains("HK") {
                tuiLanguage = "zh-Hant"
            } else {
                tuiLanguage = "zh-Hans"
            }
        } else if appLanguage.hasPrefix("ar") {
            tuiLanguage = "ar"
        } else {
            tuiLanguage = "en"
        }
        TUIGlobalization.setPreferredLanguage(tuiLanguage)
    }
}

extension AppDelegate {
    ///
    ///   - `TXLiveBase.setLicenceURL(LICENSEURL, key: LICENSEURLKEY)`
    ///   - `TXUGCBase.setLicenceURL(LICENSEURL_SHORTVIDEO, key: LICENSEKEY_SHORTVIDEO)`
    ///
    private func setupLicence() {
        #if !OPEN_SOURCE
        V2TXLivePremier.setLicence(LIVE_LICENSE_URL, key: LIVE_LICENSE_KEY)
        TXLiveBase.setLicenceURL(LIVE_LICENSE_URL, key: LIVE_LICENSE_KEY)
        TXUGCBase.setLicenceURL(TENCENT_EFFECT_LICENSE_URL, key: TENCENT_EFFECT_LICENSE_KEY)
//        TUIBeautyKit.initialize(licenseUrl: TENCENT_EFFECT_LICENSE_URL,
//                                licenseKey: TENCENT_EFFECT_LICENSE_KEY,
//                                beautyLevel: .S1_07)
        TCMediaXBase.getInstance().setDelegate(self)
        TCMediaXBase.getInstance().setLicenceURL(TENCENT_EFFECT_LICENSE_URL, key: TENCENT_EFFECT_LICENSE_KEY)
        #endif
    }

    private func startNetworkMonitorForLicence() {
        networkMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.rtcube.NetworkMonitor")
        networkMonitor?.pathUpdateHandler = { path in
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    #if !OPEN_SOURCE
                    V2TXLivePremier.setLicence(LIVE_LICENSE_URL, key: LIVE_LICENSE_KEY)
                    TELicenseCheck.setTELicense(TENCENT_EFFECT_LICENSE_URL, key: TENCENT_EFFECT_LICENSE_KEY) { _, _ in }
                    #endif
                }
            }
        }
        networkMonitor?.start(queue: queue)
    }
}

extension AppDelegate {
    private func registerPushLifecycleHandler() {
        PushLifecycleHandler.shared.businessID = PUSH_BUSINESS_ID
        AppLifecycleRegistry.shared.register(PushLifecycleHandler.shared)
    }

    private func registerRemoteNotifications(with application: UIApplication) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, error in
            DispatchQueue.main.async {
                if error == nil, isGranted {
                    AppLogger.App.info(" 用户允许了推送权限")
                } else {
                    AppLogger.App.info(" 用户拒绝了推送权限")
                }
            }
        }
        application.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        AppLogger.App.info(" didRegisterForRemoteNotificationsWithDeviceToken success")
        AppLifecycleRegistry.shared.applicationDidRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        AppLogger.App.info(" didFailToRegisterForRemoteNotificationsWithError: \(error)")
    }
}

extension AppDelegate: V2TIMConversationListener, V2TIMAPNSListener {
    private func setupIMListeners() {
        V2TIMManager.sharedInstance().setAPNSListener(apnsListener: self)
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
    }

    // MARK: V2TIMConversationListener

    func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
    }

    // MARK: V2TIMAPNSListener

    func onSetAPPUnreadCount() -> UInt32 {
        return 0
    }
}

extension AppDelegate {
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

#if !OPEN_SOURCE
extension AppDelegate {
    private func registerBuglyIfNeeded() {
        #if RTCUBE_LAB || !DEBUG
        let buglyConfig = BuglyConfig(appId: BUGLY_APP_ID, appKey: BUGLY_APP_KEY)
        #if DEBUG
        buglyConfig.debugMode = true
        #endif
        let userId = TUILogin.getUserID() ?? ""
        buglyConfig.userIdentifier = userId
        Bugly.start(with: buglyConfig)
        #endif
    }

    func updateBuglyUserIdentifier(_ userId: String) {
        #if RTCUBE_LAB || !DEBUG
        Bugly.updateUserIdentifier(userId)
        #endif
    }
}
#endif

extension AppDelegate {
    private func registerAnalytics(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if !DEBUG
        AppAnalytics.start(launchOptions: launchOptions)
        #endif
    }
}

extension AppDelegate {
    private func setupNavigationBarAppearance() {
        let tokens = ThemeStore.shared
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = tokens.colorTokens.bgColorTopBar
        appearance.shadowImage = UIImage()
        appearance.shadowColor = nil
        appearance.titleTextAttributes = [
            .font: tokens.typographyTokens.Regular18,
            .foregroundColor: tokens.colorTokens.textColorPrimary,
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension AppDelegate {
    func checkAppUpdateVersion() {
        #if !DEBUG || !RTCUBE_LAB
        checkStoreVersion(appID: APP_STORE_ID)
        #endif
    }

    private func checkStoreVersion(appID: String) {
        let urlStr = "https://itunes.apple.com/cn/lookup?id=" + appID
        guard let url = URL(string: urlStr) else { return }
        let request = URLRequest(url: url)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let appInfo = results.first,
                  let storeVersion = appInfo["version"] as? String else { return }
            AppLogger.App.info(" App Store version: \(storeVersion)")
            if self.isStoreVersionNewer(storeVersion) {
                DispatchQueue.main.async {
                    self.showUpdateAlert(appID: appID)
                }
            }
        }
        task.resume()
    }

    private func isStoreVersionNewer(_ storeVersion: String) -> Bool {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        AppLogger.App.info(" Current version: \(currentVersion)")
        return storeVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    private func showUpdateAlert(appID: String) {
        let title = MainLocalize("Demo.TRTC.Home.prompt")
        let message = MainLocalize("Demo.TRTC.Home.newversionpublic")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let updateAction = UIAlertAction(title: MainLocalize("Demo.TRTC.Home.updatenow"), style: .default) { [weak self] _ in
            self?.openAppStore(appID: appID)
        }
        let laterAction = UIAlertAction(title: MainLocalize("Demo.TRTC.Home.later"), style: .cancel)

        alert.addAction(updateAction)
        alert.addAction(laterAction)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootVC = keyWindow.rootViewController
        {
            rootVC.present(alert, animated: true)
        }
    }

    private func openAppStore(appID: String) {
        guard let url = URL(string: "https://itunes.apple.com/us/app/id\(appID)?ls=1&mt=8") else { return }
        UIApplication.shared.open(url)
    }
}

#if !OPEN_SOURCE
extension AppDelegate: TCMediaXBaseDelegate {
    func onLicenseCheckCallback(_ errcode: Int32, withParam param: [AnyHashable: Any]) {
        if errcode == TCMediaXLicenceCheckErrorCode.TMXLicenseCheckOk.rawValue {
            debugPrint("Tencent Effect license check success.")
        } else {
            debugPrint("Tencent Effect license check failed.")
        }
    }
}
#endif
