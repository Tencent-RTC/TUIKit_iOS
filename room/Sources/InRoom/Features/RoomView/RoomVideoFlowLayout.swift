import UIKit

///
///
final class RoomVideoFlowLayout: UICollectionViewLayout {

    static let pageCapacity = 6
    static let gap: CGFloat = 4
    static let inset: CGFloat = 8
    static let itemAspectRatio: CGFloat = 9.0 / 16.0
    static let floatingWidthFraction: CGFloat = 0.24
    static let floatingMaxWidth: CGFloat = 120
    static let floatingInset: CGFloat = 8
    static let cornerRadius: CGFloat = 12

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
        hasScreenShare ? (hasFloatingWindow ? 2 : 1) : 0
    }

    var itemCount: Int {
        leadingItemCount + participantCount
    }

    var pageCount: Int {
        (hasScreenShare ? 1 : 0) + (participantCount + Self.pageCapacity - 1) / Self.pageCapacity
    }

    func isScreenItem(_ item: Int) -> Bool {
        hasScreenShare && item == 0
    }

    func isFloatingItem(_ item: Int) -> Bool {
        hasFloatingWindow && item == 1
    }

    func participantIndex(forItem item: Int) -> Int {
        item - leadingItemCount
    }

    func pageIndex(forItem item: Int) -> Int {
        guard item >= leadingItemCount else { return 0 }
        return (hasScreenShare ? 1 : 0) + participantIndex(forItem: item) / Self.pageCapacity
    }

    // MARK: - UICollectionViewLayout

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
            var rects = [Self.contentBounds(in: pageSize)]
            if hasFloatingWindow {
                rects.append(Self.floatingBounds(in: pageSize, position: floatingPosition))
            }
            pageRects.append(rects)
        }
        let multiplePages = participantCount > Self.pageCapacity
        for start in stride(from: 0, to: participantCount, by: Self.pageCapacity) {
            let count = min(Self.pageCapacity, participantCount - start)
            pageRects.append(Self.participantRects(count: count, multiplePages: multiplePages, in: pageSize))
        }

        var item = 0
        for (pageIndex, rects) in pageRects.enumerated() {
            let pageOriginX = CGFloat(pageIndex) * pageSize.width
            for rect in rects {
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: 0))
                attributes.frame = rect.offsetBy(dx: pageOriginX, dy: 0)
                attributes.zIndex = isFloatingItem(item) ? 1 : 0
                attributesList.append(attributes)
                item += 1
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


extension RoomVideoFlowLayout {

    func handleFloatingPan(of cell: UIView, state: UIGestureRecognizer.State, translation: CGPoint) {
        switch state {
        case .began:
            floatingDragStartFrame = cell.frame
        case .changed:
            let clamped = clampedFloatingTranslation(translation)
            cell.transform = CGAffineTransform(translationX: clamped.x, y: clamped.y)
        case .ended, .cancelled, .failed:
            let clamped = clampedFloatingTranslation(translation)
            cell.transform = .identity
            floatingPosition = settledFloatingPosition(
                for: floatingDragStartFrame.offsetBy(dx: clamped.x, dy: clamped.y)
            )
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


extension RoomVideoFlowLayout {

    private static func contentBounds(in size: CGSize) -> CGRect {
        let edge = min(inset, min(size.width, size.height) / 8)
        return CGRect(origin: .zero, size: size).insetBy(dx: edge, dy: edge)
    }

    static func floatingInset(in size: CGSize) -> CGFloat {
        min(floatingInset, min(size.width, size.height) / 4)
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
        let preferredWidth = min(size.width * floatingWidthFraction, floatingMaxWidth)
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
        let edgeInset = min(inset, maxSpacing)
        let itemGap = min(gap, maxSpacing)
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
