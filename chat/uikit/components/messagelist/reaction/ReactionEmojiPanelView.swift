import UIKit
import SnapKit
import AtomicXCore

final class ReactionEmojiPanelView: UIView {
    static let panelWidth: CGFloat = horizontalPadding * 2 + cellSize * CGFloat(columns)

    static let panelHeight: CGFloat = topPadding + headerHeight + headerGap + gridHeight + bottomPadding

    var onCollapse: (() -> Void)?

    var onMore: (() -> Void)?

    var onToggleEmoji: ((EmojiData) -> Void)?

    private static let columns = 6

    private static let rows = 2

    private static let maxQuickEmojiCount = 11

    private static let cellSize: CGFloat = 40

    private static let emojiGlyphInset: CGFloat = 6

    private static let horizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)

    private static let topPadding = CGFloat(SpacingScheme.iconIconSpacing)

    private static let headerHeight: CGFloat = 16

    private static let headerGap = CGFloat(SpacingScheme.smallSpacing)

    private static let bottomPadding = CGFloat(SpacingScheme.smallSpacing)

    private static let collapseIconSize: CGFloat = 16

    private static let rowDividerLineHeight: CGFloat = 1

    private static let rowDividerVerticalMargin = CGFloat(SpacingScheme.iconTextSpacing)

    private static let rowDividerAlpha: CGFloat = 140.0 / 255.0

    private static let moreButtonSize: CGFloat = 28

    private static let moreButtonGlyphInset: CGFloat = 6

    private static var gridHeight: CGFloat {
        return cellSize * CGFloat(rows) + rowDividerLineHeight + rowDividerVerticalMargin * 2
    }

    private let message: MessageInfo

    init(message: MessageInfo) {
        self.message = message
        super.init(frame: .zero)
        constructViewHierarchy()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        let header = buildHeader()
        addSubview(header)
        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.topPadding)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.headerHeight)
        }

        let grid = buildEmojiGrid()
        addSubview(grid)
        grid.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(Self.headerGap)
            make.centerX.equalToSuperview()
            make.width.equalTo(Self.panelWidth)
            make.height.equalTo(Self.gridHeight)
        }

        snp.makeConstraints { make in
            make.width.equalTo(Self.panelWidth)
            make.height.equalTo(Self.panelHeight)
        }
    }

    private func buildHeader() -> UIView {
        let header = UIView()

        let titleLabel = UILabel()
        titleLabel.text = LocalizedChatString("Reaction")
        titleLabel.font = FontScheme.caption3Regular
        titleLabel.textColor = TUIChatKitTheme.colors.textColorPrimary
        header.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }

        let collapseButton = TappableControl { [weak self] in self?.onCollapse?() }
        let collapseIcon = UIImageView()
        collapseIcon.contentMode = .scaleAspectFit
        collapseIcon.tintColor = TUIChatKitTheme.colors.textColorPrimary
        collapseIcon.image = Self.icon(named: "message_reaction_collapse", fallback: "chevron.up")
        collapseButton.addSubview(collapseIcon)
        collapseIcon.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        header.addSubview(collapseButton)
        collapseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.collapseIconSize)
        }
        return header
    }

    private func buildEmojiGrid() -> UIView {
        let container = UIView()
        let quickEmojis = quickEmojiList()
        let lastIndex = Self.columns * Self.rows - 1

        var previousRow: UIStackView?
        for rowIndex in 0 ..< Self.rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 0
            for column in 0 ..< Self.columns {
                let index = rowIndex * Self.columns + column
                let cell: UIView
                if index == lastIndex {
                    cell = buildMoreCell()
                } else if index < quickEmojis.count {
                    cell = buildEmojiCell(quickEmojis[index])
                } else {
                    cell = UIView()
                }
                cell.snp.makeConstraints { make in
                    make.width.height.equalTo(Self.cellSize)
                }
                rowStack.addArrangedSubview(cell)
            }
            container.addSubview(rowStack)
            rowStack.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
                make.height.equalTo(Self.cellSize)
                if let previousRow = previousRow {
                    make.top.equalTo(previousRow.snp.bottom)
                        .offset(Self.rowDividerLineHeight + Self.rowDividerVerticalMargin * 2)
                } else {
                    make.top.equalToSuperview()
                }
            }

            if rowIndex < Self.rows - 1 {
                let divider = UIView()
                divider.backgroundColor = TUIChatKitTheme.colors.strokeColorPrimary
                    .withAlphaComponent(Self.rowDividerAlpha)
                container.addSubview(divider)
                divider.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
                    make.top.equalTo(rowStack.snp.bottom).offset(Self.rowDividerVerticalMargin)
                    make.height.equalTo(Self.rowDividerLineHeight)
                }
            }
            previousRow = rowStack
        }
        return container
    }

    private func buildEmojiCell(_ emoji: EmojiData) -> UIView {
        let control = TappableControl { [weak self] in self?.onToggleEmoji?(emoji) }
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = ReactionEmojiRenderer.image(for: emoji) ?? UIImage(systemName: "face.smiling")
        control.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.emojiGlyphInset)
        }
        return control
    }

    private func buildMoreCell() -> UIView {
        let control = TappableControl { [weak self] in self?.onMore?() }
        let circle = UIView()
        circle.backgroundColor = TUIChatKitTheme.colors.dropdownColorHover
        circle.layer.cornerRadius = Self.moreButtonSize / 2
        circle.layer.masksToBounds = true
        circle.isUserInteractionEnabled = false
        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.tintColor = TUIChatKitTheme.colors.textColorPrimary
        icon.image = Self.icon(named: "message_more", fallback: "ellipsis")
        circle.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Self.moreButtonGlyphInset)
        }
        control.addSubview(circle)
        circle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.moreButtonSize)
        }
        return control
    }

    private func quickEmojiList() -> [EmojiData] {
        let allEmojis = EmojiManager.shared.getPickerEmojis()
        guard !allEmojis.isEmpty else { return [] }
        let emojiByName = Dictionary(uniqueKeysWithValues: allEmojis.compactMap { emoji -> (String, EmojiData)? in
            guard let name = emoji.name else { return nil }
            return (name, emoji)
        })
        var orderedNames: [String] = []
        orderedNames += message.reactionList.filter { $0.reactedByMyself }.map { $0.reactionID }
        let recentGroupID = EmojiManager.shared.reactionGroupID()
        orderedNames += EmojiManager.shared.getRecentEmojis(groupID: recentGroupID)
        orderedNames += allEmojis.compactMap { $0.name }

        var result: [EmojiData] = []
        var usedNames = Set<String>()
        for name in orderedNames {
            guard let emoji = emojiByName[name], usedNames.insert(name).inserted else { continue }
            result.append(emoji)
            if result.count >= Self.maxQuickEmojiCount { break }
        }
        return result
    }

    private static func icon(named name: String, fallback: String) -> UIImage? {
        if let image = AtomicXChatResources.image(named: name) {
            return image.withRenderingMode(.alwaysTemplate)
        }
        return UIImage(systemName: fallback)
    }
}

// MARK: - 轻量可点击容器（闭包回调）

private final class TappableControl: UIControl {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { handler() }
}
