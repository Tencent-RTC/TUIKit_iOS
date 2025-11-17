//
//  AvatarCollectionCell.swift
//  TIMCommon
//
//  Created by AI Assistant on 2025/10/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SDWebImage

class AvatarCollectionCell: UICollectionViewCell {
    
    // MARK: - Properties
    var cardItem: AvatarCardItem? {
        didSet {
            updateCellView()
        }
    }
    
    private lazy var imageView = UIImageView(frame: bounds)
    private var selectedView: UIImageView!
    private lazy var bgView: UIView = UIView(frame: .zero)
    private var descLabel: UILabel!
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCellView()
        selectedView.frame = CGRect(x: imageView.frame.width - 20, y: 4, width: 16, height: 16)
    }
    
    // MARK: - Private Methods
    private func setupViews() {
        setupImageView()
        setupSelectedView()
        setupMaskView()
    }
    
    private func setupImageView() {
        imageView.isUserInteractionEnabled = true
        imageView.layer.cornerRadius = 8.0 // TUIConfig.defaultConfig.avatarCornerRadius
        imageView.layer.borderWidth = 2
        imageView.layer.masksToBounds = true
        contentView.addSubview(imageView)
    }
    
    private func setupSelectedView() {
        selectedView = UIImageView()
        selectedView.image = UIImage(named: "icon_avatar_selected") // TIMCommonImagePath
        selectedView.isHidden = true
        imageView.addSubview(selectedView)
    }
    
    private func setupMaskView() {
        bgView.backgroundColor = UIColor(hex: "cccccc")
        bgView.isHidden = true
        imageView.addSubview(bgView)
        
        descLabel = UILabel()
        descLabel.text = "默认背景" // TIMCommonLocalizableString
        descLabel.textColor = .white
        descLabel.font = UIFont.systemFont(ofSize: 13)
        descLabel.textAlignment = .center
        bgView.addSubview(descLabel)
    }
    
    private func updateCellView() {
        updateSelectedUI()
        updateImageView()
        updateMaskView()
    }
    
    func updateSelectedUI() {
        guard let cardItem = cardItem else { return }
        
        if cardItem.isSelect {
            imageView.layer.borderColor = UIColor.systemBlue.cgColor
            selectedView.isHidden = false
        } else {
            if cardItem.isDefaultBackgroundItem {
                imageView.layer.borderColor = UIColor.gray.withAlphaComponent(0.1).cgColor
            } else {
                imageView.layer.borderColor = UIColor.clear.cgColor
            }
            selectedView.isHidden = true
        }
    }
    
    private func updateImageView() {
        guard let cardItem = cardItem else { return }
        
        if cardItem.isGroupGridAvatar {
            updateNormalGroupGridAvatar()
        } else {
            let placeholder = UIImage(named: "default_c2c_head_img")
            if let urlString = cardItem.posterUrlStr, let url = URL(string: urlString) {
                imageView.sd_setImage(with: url, placeholderImage: placeholder)
            } else {
                imageView.image = placeholder
            }
        }
    }
    
    private func updateMaskView() {
        guard let cardItem = cardItem else { return }
        
        if cardItem.isDefaultBackgroundItem {
            bgView.isHidden = false
            bgView.frame = CGRect(x: 0, y: imageView.frame.height - 28,
                                  width: imageView.frame.width, height: 28)
            descLabel.sizeToFit()
            descLabel.center = CGPoint(x: bgView.bounds.midX, y: bgView.bounds.midY)
        } else {
            bgView.isHidden = true
        }
    }
    
    private func updateNormalGroupGridAvatar() {
        guard let cardItem = cardItem else { return }
        
        if let cacheImage = cardItem.cacheGroupGridAvatarImage {
            imageView.image = cacheImage
        }
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
