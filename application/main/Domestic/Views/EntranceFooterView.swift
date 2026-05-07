//
//  EntranceFooterView.swift
//  main
//

import UIKit
import AtomicX

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
