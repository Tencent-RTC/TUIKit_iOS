//
//  LeftAlignedFlowLayout.swift
//  main
//

import UIKit

class LeftAlignedFlowLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }

        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0

        let modifiedAttributes = attributes.map { attribute -> UICollectionViewLayoutAttributes in
            let attributesCopy = attribute.copy() as? UICollectionViewLayoutAttributes ?? attribute

            if attributesCopy.representedElementCategory == .cell {
                if attributesCopy.frame.origin.y >= maxY {
                    leftMargin = sectionInset.left
                }

                let isFullWidthCell = attributesCopy.frame.width > (self.collectionView?.bounds.width ?? 0) * 0.8

                if !isFullWidthCell {
                    attributesCopy.frame.origin.x = leftMargin
                    leftMargin += attributesCopy.frame.width + minimumInteritemSpacing
                }

                maxY = max(attributesCopy.frame.maxY, maxY)
            }

            return attributesCopy
        }

        return modifiedAttributes
    }
}
