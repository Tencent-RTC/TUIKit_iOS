import AtomicXCore
import ChatUIKit
import Combine
import TUICallKit_Swift
import UIKit

final class HomeTabBarController: UITabBarController {
    static var lastSelectedIndex = 0

    private static let showCallsTabKey = "show_calls_tab"

    static var isCallsTabVisible: Bool {
        guard UserDefaults.standard.object(forKey: showCallsTabKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: showCallsTabKey)
    }

    private let conversationListStore = ConversationListStore.create()

    private var cancellables = Set<AnyCancellable>()

    private var chatsCoordinator: ChatFlowCoordinator?

    private var contactsCoordinator: ChatFlowCoordinator?

    private weak var chatsNavigationController: UINavigationController?

    private weak var contactsNavigationController: UINavigationController?

    private var friendApplicationUnreadCount = 0

    private var groupApplicationUnreadCount = 0

    private static let tabTitleFontSize: CGFloat = 10

    private static let tabIconSize: CGFloat = 24

    private static let tabIconGradientStart = CGPoint(x: 0.66, y: -0.33)

    private static let tabIconGradientEnd = CGPoint(x: -0.24, y: 0.6875)

    private static var tabIconBaseNames: [String] {
        if isCallsTabVisible {
            return ["tab_chat", "tab_calls", "tab_contact", "tab_setting"]
        }
        return ["tab_chat", "tab_contact", "tab_setting"]
    }

    private static let badgeClearDragThreshold: CGFloat = 48

    private static let badgeVerticalOffset: CGFloat = 4

    private static let badgePressScale: CGFloat = 1.08

    private static let badgeDragMaxScaleGain: CGFloat = 0.2

    private static let badgeClearEndScale: CGFloat = 0.6

    private static let badgeClearFlyDistanceFactor: CGFloat = 1.5

    private static let badgePressAnimationDuration: TimeInterval = 0.12

    private static let badgeDragAnimationDuration: TimeInterval = 0.18

    private let messageUnreadBadge = TabUnreadBadgeView()

    private var isDraggingMessageBadge = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        updateTabBarAppearance()
        setupMessageBadgeDrag()
        bindUnreadBadge()
        bindContactsBadge()
        bindTheme()
        delegate = self
        selectedIndex = Self.lastSelectedIndex
        conversationListStore.loadConversations(option: nil, completion: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !isDraggingMessageBadge {
            updateMessageBadgePosition()
        }
    }

    private func setupTabs() {
        var tabs: [UIViewController] = [makeChatsTab()]
        if Self.isCallsTabVisible {
            tabs.append(makeCallsTab())
        }
        tabs.append(contentsOf: [makeContactsTab(), makeSettingsTab()])
        viewControllers = tabs
    }

    func setCallsTabVisible(_ visible: Bool) {
        let previous = Self.isCallsTabVisible
        UserDefaults.standard.set(visible, forKey: Self.showCallsTabKey)
        guard visible != previous else { return }
        let selectedWasSettings = selectedIndex == (viewControllers?.count ?? 1) - 1
        setupTabs()
        updateTabBarAppearance()
        if selectedWasSettings {
            selectedIndex = (viewControllers?.count ?? 1) - 1
        } else {
            selectedIndex = min(selectedIndex, (viewControllers?.count ?? 1) - 1)
        }
    }

    private func makeCallsTab() -> UIViewController {
        let callsPage = RecentCallsViewController(recordCallsUIStyle: .minimalist)
        callsPage.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabCalls"),
            image: UIImage(named: "tab_calls"),
            tag: 1
        )
        return callsPage
    }

    private func makeChatsTab() -> UIViewController {
        let coordinator = ChatFlowCoordinator()
        let conversationsPage = ConversationsPage(onConversationClick: { [weak coordinator] info in
            coordinator?.pushChat(info.conversation, locateMessage: info.locateMessage)
        })
        let nav = HiddenBarNavigationController(rootViewController: conversationsPage)
        coordinator.navigationController = nav
        nav.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabChats"),
            image: UIImage(named: "tab_chat"),
            tag: 0
        )
        chatsCoordinator = coordinator
        chatsNavigationController = nav
        return nav
    }

    private func makeContactsTab() -> UIViewController {
        let coordinator = ChatFlowCoordinator()
        let contactsPage = ContactsPage(
            onContactClick: { [weak coordinator] user in
                coordinator?.pushChat(Self.makeC2CConversation(from: user))
            },
            onGroupClick: { [weak coordinator] group in
                coordinator?.pushChat(Self.makeGroupConversation(from: group))
            }
        )
        let nav = HiddenBarNavigationController(rootViewController: contactsPage)
        coordinator.navigationController = nav
        nav.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabContacts"),
            image: UIImage(named: "tab_contact"),
            tag: 1
        )
        contactsCoordinator = coordinator
        contactsNavigationController = nav
        return nav
    }

    private func makeSettingsTab() -> UIViewController {
        let settingsPage = SettingsViewController()
        let navigationController = HiddenBarNavigationController(rootViewController: settingsPage)
        navigationController.tabBarItem = UITabBarItem(
            title: LocalizedChatString("TabSettings"),
            image: UIImage(named: "tab_setting"),
            tag: 2
        )
        return navigationController
    }

    private static func makeGroupConversation(from group: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.userID))
        conversation.type = .group
        conversation.title = group.title ?? group.userID
        conversation.avatarURL = group.avatarURL
        return conversation
    }

    private static func makeC2CConversation(from user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.userID))
        conversation.type = .c2c
        conversation.title = user.title ?? user.userID
        conversation.avatarURL = user.avatarURL
        return conversation
    }

    private func setupMessageBadgeDrag() {
        tabBar.clipsToBounds = false
        messageUnreadBadge.isHidden = true
        tabBar.addSubview(messageUnreadBadge)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMessageBadgePan(_:)))
        messageUnreadBadge.addGestureRecognizer(pan)
    }

    private func bindUnreadBadge() {
        conversationListStore.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] unreadCount in
                self?.updateMessageUnreadBadge(unreadCount: Int(unreadCount))
            }
            .store(in: &cancellables)
    }

    private func updateMessageUnreadBadge(unreadCount: Int) {
        if unreadCount <= 0 {
            if !isDraggingMessageBadge {
                messageUnreadBadge.isHidden = true
            }
            return
        }
        if isDraggingMessageBadge {
            return
        }
        messageUnreadBadge.setText(unreadCount > 99 ? "99+" : "\(unreadCount)")
        messageUnreadBadge.transform = .identity
        messageUnreadBadge.alpha = 1
        if messageUnreadBadge.isHidden {
            messageUnreadBadge.isHidden = false
        }
        updateMessageBadgePosition()
    }

    private func updateMessageBadgePosition() {
        guard !messageUnreadBadge.isHidden else { return }
        let tabButtons = tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("TabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }
        let isRTL = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
        guard let anchor = isRTL ? tabButtons.last : tabButtons.first,
              let iconView = anchor.subviews.first(where: { $0 is UIImageView }) else { return }
        tabBar.bringSubviewToFront(messageUnreadBadge)
        let iconFrame = anchor.convert(iconView.frame, to: tabBar)
        let badgeCenterX = isRTL ? iconFrame.minX : iconFrame.maxX
        messageUnreadBadge.center = CGPoint(x: badgeCenterX, y: iconFrame.minY + Self.badgeVerticalOffset)
    }

    @objc private func handleMessageBadgePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDraggingMessageBadge = true
            messageUnreadBadge.layer.removeAllAnimations()
            UIView.animate(withDuration: Self.badgePressAnimationDuration) {
                self.messageUnreadBadge.transform = CGAffineTransform(scaleX: Self.badgePressScale, y: Self.badgePressScale)
            }
        case .changed:
            let translation = gesture.translation(in: tabBar)
            let dragUpDistance = max(0, -translation.y)
            let progress = min(dragUpDistance / Self.badgeClearDragThreshold, 1)
            let scale = 1 + progress * Self.badgeDragMaxScaleGain
            messageUnreadBadge.transform = CGAffineTransform(translationX: translation.x, y: -dragUpDistance)
                .scaledBy(x: scale, y: scale)
        case .ended:
            let translation = gesture.translation(in: tabBar)
            isDraggingMessageBadge = false
            if -translation.y >= Self.badgeClearDragThreshold {
                clearAllUnreadByBadgeDrag()
            } else {
                resetMessageBadgeDrag()
            }
        case .cancelled, .failed:
            isDraggingMessageBadge = false
            resetMessageBadgeDrag()
        default:
            break
        }
    }

    private func resetMessageBadgeDrag() {
        messageUnreadBadge.layer.removeAllAnimations()
        UIView.animate(withDuration: Self.badgeDragAnimationDuration) {
            self.messageUnreadBadge.transform = .identity
            self.messageUnreadBadge.alpha = 1
        }
    }

    private func clearAllUnreadByBadgeDrag() {
        let flyDistance = Self.badgeClearDragThreshold * Self.badgeClearFlyDistanceFactor
        UIView.animate(withDuration: Self.badgeDragAnimationDuration, animations: {
            self.messageUnreadBadge.transform = CGAffineTransform(translationX: 0, y: -flyDistance)
                .scaledBy(x: Self.badgeClearEndScale, y: Self.badgeClearEndScale)
            self.messageUnreadBadge.alpha = 0
        }) { _ in
            self.messageUnreadBadge.isHidden = true
            self.messageUnreadBadge.transform = .identity
            self.messageUnreadBadge.alpha = 1
        }
        conversationListStore.clearConversationUnreadCount(conversationID: "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.success(LocalizedChatString("ClearAllUnreadSuccess"))
                case .failure:
                    self?.resetMessageBadgeDrag()
                }
            }
        }
    }

    private func bindContactsBadge() {
        ContactStore.shared.loadFriendApplications(completion: nil)
        GroupStore.shared.loadApplications(completion: nil)
        ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendApplicationUnreadCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.friendApplicationUnreadCount = count
                self?.updateContactsBadge()
            }
            .store(in: &cancellables)
        GroupStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \GroupState.unreadApplicationCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.groupApplicationUnreadCount = count
                self?.updateContactsBadge()
            }
            .store(in: &cancellables)
    }

    private func updateContactsBadge() {
        let count = friendApplicationUnreadCount + groupApplicationUnreadCount
        contactsNavigationController?.tabBarItem.badgeValue = count > 0 ? "\(count)" : nil
    }

    private func bindTheme() {
        ThemeState.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTabBarAppearance()
            }
            .store(in: &cancellables)
    }

    private func updateTabBarAppearance() {
        let themeColors = ThemeState.shared.colors
        let tertiaryColor = themeColors.textColorTertiary
        let linkColor = themeColors.textColorLink
        let titleFont = UIFont.systemFont(ofSize: Self.tabTitleFontSize)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = themeColors.bgColorTopBar
        appearance.shadowColor = .clear
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: tertiaryColor, .font: titleFont]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: linkColor, .font: titleFont]
        tabBar.isTranslucent = false
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = linkColor
        renderTabIcons()
        if messageUnreadBadge.superview === tabBar {
            tabBar.bringSubviewToFront(messageUnreadBadge)
        }
    }

    private func renderTabIcons() {
        for (index, viewController) in (viewControllers ?? []).enumerated() {
            guard index < Self.tabIconBaseNames.count else { continue }
            let cutoutName = index == 0 ? "tab_chat_lines" : nil
            viewController.tabBarItem.image = renderTabIcon(baseName: Self.tabIconBaseNames[index], cutoutName: cutoutName, selected: false)
            viewController.tabBarItem.selectedImage = renderTabIcon(baseName: Self.tabIconBaseNames[index], cutoutName: cutoutName, selected: true)
        }
    }

    private func renderTabIcon(baseName: String, cutoutName: String?, selected: Bool) -> UIImage? {
        guard let base = UIImage(named: baseName)?.cgImage else { return nil }
        let size = CGSize(width: Self.tabIconSize, height: Self.tabIconSize)
        let colors = ThemeState.shared.colors
        let fill: UIImage
        if selected {
            fill = gradientFillImage(
                size: size,
                colors: [colors.bgColorBubbleOwn.cgColor, colors.textColorLink.cgColor]
            )
        } else {
            fill = solidFillImage(size: size, color: colors.textColorTertiary)
        }
        var image = maskedImage(fill: fill, mask: base, size: size)
        if let cutoutName = cutoutName, let cutout = UIImage(named: cutoutName)?.cgImage {
            let cutoutFill = solidFillImage(size: size, color: colors.bgColorBottomBar)
            let cutoutImage = maskedImage(fill: cutoutFill, mask: cutout, size: size)
            image = compositeImage(bottom: image, top: cutoutImage, size: size)
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    private func solidFillImage(size: CGSize, color: UIColor) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func gradientFillImage(size: CGSize, colors: [CGColor]) -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(origin: .zero, size: size)
        gradientLayer.colors = colors
        gradientLayer.startPoint = Self.tabIconGradientStart
        gradientLayer.endPoint = Self.tabIconGradientEnd
        return UIGraphicsImageRenderer(size: size).image { context in
            gradientLayer.render(in: context.cgContext)
        }
    }

    private func maskedImage(fill: UIImage, mask: CGImage, size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            let rect = CGRect(origin: .zero, size: size)
            cgContext.clip(to: rect, mask: mask)
            if let fillImage = fill.cgImage {
                cgContext.draw(fillImage, in: rect)
            }
        }
    }

    private func compositeImage(bottom: UIImage, top: UIImage, size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            bottom.draw(in: CGRect(origin: .zero, size: size))
            top.draw(in: CGRect(origin: .zero, size: size))
        }
    }

}

extension HomeTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        Self.lastSelectedIndex = selectedIndex
    }
}

final class HiddenBarNavigationController: UINavigationController, UIGestureRecognizerDelegate, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
        delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarHidden(!(viewController is SystemNavigationBarPage), animated: animated)
    }
}

private final class TabUnreadBadgeView: UIView {
    private static let bubbleHeight: CGFloat = 16

    private static let bubbleMinWidth: CGFloat = 16

    private static let bubbleTextHorizontalPadding: CGFloat = 5

    private static let textFontSize: CGFloat = 10

    private static let touchAreaSize: CGFloat = 44

    private static let touchSlop: CGFloat = 6

    private let bubbleView = UIView()

    private let textLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.touchAreaSize, height: Self.touchAreaSize))
        bubbleView.backgroundColor = ThemeState.shared.colors.textColorError
        bubbleView.layer.cornerRadius = Self.bubbleHeight / 2
        bubbleView.layer.masksToBounds = true
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: Self.textFontSize, weight: .medium)
        textLabel.textAlignment = .center
        addSubview(bubbleView)
        bubbleView.addSubview(textLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0 else { return nil }
        let hotFrame = bubbleView.frame.insetBy(dx: -Self.touchSlop, dy: -Self.touchSlop)
        guard hotFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }

    func setText(_ text: String) {
        textLabel.text = text
        textLabel.sizeToFit()
        let bubbleWidth = max(Self.bubbleMinWidth, textLabel.bounds.width + Self.bubbleTextHorizontalPadding * 2)
        bubbleView.frame = CGRect(
            x: (bounds.width - bubbleWidth) / 2,
            y: (bounds.height - Self.bubbleHeight) / 2,
            width: bubbleWidth,
            height: Self.bubbleHeight
        )
        textLabel.frame = bubbleView.bounds
    }
}

private final class HomeConversationInfoHandler: GetConversationInfoCompletionHandler {
    private let onSuccessBlock: (ConversationInfo) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping (ConversationInfo) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(conversationInfo: ConversationInfo) {
        onSuccessBlock(conversationInfo)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
