//
//  RoomViewFlowLayout.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/12/2.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit

// MARK: - RoomViewFlowLayout
class RoomViewFlowLayout: UICollectionViewFlowLayout {
    
    // MARK: - Properties
    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentSize: CGSize = .zero
    
    // MARK: - Constants
    private struct LayoutConfig {
        static let itemSize: CGSize = CGSize(width: 176, height: 176)
        static let itemSpacing: CGFloat = 8.0
        static let lineSpacing: CGFloat = 8.0
        static let maxColumns: Int = 2
        static let maxRows: Int = 3
        static let maxItemsPerPage: Int = 6
        static let screenSharingPadding: CGFloat = 0
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupDefaults()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDefaults()
    }
    
    private func setupDefaults() {
        scrollDirection = .horizontal
        itemSize = LayoutConfig.itemSize
        minimumInteritemSpacing = LayoutConfig.itemSpacing
        minimumLineSpacing = LayoutConfig.lineSpacing
    }
    
    // MARK: - Layout Override Methods
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        layoutAttributes.removeAll()
        
        let containerWidth = collectionView.bounds.width
        let containerHeight = collectionView.bounds.height
        let numberOfSections = collectionView.numberOfSections
        
        guard numberOfSections > 0 else {
            contentSize = .zero
            return
        }
        
        var currentPageOffsetX: CGFloat = 0
        
        let hasScreenSharing = numberOfSections == 2
        
        if hasScreenSharing {
            let screenSharingAttributes = layoutScreenSharingSection(
                section: 0,
                pageOffsetX: currentPageOffsetX,
                containerWidth: containerWidth,
                containerHeight: containerHeight
            )
            layoutAttributes.append(contentsOf: screenSharingAttributes)
            currentPageOffsetX += containerWidth
            
            let participantCount = collectionView.numberOfItems(inSection: 1)
            if participantCount > 0 {
                let participantAttributes = layoutParticipantsSection(
                    section: 1,
                    itemCount: participantCount,
                    startPageOffsetX: currentPageOffsetX,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
                layoutAttributes.append(contentsOf: participantAttributes)
                
                let participantPages = Int(ceil(Double(participantCount) / Double(LayoutConfig.maxItemsPerPage)))
                currentPageOffsetX += CGFloat(participantPages) * containerWidth
            }
        } else {
            let participantCount = collectionView.numberOfItems(inSection: 0)
            if participantCount > 0 {
                let participantAttributes = layoutParticipantsSection(
                    section: 0,
                    itemCount: participantCount,
                    startPageOffsetX: currentPageOffsetX,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
                layoutAttributes.append(contentsOf: participantAttributes)
                
                let participantPages = Int(ceil(Double(participantCount) / Double(LayoutConfig.maxItemsPerPage)))
                currentPageOffsetX += CGFloat(participantPages) * containerWidth
            }
        }
        
        contentSize = CGSize(width: currentPageOffsetX, height: containerHeight)
    }
    
    private func layoutScreenSharingSection(
        section: Int,
        pageOffsetX: CGFloat,
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        
        let indexPath = IndexPath(item: 0, section: section)
        let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        
        attribute.frame = CGRect(
            x: pageOffsetX + LayoutConfig.screenSharingPadding,
            y: LayoutConfig.screenSharingPadding,
            width: containerWidth - 2 * LayoutConfig.screenSharingPadding,
            height: containerHeight - 2 * LayoutConfig.screenSharingPadding
        )
        
        return [attribute]
    }
    
    private func layoutParticipantsSection(
        section: Int,
        itemCount: Int,
        startPageOffsetX: CGFloat,
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        
        var attributes: [UICollectionViewLayoutAttributes] = []
        
        let numberOfPages = Int(ceil(Double(itemCount) / Double(LayoutConfig.maxItemsPerPage)))
        
        for pageIndex in 0..<numberOfPages {
            let startItemIndex = pageIndex * LayoutConfig.maxItemsPerPage
            let endItemIndex = min(startItemIndex + LayoutConfig.maxItemsPerPage, itemCount)
            let itemsInPage = endItemIndex - startItemIndex
            let pageOffsetX = startPageOffsetX + CGFloat(pageIndex) * containerWidth
            
            let pageAttributes = layoutParticipantsPage(
                section: section,
                itemsInPage: itemsInPage,
                startItemIndex: startItemIndex,
                pageIndex: pageIndex,
                pageOffsetX: pageOffsetX,
                containerWidth: containerWidth,
                containerHeight: containerHeight
            )
            
            attributes.append(contentsOf: pageAttributes)
        }
        
        return attributes
    }
    
    private func layoutParticipantsPage(
        section: Int,
        itemsInPage: Int,
        startItemIndex: Int,
        pageIndex: Int,
        pageOffsetX: CGFloat,
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        
        var attributes: [UICollectionViewLayoutAttributes] = []
        
        let rows = Int(ceil(Double(itemsInPage) / Double(LayoutConfig.maxColumns)))
        let totalGridWidth = CGFloat(LayoutConfig.maxColumns) * LayoutConfig.itemSize.width +
                            CGFloat(LayoutConfig.maxColumns - 1) * LayoutConfig.itemSpacing
        let totalGridHeight = CGFloat(LayoutConfig.maxRows) * LayoutConfig.itemSize.height +
                             CGFloat(LayoutConfig.maxRows - 1) * LayoutConfig.lineSpacing
        
        let standardHorizontalOffset = (containerWidth - totalGridWidth) / 2.0
        let standardVerticalOffset = (containerHeight - totalGridHeight) / 2.0
        
        if pageIndex == 0 && itemsInPage == 1 {
            let indexPath = IndexPath(item: startItemIndex, section: section)
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.frame = CGRect(
                x: pageOffsetX + (containerWidth - LayoutConfig.itemSize.width) / 2.0,
                y: (containerHeight - LayoutConfig.itemSize.height) / 2.0,
                width: LayoutConfig.itemSize.width,
                height: LayoutConfig.itemSize.height
            )
            return [attribute]
        }
        
        let verticalOffset: CGFloat
        if pageIndex == 0 {
            let actualGridHeight = CGFloat(rows) * LayoutConfig.itemSize.height +
                                  CGFloat(max(0, rows - 1)) * LayoutConfig.lineSpacing
            verticalOffset = (containerHeight - actualGridHeight) / 2.0
        } else {
            verticalOffset = standardVerticalOffset
        }
        
        for itemIndexInPage in 0..<itemsInPage {
            let row = itemIndexInPage / LayoutConfig.maxColumns
            let column = itemIndexInPage % LayoutConfig.maxColumns
            
            let x = pageOffsetX + standardHorizontalOffset +
                   CGFloat(column) * (LayoutConfig.itemSize.width + LayoutConfig.itemSpacing)
            let y = verticalOffset +
                   CGFloat(row) * (LayoutConfig.itemSize.height + LayoutConfig.lineSpacing)
            
            let indexPath = IndexPath(item: startItemIndex + itemIndexInPage, section: section)
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.frame = CGRect(x: x, y: y, width: LayoutConfig.itemSize.width, height: LayoutConfig.itemSize.height)
            
            attributes.append(attribute)
        }
        
        return attributes
    }
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributes.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return layoutAttributes.first { $0.indexPath == indexPath }
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.size != collectionView.bounds.size
    }
}
