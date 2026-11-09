import UIKit

final class RoomParticipantLayout: UICollectionViewLayout {

    static let pageCapacity = 6
    static let itemAspectRatio: CGFloat = 9.0 / 16.0

    enum FloatingSide {
        case left
        case right
    }

    struct FloatingWindowPosition: Equatable {
        var side: FloatingSide = .right
        var verticalFraction: CGFloat = 0
    }

    var floatingPosition = FloatingWindowPosition() {
        didSet {
            guard floatingPosition != oldValue else { return }
            invalidateLayout()
        }
    }

    private(set) var participantCount = 0
    private(set) var hasScreenShare = false
    private(set) var hasFloatingWindow = false

    private var attributesList: [UICollectionViewLayoutAttributes] = []
    private var pageSize = CGSize.zero
    private var floatingDragStartFrame = CGRect.zero

    func update(participantCount: Int, hasScreenShare: Bool, hasFloatingWindow: Bool) {
        let floating = hasScreenShare && hasFloatingWindow
        guard self.participantCount != participantCount
                || self.hasScreenShare != hasScreenShare
                || self.hasFloatingWindow != floating else { return }
        self.participantCount = participantCount
        self.hasScreenShare = hasScreenShare
        self.hasFloatingWindow = floating
        invalidateLayout()
    }

    private var leadingItemCount: Int {
        hasScreenShare ? 1 : 0
    }

    var itemCount: Int {
        leadingItemCount + participantCount
    }

    func itemCount(inSection section: Int) -> Int {
        section == 0 ? leadingItemCount : participantCount
    }

    var pageCount: Int {
        (hasScreenShare ? 1 : 0) + (participantCount + Self.pageCapacity - 1) / Self.pageCapacity
    }

    func participantIndex(forItem item: Int) -> Int {
        item
    }

    func pageIndex(for indexPath: IndexPath) -> Int {
        guard indexPath.section != 0 else { return 0 }
        return (hasScreenShare ? 1 : 0) + indexPath.item / Self.pageCapacity
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: pageSize.width * CGFloat(pageCount), height: pageSize.height)
    }

    override func prepare() {
        super.prepare()
        attributesList = []
        guard let collectionView else { return }
        pageSize = collectionView.bounds.size
        guard pageSize.width > 0, pageSize.height > 0 else { return }

        var pageRects: [[CGRect]] = []
        if hasScreenShare {
            pageRects.append([Self.contentBounds(in: pageSize)])
        }
        let multiplePages = participantCount > Self.pageCapacity
        for start in stride(from: 0, to: participantCount, by: Self.pageCapacity) {
            let count = min(Self.pageCapacity, participantCount - start)
            pageRects.append(Self.participantRects(count: count, multiplePages: multiplePages, in: pageSize))
        }

        if hasScreenShare {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
            attributes.frame = Self.contentBounds(in: pageSize)
            attributesList.append(attributes)
        }

        let screenPageCount = hasScreenShare ? 1 : 0
        for (pageOffset, rects) in pageRects.dropFirst(screenPageCount).enumerated() {
            let pageOriginX = CGFloat(pageOffset + screenPageCount) * pageSize.width
            let itemBase = pageOffset * Self.pageCapacity
            for (offset, rect) in rects.enumerated() {
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: itemBase + offset, section: 1))
                attributes.frame = rect.offsetBy(dx: pageOriginX, dy: 0)
                attributesList.append(attributes)
            }
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        attributesList.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesList.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.size != pageSize
    }
}

extension RoomParticipantLayout {

    func floatingFrame() -> CGRect {
        guard hasFloatingWindow, pageSize.width > 0, pageSize.height > 0 else { return .zero }
        return Self.floatingBounds(in: pageSize, position: floatingPosition)
    }

    func handleFloatingPan(of view: UIView, state: UIGestureRecognizer.State, translation: CGPoint) {
        switch state {
        case .began:
            floatingDragStartFrame = view.frame
        case .changed:
            let clamped = clampedFloatingTranslation(translation)
            view.frame = floatingDragStartFrame.offsetBy(dx: clamped.x, dy: clamped.y)
        case .ended, .cancelled, .failed:
            let clamped = clampedFloatingTranslation(translation)
            let finalFrame = floatingDragStartFrame.offsetBy(dx: clamped.x, dy: clamped.y)
            view.frame = finalFrame
            floatingPosition = settledFloatingPosition(for: finalFrame)
        default:
            break
        }
    }

    private func clampedFloatingTranslation(_ translation: CGPoint) -> CGPoint {
        guard pageSize.width > 0 else { return .zero }
        let local = localFrame(of: floatingDragStartFrame)
        let inset = Self.floatingInset(in: pageSize)
        let maxLeft = max(pageSize.width - local.width - inset, inset)
        let maxTop = max(pageSize.height - local.height - inset, inset)
        let left = min(max(local.minX + translation.x, inset), maxLeft)
        let top = min(max(local.minY + translation.y, inset), maxTop)
        return CGPoint(x: left - local.minX, y: top - local.minY)
    }

    private func settledFloatingPosition(for frame: CGRect) -> FloatingWindowPosition {
        let local = localFrame(of: frame)
        let inset = Self.floatingInset(in: pageSize)
        let maxTop = max(pageSize.height - local.height - inset, inset)
        let clampedTop = min(max(local.minY, inset), maxTop)
        let fraction = maxTop > inset ? (clampedTop - inset) / (maxTop - inset) : 0
        let side: FloatingSide = local.midX < pageSize.width / 2 ? .left : .right
        return FloatingWindowPosition(side: side, verticalFraction: fraction)
    }

    private func localFrame(of frame: CGRect) -> CGRect {
        let pageIndex = pageSize.width > 0 ? floor(frame.midX / pageSize.width) : 0
        return frame.offsetBy(dx: -pageIndex * pageSize.width, dy: 0)
    }
}

extension RoomParticipantLayout {

    private static func contentBounds(in size: CGSize) -> CGRect {
        let edge = min(8, min(size.width, size.height) / 8)
        return CGRect(origin: .zero, size: size).insetBy(dx: edge, dy: edge)
    }

    static func floatingInset(in size: CGSize) -> CGFloat {
        min(8, min(size.width, size.height) / 4)
    }

    private static func participantRects(count: Int, multiplePages: Bool, in size: CGSize) -> [CGRect] {
        if multiplePages {
            return Array(gridRects(count: pageCapacity, columns: 3, rows: 2, in: size).prefix(count))
        }
        switch count {
        case 1: return [contentBounds(in: size)]
        case 2: return gridRects(count: 2, columns: 2, rows: 1, in: size)
        case 3, 4: return gridRects(count: count, columns: 2, rows: 2, in: size)
        default: return gridRects(count: count, columns: 3, rows: 2, in: size)
        }
    }

    private static func floatingBounds(in size: CGSize, position: FloatingWindowPosition) -> CGRect {
        let inset = floatingInset(in: size)
        let preferredWidth = min(size.width * 0.24, 120)
        let widthFittingHeight = (size.height - inset * 2) * itemAspectRatio
        let itemWidth = min(preferredWidth, widthFittingHeight)
        let itemHeight = itemWidth / itemAspectRatio
        let minTop = inset
        let maxTop = size.height - inset - itemHeight
        let top = maxTop <= minTop
            ? minTop
            : minTop + (maxTop - minTop) * min(max(position.verticalFraction, 0), 1)
        let x = position.side == .left ? inset : size.width - inset - itemWidth
        return CGRect(x: x, y: top, width: itemWidth, height: itemHeight)
    }

    private static func gridRects(count: Int, columns: Int, rows: Int, in size: CGSize) -> [CGRect] {
        let maxSpacing = min(size.width, size.height) / 8
        let edgeInset = min(8, maxSpacing)
        let itemGap = min(4, maxSpacing)
        let widthPerColumn = (size.width - edgeInset * 2 - itemGap * CGFloat(columns - 1)) / CGFloat(columns)
        let heightPerRow = (size.height - edgeInset * 2 - itemGap * CGFloat(rows - 1)) / CGFloat(rows)
        let itemWidth = max(min(widthPerColumn, heightPerRow * itemAspectRatio), 0)
        let itemHeight = itemWidth / itemAspectRatio
        let gridTop = (size.height - itemHeight * CGFloat(rows) - itemGap * CGFloat(rows - 1)) / 2

        return (0..<count).map { index in
            let rowIndex = index / columns
            let columnIndex = index % columns
            let itemsInRow = min(columns, count - rowIndex * columns)
            let rowWidth = itemWidth * CGFloat(itemsInRow) + itemGap * CGFloat(itemsInRow - 1)
            let rowLeft = (size.width - rowWidth) / 2
            return CGRect(
                x: rowLeft + CGFloat(columnIndex) * (itemWidth + itemGap),
                y: gridTop + CGFloat(rowIndex) * (itemHeight + itemGap),
                width: itemWidth,
                height: itemHeight
            )
        }
    }
}
