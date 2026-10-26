import AtomicXCore
import TUIChatKit
import Combine
import UIKit

extension HomeTabBarController {
    private static let badgeClearDragThreshold: CGFloat = 48
    private static let badgeTapMaxDistance: CGFloat = 20
    private static let badgeVerticalOffset: CGFloat = 4
    private static let tabBarContentTopInset: CGFloat = 8
    private static let tabIconSizeTolerance: CGFloat = 8
    private static let badgePressScale: CGFloat = 1.08
    private static let badgeDragMaxScaleGain: CGFloat = 0.2
    private static let badgeClearEndScale: CGFloat = 0.6
    private static let badgeClearFlyDistanceFactor: CGFloat = 1.5
    private static let badgePressAnimationDuration: TimeInterval = 0.12
    private static let badgeDragAnimationDuration: TimeInterval = 0.18
    private static let maximumDisplayedUnreadCount = 99

    internal func configureUnreadBadges() {
        tabBar.clipsToBounds = false
        messageUnreadBadge.isHidden = true
        tabBar.addSubview(messageUnreadBadge)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMessageBadgePan(_:)))
        pan.delegate = self
        messageUnreadBadge.addGestureRecognizer(pan)
        // 原地轻点时 pan 不会进入 began/ended，必须单独用 tap 手势接住，
        // 否则角标热区会吞掉这次点击，tab 无法切换
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMessageBadgeTap(_:)))
        tap.delegate = self
        messageUnreadBadge.addGestureRecognizer(tap)
        contactsUnreadBadge.isHidden = true
        contactsUnreadBadge.isUserInteractionEnabled = false
        tabBar.addSubview(contactsUnreadBadge)
    }

    internal func observeMessageUnreadCount() {
        conversationListStore.state
            .subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] unreadCount in
                self?.updateMessageUnreadBadge(unreadCount: Int(unreadCount))
            }
            .store(in: &cancellables)
    }

    internal func observeContactApplicationUnreadCounts() {
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

    internal func updateUnreadBadgePositions() {
        if !isDraggingMessageBadge, !isClearingMessageBadge {
            updateMessageBadgePosition()
        }
        updateContactsBadgePosition()
    }

    internal func refreshUnreadBadgesAfterTabLayout() {
        tabBar.setNeedsLayout()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isViewLoaded else { return }
            self.tabBar.layoutIfNeeded()
            self.updateUnreadBadgePositions()
        }
    }

    private func updateMessageUnreadBadge(unreadCount: Int) {
        if unreadCount <= 0 {
            guard !isDraggingMessageBadge else { return }
            UIView.performWithoutAnimation { messageUnreadBadge.clearContent() }
            return
        }
        guard !isDraggingMessageBadge, !isClearingMessageBadge else { return }
        UIView.performWithoutAnimation {
            messageUnreadBadge.setText(Self.unreadBadgeText(unreadCount))
            messageUnreadBadge.transform = .identity
            messageUnreadBadge.alpha = 1
        }
        updateMessageBadgePosition()
    }

    private func updateContactsBadge() {
        let count = friendApplicationUnreadCount + groupApplicationUnreadCount
        contactsNavigationController?.tabBarItem.badgeValue = nil
        guard count > 0 else {
            UIView.performWithoutAnimation { contactsUnreadBadge.clearContent() }
            return
        }
        UIView.performWithoutAnimation {
            contactsUnreadBadge.setText(Self.unreadBadgeText(count))
        }
        updateContactsBadgePosition()
    }

    private static func unreadBadgeText(_ count: Int) -> String {
        return count > maximumDisplayedUnreadCount ? "99+" : "\(count)"
    }

    private func updateMessageBadgePosition() {
        positionBadge(messageUnreadBadge, tabIndex: Self.chatsTabIndex)
    }

    private func updateContactsBadgePosition() {
        positionBadge(contactsUnreadBadge, tabIndex: Self.contactsTabIndex)
    }

    private var isTabBarVisible: Bool {
        guard !tabBar.isHidden, tabBar.alpha > 0, tabBar.window != nil else { return false }
        return view.bounds.intersects(tabBar.convert(tabBar.bounds, to: view))
    }

    private func positionBadge(_ badge: TabUnreadBadgeView, tabIndex: Int) {
        guard badge.hasContent, tabBar.bounds.width > 0, tabBar.bounds.height > 0,
              let items = tabBar.items, items.indices.contains(tabIndex) else {
            badge.isHidden = true
            return
        }
        guard isTabBarVisible else { return }
        let isRTL = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let anchoredFrame = anchoredIconFrame(tabIndex: tabIndex, itemCount: items.count, isRTL: isRTL)
        if anchoredFrame == nil, badge.hasAnchoredPosition { return }
        let anchorFrame = anchoredFrame ?? geometricIconFrame(tabIndex: tabIndex, itemCount: items.count, isRTL: isRTL)
        if anchoredFrame != nil { badge.hasAnchoredPosition = true }
        let badgeCenterX = isRTL ? anchorFrame.minX : anchorFrame.maxX
        let centerY = anchorFrame.minY + Self.badgeVerticalOffset
        let contentSize = badge.contentSize
        let halfWidth = max(contentSize.width / 2, 1)
        let halfHeight = max(contentSize.height / 2, 1)
        let bounds = tabBar.bounds
        let center = CGPoint(
            x: min(max(badgeCenterX, halfWidth), max(bounds.maxX - halfWidth, halfWidth)),
            y: min(max(centerY, halfHeight), max(bounds.maxY - halfHeight, halfHeight))
        )
        UIView.performWithoutAnimation {
            badge.isHidden = false
            tabBar.bringSubviewToFront(badge)
            badge.center = center
        }
    }

    private func anchoredIconFrame(tabIndex: Int, itemCount: Int, isRTL: Bool) -> CGRect? {
        guard tabBar.bounds.width > 0, itemCount > 0 else { return nil }
        // 优先按真实 tab 按钮定位：等分栏宽的假设在悬浮 tab bar 上会整体偏移
        if let button = tabItemButton(tabIndex: tabIndex, itemCount: itemCount, isRTL: isRTL) {
            if let iconFrame = iconFrame(in: button) { return iconFrame }
            let buttonFrame = button.convert(button.bounds, to: tabBar)
            return CGRect(
                x: buttonFrame.midX - Self.tabIconSize / 2,
                y: buttonFrame.minY + Self.tabBarContentTopInset,
                width: Self.tabIconSize,
                height: Self.tabIconSize
            )
        }
        var iconFrames: [CGRect] = []
        appendTabIconFrames(in: tabBar, into: &iconFrames)
        let tabWidth = tabBar.bounds.width / CGFloat(itemCount)
        let segmentMinX = isRTL
            ? tabBar.bounds.width - CGFloat(tabIndex + 1) * tabWidth
            : CGFloat(tabIndex) * tabWidth
        let segment = CGRect(x: segmentMinX, y: 0, width: tabWidth, height: tabBar.bounds.height)
        return iconFrames
            .filter { segment.contains(CGPoint(x: $0.midX, y: $0.midY)) }
            .min { abs($0.midX - segment.midX) < abs($1.midX - segment.midX) }
    }

    private func tabItemButton(tabIndex: Int, itemCount: Int, isRTL: Bool) -> UIView? {
        var buttons: [UIView] = []
        for subview in tabBar.subviews
        where subview is UIControl && !subview.isHidden && subview.alpha > 0
            && subview.bounds.width > 0 && subview.bounds.height > 0 {
            buttons.append(subview)
        }
        guard buttons.count == itemCount else { return nil }
        buttons.sort { isRTL ? $0.frame.minX > $1.frame.minX : $0.frame.minX < $1.frame.minX }
        guard buttons.indices.contains(tabIndex) else { return nil }
        return buttons[tabIndex]
    }

    private func iconFrame(in button: UIView) -> CGRect? {
        var best: (frame: CGRect, area: CGFloat)?
        collectIconFrame(in: button, depth: 0) { candidate in
            let area = candidate.width * candidate.height
            if let current = best, current.area >= area { return }
            best = (candidate, area)
        }
        return best?.frame
    }

    private func collectIconFrame(in view: UIView, depth: Int, handle: (CGRect) -> Void) {
        guard depth < 3 else { return }
        for subview in view.subviews where !subview.isHidden && subview.alpha > 0
            && subview.bounds.width > 0 && subview.bounds.height > 0 {
            if let imageView = subview as? UIImageView, imageView.image != nil {
                handle(imageView.convert(imageView.bounds, to: tabBar))
            }
            collectIconFrame(in: subview, depth: depth + 1, handle: handle)
        }
    }

    private func geometricIconFrame(tabIndex: Int, itemCount: Int, isRTL: Bool) -> CGRect {
        let tabWidth = tabBar.bounds.width / CGFloat(itemCount)
        let itemCenterX = isRTL
            ? tabBar.bounds.width - (CGFloat(tabIndex) + 0.5) * tabWidth
            : (CGFloat(tabIndex) + 0.5) * tabWidth
        return CGRect(
            x: itemCenterX - Self.tabIconSize / 2,
            y: Self.tabBarContentTopInset,
            width: Self.tabIconSize,
            height: Self.tabIconSize
        )
    }

    private func appendTabIconFrames(in view: UIView, into frames: inout [CGRect]) {
        guard !(view is TabUnreadBadgeView), !view.isHidden, view.alpha > 0,
              view.bounds.width > 0, view.bounds.height > 0 else { return }
        for subview in view.subviews {
            guard !(subview is TabUnreadBadgeView), !subview.isHidden, subview.alpha > 0 else { continue }
            if isTabIconView(subview) {
                frames.append(subview.convert(subview.bounds, to: tabBar))
            }
            appendTabIconFrames(in: subview, into: &frames)
        }
    }

    private func isTabIconView(_ view: UIView) -> Bool {
        guard let imageView = view as? UIImageView, imageView.image != nil else { return false }
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return false }
        return abs(size.width - Self.tabIconSize) <= Self.tabIconSizeTolerance
            && abs(size.height - Self.tabIconSize) <= Self.tabIconSizeTolerance
    }

    @objc private func handleMessageBadgeTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        selectedIndex = Self.chatsTabIndex
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
            updateMessageBadgeDrag(translation: gesture.translation(in: tabBar))
        case .ended:
            finishMessageBadgeDrag(translation: gesture.translation(in: tabBar))
        case .cancelled, .failed:
            isDraggingMessageBadge = false
            resetMessageBadgeDrag()
        default:
            break
        }
    }

    private func updateMessageBadgeDrag(translation: CGPoint) {
        let dragUpDistance = max(0, -translation.y)
        let progress = min(dragUpDistance / Self.badgeClearDragThreshold, 1)
        let scale = 1 + progress * Self.badgeDragMaxScaleGain
        messageUnreadBadge.transform = CGAffineTransform(translationX: translation.x, y: -dragUpDistance)
            .scaledBy(x: scale, y: scale)
    }

    private func finishMessageBadgeDrag(translation: CGPoint) {
        isDraggingMessageBadge = false
        if -translation.y >= Self.badgeClearDragThreshold {
            clearAllUnreadByBadgeDrag()
        } else if abs(translation.x) < Self.badgeTapMaxDistance,
                  abs(translation.y) < Self.badgeTapMaxDistance {
            resetMessageBadgeDrag()
            selectedIndex = Self.chatsTabIndex
        } else {
            resetMessageBadgeDrag()
        }
    }

    private func resetMessageBadgeDrag() {
        isClearingMessageBadge = false
        messageUnreadBadge.layer.removeAllAnimations()
        UIView.animate(withDuration: Self.badgeDragAnimationDuration) {
            self.messageUnreadBadge.transform = .identity
            self.messageUnreadBadge.alpha = 1
        }
    }

    private func clearAllUnreadByBadgeDrag() {
        isClearingMessageBadge = true
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
                guard let self else { return }
                switch result {
                case .success:
                    self.messageUnreadBadge.clearContent()
                    self.isClearingMessageBadge = false
                    WindowToastManager.shared.success(LocalizedChatString("ClearAllUnreadSuccess"))
                case .failure:
                    self.messageUnreadBadge.isHidden = false
                    self.resetMessageBadgeDrag()
                }
            }
        }
    }
}

extension HomeTabBarController: UIGestureRecognizerDelegate {
    internal func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

internal final class TabUnreadBadgeView: UIView {
    private static let bubbleHeight: CGFloat = 16
    private static let bubbleMinWidth: CGFloat = 16
    private static let bubbleTextHorizontalPadding: CGFloat = 5
    private static let textFontSize: CGFloat = 10
    private static let touchAreaSize: CGFloat = 44
    private static let touchSlop: CGFloat = 6
    private let bubbleView = UIView()
    private let textLabel = UILabel()

    internal override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: TabUnreadBadgeView.touchAreaSize, height: TabUnreadBadgeView.touchAreaSize))
        bubbleView.backgroundColor = ThemeState.shared.colors.textColorError
        bubbleView.layer.cornerRadius = Self.bubbleHeight / 2
        bubbleView.layer.masksToBounds = true
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: Self.textFontSize, weight: .medium)
        textLabel.textAlignment = .center
        addSubview(bubbleView)
        bubbleView.addSubview(textLabel)
    }

    internal required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0 else { return nil }
        let hotFrame = bubbleView.frame.insetBy(dx: -Self.touchSlop, dy: -Self.touchSlop)
        guard hotFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }

    internal private(set) var hasContent = false
    internal var hasAnchoredPosition = false

    internal var contentSize: CGSize { bubbleView.bounds.size }

    internal func setText(_ text: String) {
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
        hasContent = true
        isHidden = false
    }

    internal func clearContent() {
        hasContent = false
        isHidden = true
    }
}
