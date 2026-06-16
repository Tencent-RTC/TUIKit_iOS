//
//  AppDelegate.swift
//  RTCube
//
//  壳工程入口 — 负责系统回调转发 + 全局 SDK 初始化
//
//  包含以下模块（按扩展分区）：
//    1. AppLifecycleRegistry 转发（登录/URL 等模块级回调）
//    2. Licence 设置 + 网络监控（直播推流、短视频、美颜）
//    3. 远程推送注册 + DeviceToken
//    4. V2TIM 监听（APNS + 会话未读数）
//    5. 推送通知清理（进前台清除通知）
//    6. Bugly 崩溃上报
//    7. 埋点初始化（壳工程门面 AppAnalytics，内部封装神策 SDK）
//    8. UINavigationBar 全局外观
//    9. App Store 版本检测
//   10. KaraokeConfig / MusicCatalogService（预留）
//
//  已移至各自模块（通过 AppLifecycleRegistry 接入）：
//    - TUICallKit 全局配置 → Call/Service/CallKitLifecycleHandler.swift
//    - TUILoginListener（被踢下线/UserSig过期） → Login/Components/Service/TUILoginListenerHandler.swift
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
    /// 网络状态监控（Licence 联网重设使用）
    private var networkMonitor: NWPathMonitor?

    @objc var window: UIWindow? {
        // 优先：foreground active 的 WindowScene
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

        // ⓪ 将 App 首选语言同步到 TUIGlobalization（兜底）
        syncAppLanguageToTUIGlobalization()

        // ⓪.5 初始化主题（支持 Dark Mode）
        ThemeStore.shared.setMode(.light)

        // ① 模块级生命周期分发
        AppLifecycleRegistry.shared.applicationDidFinishLaunching(application)

        // ② Licence 设置（直播推流 / 短视频 / 美颜）
        setupLicence()
        startNetworkMonitorForLicence()

        // ③ 推送 Handler 注册 + 远程推送注册
        registerPushLifecycleHandler()
        registerRemoteNotifications(with: application)

        // ④ V2TIM 监听（APNS + 会话未读数）
        setupIMListeners()

        // ⑤ Bugly 崩溃上报（仅 Release）
        #if !OPEN_SOURCE
        registerBuglyIfNeeded()
        #endif

        // ⑥ 埋点初始化（仅 Release；门面由 AppAnalytics 统一封装）
        registerAnalytics(with: launchOptions)

        // ⑦ UINavigationBar 全局外观
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
        // 先让模块级 handler 处理（ITLogin SSO 等）
        if AppLifecycleRegistry.shared.handleOpenURL(url, options: options) {
            return true
        }
        // 埋点 SDK 的 URL Scheme 处理（仅 Release；门面由 AppAnalytics 统一封装）
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

// MARK: - #0 App 语言同步到 TUIGlobalization

extension AppDelegate {
    /// 将「系统设置 → App → 当前 App → 首选语言」同步到 TUIGlobalization
    ///
    /// TUIGlobalization 默认跟随 `[NSLocale preferredLanguages]`（系统全局语言），
    /// 无法感知 iOS per-app 语言设置。此方法在启动时读取 Bundle.main.preferredLocalizations
    /// （已包含 per-app 语言偏好），将其映射为 TUIGlobalization 可识别的语言 key 后写入，
    /// 确保所有使用 TUIGlobalization 的模块（Login、Main 等）显示正确的语言。
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

// MARK: - #2 Licence 设置 + 网络监控

extension AppDelegate {
    /// 立即设置 Licence（首次启动，可能无网络）
    ///
    /// 对应旧版：
    ///   - `TXLiveBase.setLicenceURL(LICENSEURL, key: LICENSEURLKEY)`
    ///   - `TXUGCBase.setLicenceURL(LICENSEURL_SHORTVIDEO, key: LICENSEKEY_SHORTVIDEO)`
    ///   - `TCMediaXBase.setLicenceURL(PLAYER_LICENSE_URL, key: PLAYER_LICENSE_KEY)`（旧版位于 VideoLiveViewController）
    ///
    /// Licence 映射关系：
    ///   旧版 LICENSEURL / LICENSEURLKEY         → v2 LIVE_LICENSE_URL / LIVE_LICENSE_KEY（直播推流）
    ///   旧版 LICENSEURL_SHORTVIDEO / LICENSEKEY  → v2 TENCENT_EFFECT_LICENSE_URL / KEY（短视频 + 美颜）
    ///   旧版 PLAYER_LICENSE_URL / KEY            → v2 PLAYER_LICENSE_URL / KEY（播放器，TCMediaXBase 专用）
    private func setupLicence() {
        #if !OPEN_SOURCE
        V2TXLivePremier.setLicence(LIVE_LICENSE_URL, key: LIVE_LICENSE_KEY)
        TXLiveBase.setLicenceURL(LIVE_LICENSE_URL, key: LIVE_LICENSE_KEY)
        TXUGCBase.setLicenceURL(TENCENT_EFFECT_LICENSE_URL, key: TENCENT_EFFECT_LICENSE_KEY)
        TUIBeautyKit.initialize(licenseUrl: TENCENT_EFFECT_LICENSE_URL,
                                licenseKey: TENCENT_EFFECT_LICENSE_KEY,
                                beautyLevel: .S1_07)
        TCMediaXBase.getInstance().setDelegate(self)
        TCMediaXBase.getInstance().setLicenceURL(PLAYER_LICENSE_URL, key: PLAYER_LICENSE_KEY)
        #endif
    }

    /// 启动网络监控：联网后重新设置 Licence（覆盖首次无网络的场景）
    ///
    /// 对应旧版 NWPathMonitor 回调中的 V2TXLivePremier.setLicence + TELicenseCheck.setTELicense
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

// MARK: - #3 远程推送注册

extension AppDelegate {
    /// 注册 PushLifecycleHandler 并注入推送证书 ID
    ///
    /// 必须在 `registerRemoteNotifications` 之前调用，
    /// 确保 deviceToken 回调到达时 handler 已注册。
    private func registerPushLifecycleHandler() {
        PushLifecycleHandler.shared.businessID = PUSH_BUSINESS_ID
        AppLifecycleRegistry.shared.register(PushLifecycleHandler.shared)
    }

    /// 注册远程推送权限 + 获取 DeviceToken
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
        // 将 deviceToken 分发给 PushLifecycleHandler 等已注册的 handler
        AppLifecycleRegistry.shared.applicationDidRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        AppLogger.App.info(" didFailToRegisterForRemoteNotificationsWithError: \(error)")
    }
}

// MARK: - #4 V2TIM 监听（APNS + 会话未读数）

extension AppDelegate: V2TIMConversationListener, V2TIMAPNSListener {
    /// 注册 V2TIM 的 APNS 监听和会话未读数监听
    private func setupIMListeners() {
        V2TIMManager.sharedInstance().setAPNSListener(apnsListener: self)
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
    }

    // MARK: V2TIMConversationListener

    func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        // 占位预留，如需在首页显示未读红点可在此处实现
    }

    // MARK: V2TIMAPNSListener

    /// 有意返回 0，不在 App 角标显示 IM 未读数
    ///
    /// 如果不处理，APP 未读数默认为所有会话未读数之和。
    func onSetAPPUnreadCount() -> UInt32 {
        return 0
    }
}

// MARK: - #5 推送通知清理（由 SceneDelegate 转发调用）

extension AppDelegate {
    /// 清除所有已投递和待投递的推送通知
    ///
    /// 在 Scene 架构中，由 SceneDelegate.sceneWillEnterForeground 调用此方法
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - #6 Bugly 崩溃上报

#if !OPEN_SOURCE
extension AppDelegate {
    /// 注册 Bugly
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

    /// 登录成功后更新 Bugly 用户标识
    func updateBuglyUserIdentifier(_ userId: String) {
        #if RTCUBE_LAB || !DEBUG
        Bugly.updateUserIdentifier(userId)
        #endif
    }
}
#endif

// MARK: - #7 埋点初始化

extension AppDelegate {
    private func registerAnalytics(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if !DEBUG
        AppAnalytics.start(launchOptions: launchOptions)
        #endif
    }
}

// MARK: - #8 UINavigationBar 全局外观

extension AppDelegate {
    /// 设置全局 NavigationBar 外观（Token 颜色、无阴影、18pt 字体）
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

// MARK: - #9 App Store 版本检测

extension AppDelegate {
    /// 检测 App Store 是否有新版本
    func checkAppUpdateVersion() {
        #if !DEBUG && !RTCUBE_LAB
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
        let title = MainLocalize("main_home_prompt")
        let message = MainLocalize("main_home_new_version_public")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let updateAction = UIAlertAction(title: MainLocalize("main_home_update_now"), style: .default) { [weak self] _ in
            self?.openAppStore(appID: appID)
        }
        let laterAction = UIAlertAction(title: MainLocalize("main_home_later"), style: .cancel)

        alert.addAction(updateAction)
        alert.addAction(laterAction)

        // Scene 架构下获取当前 keyWindow
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
