//
//  UIView+Extension.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/1/29.
//

import UIKit

extension UITableViewCell {
    public class var cellReuseIdentifier: String {
        return "reuseId_\(self.description())"
    }
}

extension UICollectionViewCell {
    public class var cellReuseIdentifier: String {
        return "reuseId_\(self.description())"
    }
}
