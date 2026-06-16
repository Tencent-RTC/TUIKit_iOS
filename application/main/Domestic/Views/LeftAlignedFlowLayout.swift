//
//  LeftAlignedFlowLayout.swift
//  main
//
//  左对齐自定义 FlowLayout — 从旧版 EntranceViewController.swift 底部迁移
//
//  旧版 LeftAlignedCollectionViewFlowLayout 定义在 EntranceViewController.swift 最底部，
//  新版独立成文件。逻辑完全保持不变。
//

import UIKit

/// 左对齐自定义 FlowLayout
///
/// 让 CollectionView 的 Cell 严格左对齐（默认 FlowLayout 会居中分散），
/// 宽度超过 80% 的 Cell（通栏）不做偏移处理。
class LeftAlignedFlowLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }

        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0

        let modifiedAttributes = attributes.map { attribute -> UICollectionViewLayoutAttributes in
            let attributesCopy = attribute.copy() as? UICollectionViewLayoutAttributes ?? attribute

            if attributesCopy.representedElementCategory == .cell {
                // 换行检测：如果当前行 Y 值大于之前的 maxY，说明换了一行
                if attributesCopy.frame.origin.y >= maxY {
                    leftMargin = sectionInset.left
                }

                // 通栏 Cell（宽度超过 80%）不做左对齐偏移
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
