//
//  TUIGiftSideslipLayout.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/1/2.
//

import UIKit

class GiftCollectionViewLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        return true
    }
}

class TUIGiftSideslipLayout: GiftCollectionViewLayout {
    var rows: Int = 2
    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var beginDiff: CGFloat = 0
    private var midDiff: CGFloat = 0
    private var cellRowCount: Int = 4
    private var maxLeft: CGFloat = 0

    override func prepare() {
        guard let collectionView = collectionView else { return }
        
        if scrollDirection == .vertical {
            prepareVerticalLayout(collectionView: collectionView)
        } else {
            prepareHorizontalLayout(collectionView: collectionView)
        }
    }
    
    private func prepareVerticalLayout(collectionView: UICollectionView) {
        layoutAttributes = []
        let itemCount = collectionView.numberOfItems(inSection: 0)
        
        let collectionViewWidth = collectionView.frame.width
        let horizontalPadding: CGFloat = 16
        let itemSpacing: CGFloat = 8
        let availableWidth = collectionViewWidth - horizontalPadding * 2
        let itemsPerRow = max(1, Int(availableWidth / (itemSize.width + itemSpacing)))
        let actualItemWidth = (availableWidth - CGFloat(itemsPerRow - 1) * itemSpacing) / CGFloat(itemsPerRow)
        
        for i in 0 ..< itemCount {
            let indexPath = IndexPath(item: i, section: 0)
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            
            let row = i / itemsPerRow
            let column = i % itemsPerRow
            
            let x = horizontalPadding + CGFloat(column) * (actualItemWidth + itemSpacing)
            let y = CGFloat(row) * (itemSize.height + itemSpacing)
            
            attribute.frame = CGRect(x: x, y: y, width: actualItemWidth, height: itemSize.height)
            layoutAttributes.append(attribute)
        }
    }
    
    private func prepareHorizontalLayout(collectionView: UICollectionView) {
        maxLeft = 0.0
        cellRowCount = 4
        beginDiff = 24
        midDiff = (collectionView.mm_w - itemSize.width * CGFloat(cellRowCount) - (beginDiff * 2)) / (CGFloat(cellRowCount) - 1.0)

        layoutAttributes = []

        let itemCount = collectionView.numberOfItems(inSection: 0)
        
        for i in 0 ..< itemCount {
            let indexPath = IndexPath(item: i, section: 0)
            let attribute = layoutAttributesForItem(at: indexPath)
            layoutAttributes.append(attribute!)
        }

        let pageCellCount = cellRowCount * rows
        let page = Int(ceil(Double(itemCount) / Double(pageCellCount)))
        maxLeft = CGFloat(page) * (collectionView.mm_w)
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if scrollDirection == .vertical {
            return layoutAttributesForVerticalItem(at: indexPath)
        } else {
            return layoutAttributesForHorizontalItem(at: indexPath)
        }
    }
    
    private func layoutAttributesForVerticalItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < layoutAttributes.count else { return nil }
        return layoutAttributes[indexPath.item]
    }
    
    private func layoutAttributesForHorizontalItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let pageCellCount = cellRowCount * rows
        let page = indexPath.item / pageCellCount
        let index = indexPath.item % pageCellCount
        let indexRow = index / cellRowCount
        let indexColumn = index % cellRowCount

        var x: CGFloat = CGFloat(indexColumn) * (itemSize.width + midDiff) + beginDiff
        x += CGFloat(page) * (collectionView?.mm_w ?? 0)
        let y: CGFloat = CGFloat(indexRow) * itemSize.height

        attribute.frame = CGRect(x: x, y: y, width: itemSize.width, height: itemSize.height)
        return attribute
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributes
    }

    override var collectionViewContentSize: CGSize {
        if scrollDirection == .vertical {
            return verticalContentSize
        } else {
            return horizontalContentSize
        }
    }
    
    private var verticalContentSize: CGSize {
        guard let collectionView = collectionView else { return .zero }
        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else { return collectionView.frame.size }
        
        let collectionViewWidth = collectionView.frame.width
        let horizontalPadding: CGFloat = 16
        let itemSpacing: CGFloat = 8
        let availableWidth = collectionViewWidth - horizontalPadding * 2
        let itemsPerRow = max(1, Int(availableWidth / (itemSize.width + itemSpacing)))
        let rows = Int(ceil(Double(itemCount) / Double(itemsPerRow)))
        
        let totalHeight = CGFloat(rows) * itemSize.height + CGFloat(rows - 1) * itemSpacing
        return CGSize(width: collectionView.frame.width, height: totalHeight)
    }
    
    private var horizontalContentSize: CGSize {
        return CGSize(width: maxLeft, height: collectionView?.mm_h ?? 0)
    }
}
