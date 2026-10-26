import AtomicXCore
import TUIChatKit
import Combine
import UIKit

internal final class HomeTabBarController: UITabBarController {
    private static let showCallsTabKey = "show_calls_tab"
    internal static let tabIconSize: CGFloat = 24

//    #if ENABLE_AI_ASSISTANT
//    private static let isAITabVisible = true
//    #else
//    private static let isAITabVisible = false
//    #endif

    internal static let isAITabVisible = true

    internal static var isCallsTabVisible: Bool {
        guard UserDefaults.standard.object(forKey: showCallsTabKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: showCallsTabKey)
    }

    private static var aiTabOffset: Int {
        return isAITabVisible ? 1 : 0
    }

    internal static var chatsTabIndex: Int {
        return aiTabOffset
    }

    internal static var contactsTabIndex: Int {
        return aiTabOffset + (isCallsTabVisible ? 2 : 1)
    }

    internal let conversationListStore = ConversationListStore.create()
    internal var cancellables = Set<AnyCancellable>()
    internal var chatsCoordinator: ChatFlowCoordinator?
    internal var contactsCoordinator: ChatFlowCoordinator?
    internal weak var chatsNavigationController: UINavigationController?
    internal weak var contactsNavigationController: UINavigationController?
    internal var friendApplicationUnreadCount = 0
    internal var groupApplicationUnreadCount = 0
    internal let messageUnreadBadge = TabUnreadBadgeView()
    internal let contactsUnreadBadge = TabUnreadBadgeView()
    internal var isDraggingMessageBadge = false
    internal var isClearingMessageBadge = false

    private var hasRebuiltTabsAfterFirstAppearance = false
    private let initialSelectedIndex: Int

    internal init(initialSelectedIndex: Int = 0) {
        self.initialSelectedIndex = initialSelectedIndex
        super.init(nibName: nil, bundle: nil)
    }

    internal required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal override func viewDidLoad() {
        super.viewDidLoad()
        rebuildTabs()
        updateTabBarAppearance()
        configureUnreadBadges()
        observeMessageUnreadCount()
        observeContactApplicationUnreadCounts()
        observeThemeChanges()
        conversationListStore.loadConversations(option: nil, completion: nil)
        if Self.isAITabVisible {
            RobotConversationActivator.scheduleActivation()
        }
    }

    internal override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTabBarAppearance()
        // 先让底部栏完成布局，再按最终几何定位角标，避免返回时先出现在错误位置再跳过去
        tabBar.layoutIfNeeded()
        updateUnreadBadgePositions()
    }

    internal override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rebuildTabsAfterFirstAppearanceIfNeeded()
            self.updateTabBarAppearance()
            self.tabBar.setNeedsLayout()
        }
    }

    internal override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateUnreadBadgePositions()
    }

    internal func setCallsTabVisible(_ visible: Bool) {
        let previous = Self.isCallsTabVisible
        UserDefaults.standard.set(visible, forKey: Self.showCallsTabKey)
        guard visible != previous else { return }
        let selectedWasSettings = selectedIndex == (viewControllers?.count ?? 1) - 1
        rebuildTabs()
        // tab 数量变化后按钮位置会变，重新走一次真实图标定位
        messageUnreadBadge.hasAnchoredPosition = false
        contactsUnreadBadge.hasAnchoredPosition = false
        updateTabBarAppearance()
        if selectedWasSettings {
            selectedIndex = (viewControllers?.count ?? 1) - 1
        } else {
            selectedIndex = min(selectedIndex, (viewControllers?.count ?? 1) - 1)
        }
    }

    private func rebuildTabsAfterFirstAppearanceIfNeeded() {
        guard !hasRebuiltTabsAfterFirstAppearance else { return }
        hasRebuiltTabsAfterFirstAppearance = true
        rebuildTabs()
        let maxIndex = (viewControllers?.count ?? 1) - 1
        selectedIndex = min(initialSelectedIndex, maxIndex)
    }
}
