//
//  UIFont+Extension.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/3/11.
//

import UIKit
import AtomicX

public extension UIFont {
    static func customFont(ofSize fontSize: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return ThemeStore.shared.typographyTokens.font(size: fontSize, weight: weight)
    }
}
