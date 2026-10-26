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
        static let preferredItemSize: CGFloat = 176
        static let itemSpacing: CGFloat = 8.0
        static let lineSpacing: CGFloat = 8.0
        static let horizontalPadding: CGFloat = 8.0
        static let maxColumns: Int = 2
        static let maxRows: Int = 3
        static let maxItemsPerPage: Int = 6
        static let screenSharingPadding: CGFloat = 0

        static func calculatedItemSize(for containerWidth: CGFloat) -> CGSize {
            let cols = CGFloat(maxColumns)
            let available = containerWidth - 2 * horizontalPadding - (cols - 1) * itemSpacing
            let width = min(preferredItemSize, floor(available / cols))
            return CGSize(width: max(width, 80), height: max(width, 80))
        }
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
        itemSize = LayoutConfig.calculatedItemSize(for: UIScreen.main.bounds.width)
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
            let screenSharingAttributes = layoutFullScreenSection(
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
            if participantCount == 1 {
                let fullAttributes = layoutFullScreenSection(
                    section: 0,
                    pageOffsetX: currentPageOffsetX,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
                layoutAttributes.append(contentsOf: fullAttributes)
                currentPageOffsetX += containerWidth
            } else if participantCount > 1 {
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
    
    private func layoutFullScreenSection(
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
        let itemSize = LayoutConfig.calculatedItemSize(for: containerWidth)
        
        let firstPageItemCount = min(itemCount, LayoutConfig.maxItemsPerPage)
        let firstPageRows = Int(ceil(Double(firstPageItemCount) / Double(LayoutConfig.maxColumns)))
        let firstPageGridHeight = CGFloat(firstPageRows) * itemSize.height +
                                  CGFloat(max(0, firstPageRows - 1)) * LayoutConfig.lineSpacing
        let topOffset = max(0, (containerHeight - firstPageGridHeight) / 2.0)
        
        for pageIndex in 0..<numberOfPages {
            let startItemIndex = pageIndex * LayoutConfig.maxItemsPerPage
            let endItemIndex = min(startItemIndex + LayoutConfig.maxItemsPerPage, itemCount)
            let itemsInPage = endItemIndex - startItemIndex
            let pageOffsetX = startPageOffsetX + CGFloat(pageIndex) * containerWidth
            
            let pageAttributes = layoutParticipantsPage(
                section: section,
                itemsInPage: itemsInPage,
                startItemIndex: startItemIndex,
                pageOffsetX: pageOffsetX,
                containerWidth: containerWidth,
                topOffset: topOffset
            )
            
            attributes.append(contentsOf: pageAttributes)
        }
        
        return attributes
    }
    
    private func layoutParticipantsPage(
        section: Int,
        itemsInPage: Int,
        startItemIndex: Int,
        pageOffsetX: CGFloat,
        containerWidth: CGFloat,
        topOffset: CGFloat
    ) -> [UICollectionViewLayoutAttributes] {
        
        var attributes: [UICollectionViewLayoutAttributes] = []
        let itemSize = LayoutConfig.calculatedItemSize(for: containerWidth)
        
        let totalGridWidth = CGFloat(LayoutConfig.maxColumns) * itemSize.width +
                            CGFloat(LayoutConfig.maxColumns - 1) * LayoutConfig.itemSpacing
        let standardHorizontalOffset = (containerWidth - totalGridWidth) / 2.0
        
        for itemIndexInPage in 0..<itemsInPage {
            let row = itemIndexInPage / LayoutConfig.maxColumns
            let column = itemIndexInPage % LayoutConfig.maxColumns
            
            let x = pageOffsetX + standardHorizontalOffset +
                   CGFloat(column) * (itemSize.width + LayoutConfig.itemSpacing)
            let y = topOffset +
                   CGFloat(row) * (itemSize.height + LayoutConfig.lineSpacing)
            
            let indexPath = IndexPath(item: startItemIndex + itemIndexInPage, section: section)
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.frame = CGRect(x: x, y: y, width: itemSize.width, height: itemSize.height)
            
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
