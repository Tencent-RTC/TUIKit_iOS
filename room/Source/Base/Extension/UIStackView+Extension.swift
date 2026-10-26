//
//  UIStackView+Extension.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit

extension UIStackView {
    /// Convenience: add multiple arranged subviews at once.
    func addArrangedSubviews(_ views: UIView...) {
        views.forEach { addArrangedSubview($0) }
    }
}
