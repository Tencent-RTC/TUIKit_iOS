//
//  EntranceFooterView.swift
//  main
//
//  CollectionView 底部说明文字 — 从旧版 EntranceViewController.swift 内部类迁移
//
//  旧版 EntranceFooterView 定义在 EntranceViewController.swift 文件内部（第 25-52 行），
//  新版独立成文件。UI 布局完全保持不变。
//

import UIKit
import AtomicX

/// CollectionView 底部说明文字视图
///
/// 在 CollectionView 的 Section Footer 中展示试用提示文案。
class EntranceFooterView: UICollectionReusableView {

    let footerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(footerLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        footerLabel.frame = CGRect(
            x: 16,
            y: 0,
            width: bounds.width - 32,
            height: bounds.height
        )
    }
}
