import UIKit
import SnapKit
import AtomicXCore

final class MessageActionMenuController: NSObject {
    static let shared = MessageActionMenuController()

    private enum Metric {
        static let menuCornerRadius = CGFloat(RadiusScheme.smallRadius)
        static let arrowWidth: CGFloat = 14
        static let arrowHeight: CGFloat = 8

        static let columns = 5
        static let pageRows = 2

        static let cellWidth: CGFloat = 52
        static let cellHeight: CGFloat = 68

        static let auxiliaryCellWidth: CGFloat = 50
        static let auxiliaryCellHeight: CGFloat = 58

        static let pagePadding = CGFloat(SpacingScheme.iconTextSpacing)

        static let rowDividerHeight: CGFloat = 1
        static let rowDividerSideMargin = CGFloat(SpacingScheme.smallSpacing)
        static let screenPadding = CGFloat(SpacingScheme.smallSpacing)
        static let bubbleSpacing = CGFloat(SpacingScheme.iconTextSpacing)
        static let minEdgeSpacing = CGFloat(SpacingScheme.smallSpacing)

        static let indicatorDotSize: CGFloat = 6
        static let indicatorDotSpacing = CGFloat(SpacingScheme.iconTextSpacing)
        static let indicatorVerticalPadding = CGFloat(SpacingScheme.smallSpacing)
        static let indicatorInactiveAlpha: CGFloat = 64.0 / 255.0

        static var indicatorAreaHeight: CGFloat {
            return indicatorDotSize + indicatorVerticalPadding * 2
        }

        static let overlayAlpha: CGFloat = 0.001
        static let rowDividerAlpha: CGFloat = 140.0 / 255.0
        static let switchAnimationDuration: TimeInterval = 0.22
        static let menuAppearDuration: TimeInterval = 0.2
        static let menuAppearScale: CGFloat = 0.95
    }

    private enum MenuStyle {
        case message
        case auxiliary

        var cellWidth: CGFloat {
            switch self {
            case .message: return Metric.cellWidth
            case .auxiliary: return Metric.auxiliaryCellWidth
            }
        }

        var cellHeight: CGFloat {
            switch self {
            case .message: return Metric.cellHeight
            case .auxiliary: return Metric.auxiliaryCellHeight
            }
        }

        var buttonMetrics: MessageActionMenuButtonMetrics {
            switch self {
            case .message: return .standard
            case .auxiliary: return .compact
            }
        }
    }

    private struct MenuContentLayout {
        let view: UIView
        let cardWidth: CGFloat
        let height: CGFloat
    }

    private var overlayView: UIView?

    private weak var menuBubbleView: UIView?

    private weak var activeMenuContent: UIView?

    private weak var activeEmojiPanel: ReactionEmojiPanelView?

    private var isEmojiExpanded = false

    private var menuIsAbove = true

    private var collapsedContentSize: CGSize = .zero

    private var expandedContentSize: CGSize = .zero

    // MARK: - Public

    func show(for message: MessageInfo,
              bubbleFrameInWindow: CGRect,
              config: MessageListConfigProtocol & MessageActionConfigProtocol,
              auxiliaryHiddenIDs: Set<String> = []) {
        var actions = MessageActionMenuProvider.visibleActions(
            for: message,
            config: config,
            auxiliaryHiddenIDs: auxiliaryHiddenIDs
        )
        guard !actions.isEmpty else { return }
        let showReactionEntry = config.isSupportReaction
            && message.status == .sendSuccess
            && !EmojiManager.shared.getPickerEmojis().isEmpty
        if showReactionEntry {
            actions.append(makeReactionEntryAction())
        }
        presentMenu(
            actions: actions,
            message: message,
            anchorFrameInWindow: bubbleFrameInWindow,
            hasReactionEntry: showReactionEntry,
            style: .message
        )
    }

    func showAuxiliaryMenu(actions: [MessageActionMenuAction],
                           message: MessageInfo,
                           anchorFrameInWindow: CGRect) {
        presentMenu(
            actions: actions,
            message: message,
            anchorFrameInWindow: anchorFrameInWindow,
            hasReactionEntry: false,
            style: .auxiliary
        )
    }

    private func presentMenu(actions: [MessageActionMenuAction],
                             message: MessageInfo,
                             anchorFrameInWindow: CGRect,
                             hasReactionEntry: Bool,
                             style: MenuStyle) {
        guard let window = Self.keyWindow(), !actions.isEmpty else { return }
        dismiss()

        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(Metric.overlayAlpha)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap))
        tap.delegate = self
        overlay.addGestureRecognizer(tap)
        window.addSubview(overlay)
        overlayView = overlay

        let menuView = buildMenuView(
            actions: actions,
            message: message,
            hasReactionEntry: hasReactionEntry,
            style: style
        )
        overlay.addSubview(menuView)
        menuBubbleView = menuView
        layoutMenu(menuView, around: anchorFrameInWindow, in: overlay)
        animateIn(menuView)
    }

    func dismiss() {
        overlayView?.removeFromSuperview()
        overlayView = nil
        menuBubbleView = nil
        activeMenuContent = nil
        activeEmojiPanel = nil
        isEmojiExpanded = false
    }

    // MARK: - Helpers

    private override init() {
        super.init()
    }

    private func makeReactionEntryAction() -> MessageActionMenuAction {
        var action = MessageActionMenuAction(
            ID: MessageActionIDs.reaction,
            iconName: "message_reaction",
            systemIconFallback: "face.smiling",
            label: LocalizedChatString("Reaction")
        ) { _, _ in }
        action.isReactionEntry = true
        return action
    }

    private func buildMenuView(actions: [MessageActionMenuAction],
                               message: MessageInfo,
                               hasReactionEntry: Bool,
                               style: MenuStyle) -> MessageActionMenuBubbleView {
        let bubble = MessageActionMenuBubbleView()
        let menuContent = buildMenuContent(
            actions: actions,
            message: message,
            forceFullColumns: hasReactionEntry,
            style: style
        )
        activeMenuContent = menuContent.view

        let switchArea = UIStackView()
        switchArea.axis = .vertical
        switchArea.spacing = 0
        switchArea.alignment = .center
        switchArea.addArrangedSubview(menuContent.view)

        collapsedContentSize = CGSize(width: menuContent.cardWidth, height: menuContent.height)
        expandedContentSize = collapsedContentSize

        if hasReactionEntry {
            let panel = ReactionEmojiPanelView(message: message)
            panel.isHidden = true
            panel.onCollapse = { [weak self] in self?.toggleEmojiPanel() }
            panel.onMore = { [weak self] in
                self?.dismiss()
                ReactionEmojiPickerViewController.present(message: message)
            }
            panel.onToggleEmoji = { [weak self] emoji in
                guard let self = self, let name = emoji.name else { return }
                self.dismiss()
                let hasReacted = message.reactionList.contains { $0.reactionID == name && $0.reactedByMyself }
                if !hasReacted {
                    EmojiManager.shared.addRecentEmoji(emoji, groupID: EmojiManager.shared.reactionGroupID())
                }
                NotificationCenter.default.post(
                    name: NSNotification.Name("messageReactionToggle"),
                    object: nil,
                    userInfo: ["message": message, "reactionID": name]
                )
            }
            switchArea.addArrangedSubview(panel)
            activeEmojiPanel = panel
            expandedContentSize = CGSize(width: menuContent.cardWidth, height: ReactionEmojiPanelView.panelHeight)
        }

        bubble.setContent(switchArea)
        return bubble
    }

    private func buildMenuContent(actions: [MessageActionMenuAction],
                                  message: MessageInfo,
                                  forceFullColumns: Bool,
                                  style: MenuStyle) -> MenuContentLayout {
        let pageSize = Metric.columns * Metric.pageRows
        let pages = actions.chunked(into: pageSize)
        if pages.count <= 1 {
            let items = pages.first ?? []
            let columnCount = forceFullColumns ? Metric.columns : max(1, min(items.count, Metric.columns))
            let cardWidth = style.cellWidth * CGFloat(columnCount) + Metric.pagePadding * 2
            let pageView = buildMenuPage(items: items, columnCount: columnCount, message: message, style: style)
            let height = menuPageHeight(rowCount: max(1, (items.count + columnCount - 1) / columnCount), style: style)
            pageView.frame = CGRect(x: 0, y: 0, width: cardWidth, height: height)
            return MenuContentLayout(view: pageView, cardWidth: cardWidth, height: height)
        }

        let columnCount = Metric.columns
        let cardWidth = style.cellWidth * CGFloat(columnCount) + Metric.pagePadding * 2
        let pagerHeight = menuPageHeight(rowCount: Metric.pageRows, style: style)
        let pagerView = MessageActionMenuPager(
            pages: pages,
            columnCount: columnCount,
            cardWidth: cardWidth,
            pagerHeight: pagerHeight,
            pageBuilder: { [weak self] items in
                guard let self = self else { return UIView() }
                return self.buildMenuPage(items: items, columnCount: columnCount, message: message, style: style)
            }
        )
        let totalHeight = pagerHeight + Metric.indicatorAreaHeight
        pagerView.frame = CGRect(x: 0, y: 0, width: cardWidth, height: totalHeight)
        return MenuContentLayout(view: pagerView, cardWidth: cardWidth, height: totalHeight)
    }

    private func menuPageHeight(rowCount: Int, style: MenuStyle) -> CGFloat {
        let rows = max(1, rowCount)
        return Metric.pagePadding * 2
            + style.cellHeight * CGFloat(rows)
            + Metric.rowDividerHeight * CGFloat(rows - 1)
    }

    private func buildMenuPage(items: [MessageActionMenuAction],
                               columnCount: Int,
                               message: MessageInfo,
                               style: MenuStyle) -> UIView {
        let rows = items.chunked(into: columnCount)
        let page = UIStackView()
        page.axis = .vertical
        page.spacing = 0
        page.alignment = .leading
        page.layoutMargins = UIEdgeInsets(
            top: Metric.pagePadding,
            left: Metric.pagePadding,
            bottom: Metric.pagePadding,
            right: Metric.pagePadding
        )
        page.isLayoutMarginsRelativeArrangement = true

        let contentWidth = style.cellWidth * CGFloat(columnCount)
        for (rowIndex, rowItems) in rows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 0
            rowStack.alignment = .center
            for action in rowItems {
                rowStack.addArrangedSubview(makeButton(action: action, message: message, style: style))
            }
            for _ in rowItems.count ..< columnCount {
                let spacer = UIView()
                spacer.snp.makeConstraints { make in
                    make.width.equalTo(style.cellWidth)
                    make.height.equalTo(style.cellHeight)
                }
                rowStack.addArrangedSubview(spacer)
            }
            rowStack.snp.makeConstraints { make in
                make.width.equalTo(contentWidth)
            }
            page.addArrangedSubview(rowStack)
            if rowIndex < rows.count - 1 {
                page.addArrangedSubview(makeRowDivider(width: contentWidth))
            }
        }
        return page
    }

    private func makeRowDivider(width: CGFloat) -> UIView {
        let line = UIView()
        line.backgroundColor = ChatUIKitTheme.colors.strokeColorPrimary.withAlphaComponent(Metric.rowDividerAlpha)
        line.snp.makeConstraints { make in
            make.width.equalTo(width - Metric.rowDividerSideMargin * 2)
            make.height.equalTo(Metric.rowDividerHeight)
        }
        return line
    }

    private func toggleEmojiPanel() {
        guard let overlay = overlayView,
              let bubble = menuBubbleView,
              let menuContent = activeMenuContent,
              let panel = activeEmojiPanel else { return }
        isEmojiExpanded.toggle()
        menuContent.isHidden = isEmojiExpanded
        panel.isHidden = !isEmojiExpanded

        overlay.layoutIfNeeded()
        let contentHeight = isEmojiExpanded ? expandedContentSize.height : collapsedContentSize.height
        let targetHeight = contentHeight + Metric.arrowHeight
        var frame = bubble.frame
        if menuIsAbove {
            frame.origin.y = frame.maxY - targetHeight
        }
        frame.size.height = targetHeight

        let safeTop = overlay.safeAreaInsets.top
        let safeBottom = overlay.safeAreaInsets.bottom
        if menuIsAbove {
            frame.origin.y = max(safeTop + Metric.minEdgeSpacing, frame.origin.y)
        } else {
            frame.origin.y = min(frame.origin.y, overlay.bounds.height - safeBottom - Metric.minEdgeSpacing - frame.height)
        }

        UIView.animate(withDuration: Metric.switchAnimationDuration, delay: 0, options: [.curveEaseInOut]) {
            bubble.frame = frame
            bubble.layoutIfNeeded()
        }
    }

    private func makeButton(action: MessageActionMenuAction,
                            message: MessageInfo,
                            style: MenuStyle) -> UIControl {
        let control = MessageActionMenuButton(action: action, metrics: style.buttonMetrics) { [weak self] in
            guard let self = self else { return }
            if action.isReactionEntry {
                self.toggleEmojiPanel()
                return
            }
            self.dismiss()
            action.handler(message, MessageActionStore.create(message: message))
        }
        control.snp.makeConstraints { make in
            make.width.equalTo(style.cellWidth)
            make.height.equalTo(style.cellHeight)
        }
        return control
    }

    private func layoutMenu(_ menuView: MessageActionMenuBubbleView,
                            around bubbleFrame: CGRect,
                            in overlay: UIView) {
        overlay.layoutIfNeeded()
        let menuWidth = collapsedContentSize.width

        let menuHeight = collapsedContentSize.height + Metric.arrowHeight

        let safeTop = overlay.safeAreaInsets.top
        let safeBottom = overlay.safeAreaInsets.bottom
        let overlayWidth = overlay.bounds.width
        let overlayHeight = overlay.bounds.height

        let maxContentHeight = max(menuHeight, expandedContentSize.height + Metric.arrowHeight)
        let spaceAbove = bubbleFrame.minY - safeTop
        let showAbove = spaceAbove >= (maxContentHeight + Metric.bubbleSpacing + Metric.minEdgeSpacing)
        menuIsAbove = showAbove
        menuView.setArrow(showAbove: showAbove)

        let bubbleCenterX = bubbleFrame.midX
        var menuX = bubbleCenterX - menuWidth / 2
        menuX = max(Metric.screenPadding, min(menuX, overlayWidth - Metric.screenPadding - menuWidth))
        let arrowOffsetX = bubbleCenterX - (menuX + menuWidth / 2)
        menuView.setArrowOffset(arrowOffsetX)

        let menuY: CGFloat
        if showAbove {
            menuY = max(safeTop + Metric.minEdgeSpacing,
                        bubbleFrame.minY - Metric.bubbleSpacing - menuHeight)
        } else {
            let below = bubbleFrame.maxY + Metric.bubbleSpacing
            menuY = min(below, overlayHeight - safeBottom - Metric.minEdgeSpacing - menuHeight)
        }

        menuView.frame = CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)
    }

    private func animateIn(_ menuView: UIView) {
        menuView.alpha = 0
        menuView.transform = CGAffineTransform(scaleX: Metric.menuAppearScale, y: Metric.menuAppearScale)
        UIView.animate(withDuration: Metric.menuAppearDuration, delay: 0, options: [.curveEaseOut]) {
            menuView.alpha = 1
            menuView.transform = .identity
        }
    }

    @objc private func handleOverlayTap() {
        dismiss()
    }

    private static func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MessageActionMenuController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let menu = menuBubbleView else { return true }
        let point = touch.location(in: menu)
        return !menu.bounds.contains(point)
    }
}

// MARK: - 分页菜单容器（横向翻页 + 页码圆点）

private final class MessageActionMenuPager: UIView, UIScrollViewDelegate {
    private static let indicatorDotSize: CGFloat = 6

    private static let indicatorDotSpacing = CGFloat(SpacingScheme.iconTextSpacing)

    private static let indicatorVerticalPadding = CGFloat(SpacingScheme.smallSpacing)

    private static let indicatorInactiveAlpha: CGFloat = 64.0 / 255.0

    private let scrollView = UIScrollView()

    private let pagesStack = UIStackView()

    private let indicatorStack = UIStackView()

    private var indicatorDots: [UIView] = []

    private var pageCount = 0

    private var hasAppliedInitialPage = false

    init(pages: [[MessageActionMenuAction]],
         columnCount: Int,
         cardWidth: CGFloat,
         pagerHeight: CGFloat,
         pageBuilder: ([MessageActionMenuAction]) -> UIView) {
        pageCount = pages.count
        super.init(frame: .zero)

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        pagesStack.axis = .horizontal
        pagesStack.spacing = 0

        addSubview(scrollView)
        scrollView.addSubview(pagesStack)
        for pageItems in pages {
            let pageView = pageBuilder(pageItems)
            pagesStack.addArrangedSubview(pageView)
            pageView.snp.makeConstraints { make in
                make.width.equalTo(cardWidth)
                make.height.equalTo(pagerHeight)
            }
        }
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(pagerHeight)
        }
        pagesStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }

        indicatorStack.axis = .horizontal
        indicatorStack.spacing = Self.indicatorDotSpacing
        indicatorStack.alignment = .center
        addSubview(indicatorStack)
        indicatorStack.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom)
                .offset(Self.indicatorVerticalPadding)
            make.centerX.equalToSuperview()
            make.height.equalTo(Self.indicatorDotSize)
        }
        buildIndicatorDots()
        updateIndicator(currentPage: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasAppliedInitialPage, bounds.width > 0 else { return }
        hasAppliedInitialPage = true
        guard effectiveUserInterfaceLayoutDirection == .rightToLeft else { return }
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        scrollView.setContentOffset(CGPoint(x: maxOffsetX, y: 0), animated: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let rawPage = Int((scrollView.contentOffset.x / scrollView.bounds.width).rounded())
        let page = effectiveUserInterfaceLayoutDirection == .rightToLeft ? pageCount - 1 - rawPage : rawPage
        updateIndicator(currentPage: page)
    }

    private func buildIndicatorDots() {
        for _ in 0 ..< pageCount {
            let dot = UIView()
            dot.layer.cornerRadius = Self.indicatorDotSize / 2
            dot.snp.makeConstraints { make in
                make.width.height.equalTo(Self.indicatorDotSize)
            }
            indicatorStack.addArrangedSubview(dot)
            indicatorDots.append(dot)
        }
    }

    private func updateIndicator(currentPage: Int) {
        let activeColor = ChatUIKitTheme.colors.textColorPrimary
        for (index, dot) in indicatorDots.enumerated() {
            dot.backgroundColor = activeColor.withAlphaComponent(
                index == currentPage ? 1.0 : Self.indicatorInactiveAlpha
            )
        }
    }
}

// MARK: - 菜单气泡容器（圆角 + 箭头 + 阴影）

final class MessageActionMenuBubbleView: UIView {
    private let contentContainer = UIView()

    private let shapeLayer = CAShapeLayer()

    private var showAbove = true

    private var arrowOffsetX: CGFloat = 0

    private enum Metric {
        static let cornerRadius: CGFloat = 7
        static let arrowWidth: CGFloat = 12
        static let arrowHeight: CGFloat = 6

        static let contentTopPadding: CGFloat = 0
        static let contentBottomPadding: CGFloat = 0
        static let contentSidePadding: CGFloat = 0

        static let shadowAlpha: CGFloat = 0.2
        static let shadowRadius: CGFloat = 8
        static let shadowOffset = CGSize(width: 0, height: 2)
        static let minBubbleWidth: CGFloat = 60
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = ChatUIKitTheme.colors.dropdownColorDefault.cgColor
        layer.shadowColor = UIColor(white: 0, alpha: Metric.shadowAlpha).cgColor
        layer.shadowRadius = Metric.shadowRadius
        layer.shadowOpacity = 1
        layer.shadowOffset = Metric.shadowOffset
        addSubview(contentContainer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(_ content: UIView) {
        contentContainer.addSubview(content)

        content.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
    }

    func setArrow(showAbove: Bool) {
        self.showAbove = showAbove
        setNeedsLayout()
    }

    func setArrowOffset(_ offset: CGFloat) {

        let half = bounds.width / 2
        let limit = max(0, half - Metric.cornerRadius - Metric.arrowWidth / 2)
        arrowOffsetX = max(-limit, min(offset, limit))
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let topInset = (showAbove ? 0 : Metric.arrowHeight) + Metric.contentTopPadding
        let bottomInset = (showAbove ? Metric.arrowHeight : 0) + Metric.contentBottomPadding
        contentContainer.frame = CGRect(
            x: Metric.contentSidePadding,
            y: topInset,
            width: bounds.width - Metric.contentSidePadding * 2,
            height: bounds.height - topInset - bottomInset
        )
        shapeLayer.path = bubblePath().cgPath
        layer.shadowPath = shapeLayer.path
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let contentSize = contentContainer.subviews.first?
            .systemLayoutSizeFitting(UIView.layoutFittingCompressedSize) ?? .zero
        let width = contentSize.width + Metric.contentSidePadding * 2
        let height = contentSize.height + Metric.contentTopPadding + Metric.contentBottomPadding + Metric.arrowHeight
        return CGSize(width: max(width, Metric.minBubbleWidth), height: height)
    }

    private func bubblePath() -> UIBezierPath {
        let rect = bounds
        let radius = Metric.cornerRadius
        let arrowWidth = Metric.arrowWidth
        let arrowHeight = Metric.arrowHeight
        let centerX = rect.width / 2 + arrowOffsetX
        let path = UIBezierPath()

        if showAbove {
            let bodyBottom = rect.maxY - arrowHeight
            let bodyRect = CGRect(x: 0, y: 0, width: rect.width, height: bodyBottom)
            path.append(UIBezierPath(roundedRect: bodyRect, cornerRadius: radius))
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: centerX - arrowWidth / 2, y: bodyBottom))
            arrow.addLine(to: CGPoint(x: centerX, y: rect.maxY))
            arrow.addLine(to: CGPoint(x: centerX + arrowWidth / 2, y: bodyBottom))
            arrow.close()
            path.append(arrow)
        } else {
            let bodyRect = CGRect(x: 0, y: arrowHeight, width: rect.width, height: rect.height - arrowHeight)
            path.append(UIBezierPath(roundedRect: bodyRect, cornerRadius: radius))
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: centerX - arrowWidth / 2, y: arrowHeight))
            arrow.addLine(to: CGPoint(x: centerX, y: rect.minY))
            arrow.addLine(to: CGPoint(x: centerX + arrowWidth / 2, y: arrowHeight))
            arrow.close()
            path.append(arrow)
        }
        return path
    }
}

// MARK: - 单个动作按钮（图标 + 文案）

struct MessageActionMenuButtonMetrics {
    let iconSize: CGFloat
    let iconTopMargin: CGFloat
    let iconTitleSpacing: CGFloat
    let titleBottomMargin: CGFloat

    static let standard = MessageActionMenuButtonMetrics(
        iconSize: 20,
        iconTopMargin: CGFloat(SpacingScheme.bubbleSpacing),
        iconTitleSpacing: CGFloat(SpacingScheme.iconTextSpacing),
        titleBottomMargin: CGFloat(SpacingScheme.smallSpacing)
    )

    static let compact = MessageActionMenuButtonMetrics(
        iconSize: 20,
        iconTopMargin: CGFloat(SpacingScheme.smallSpacing),
        iconTitleSpacing: CGFloat(SpacingScheme.iconTextSpacing),
        titleBottomMargin: CGFloat(SpacingScheme.smallSpacing)
    )
}

final class MessageActionMenuButton: UIControl {
    private static let titleMaxLines = 2

    private let iconView = UIImageView()

    private let titleLabel = UILabel()

    private let tapHandler: () -> Void

    init(action: MessageActionMenuAction, metrics: MessageActionMenuButtonMetrics, tapHandler: @escaping () -> Void) {
        self.tapHandler = tapHandler
        super.init(frame: .zero)
        buildUI(action: action, metrics: metrics)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(action: MessageActionMenuAction, metrics: MessageActionMenuButtonMetrics) {
        let colors = ChatUIKitTheme.colors
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = colors.textColorPrimary
        iconView.image = Self.icon(named: action.iconName, fallback: action.systemIconFallback)
        titleLabel.font = FontScheme.caption3Regular
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = Self.titleMaxLines
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = action.label

        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(metrics.iconTopMargin)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(metrics.iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(metrics.iconTitleSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview().offset(-metrics.titleBottomMargin)
        }
    }

    private static func icon(named name: String, fallback: String) -> UIImage? {
        if !name.isEmpty,
           let image = AtomicXChatResources.image(named: name) {
            return image.withRenderingMode(.alwaysTemplate)
        }
        return UIImage(systemName: fallback)
    }

    @objc private func handleTap() {
        tapHandler()
    }
}

// MARK: - 数组分块工具

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
