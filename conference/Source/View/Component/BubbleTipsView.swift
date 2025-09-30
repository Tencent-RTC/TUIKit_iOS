//
//  BubbleTipsView.swift
//  TUIRoomKit
//
//  Created by CY zhao on 2025/4/21.
//

import Foundation
import UIKit

struct BubbleTipsConfig {
    var horizontalPadding: CGFloat = 0.0
    var verticalPadding: CGFloat = 0.0
    var minHorizontalMargin: CGFloat = 0.0
    var font: UIFont = UIFont.systemFont(ofSize: 14)
    var textColor: UIColor = .white
    var backgroundColor: UIColor = .white
    var triangleOffset: CGFloat = 0.5
    var triangleSize: CGSize = CGSize(width: 11, height: 6)
    var triangleImage: UIImage?
    var cornerRadius: CGFloat = 8.0
    
    static var seatTipsConfig: BubbleTipsConfig  {
        var config = BubbleTipsConfig()
        config.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        config.horizontalPadding = 16
        config.verticalPadding = 6
        config.triangleOffset = 0.2
        config.triangleImage = UIImage(named: "room_triangle_blue", in:tuiRoomKitBundle(),compatibleWith: nil)
        config.backgroundColor = UIColor.tui_color(withHex: "1C66E5")
        return config
    }
}

class BubbleTipsView: UIView {
    
    init(tips: String, baseView: UIView, containerView: UIView, verticalSpacing: CGFloat, config: BubbleTipsConfig) {
        super.init(frame: .zero)
        setupUI(tips: tips, baseView: baseView, containerView: containerView, verticalSpacing: verticalSpacing, config: config)
      }
    
    func setupUI(tips: String,baseView: UIView, containerView: UIView, verticalSpacing: CGFloat, config: BubbleTipsConfig) {
        let rect = baseView.superview?.convert(baseView.frame, to: containerView) ?? .zero
        let point = CGPoint(x: rect.midX, y: rect.maxY + verticalSpacing)
        
        let triangle = UIImageView(frame: CGRect(origin: .zero, size: config.triangleSize))
        triangle.image = config.triangleImage
        
        let label = createLabel(config: config, containerWidth: containerView.bounds.width, tips: tips)
        
        let closeButton = UIButton()
        closeButton.setImage(UIImage(named: "room_raiseHand_dismiss", in: tuiRoomKitBundle(), compatibleWith: nil), for: .normal)
        closeButton.frame.size = CGSize(width: 20, height: 20)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        
        let bottomSize = CGSize(width: label.frame.width + closeButton.frame.width + 2 * config.horizontalPadding,
                                height: label.frame.height + 2 * config.verticalPadding)
        
        var triangleOffset = config.triangleOffset
        if triangleOffset < 1 {
            triangleOffset *= bottomSize.width
        }
        
        let maxX = bottomSize.width + (point.x - triangleOffset)
        if maxX > containerView.bounds.maxX - config.minHorizontalMargin {
            triangleOffset += maxX - (containerView.bounds.maxX - config.minHorizontalMargin)
        } else if point.x - triangleOffset < config.minHorizontalMargin {
            triangleOffset -= config.minHorizontalMargin - (point.x - triangleOffset)
        }
        triangle.center.x = triangleOffset
        
        let bubbleView = UIView(frame: CGRect(x: 0,
                                                   y: config.triangleSize.height,
                                                   width: bottomSize.width,
                                                   height: bottomSize.height))
        bubbleView.backgroundColor = config.backgroundColor
        bubbleView.addSubview(label)
        bubbleView.layer.cornerRadius = config.cornerRadius
        bubbleView.clipsToBounds = true
        
        closeButton.frame.origin.x = label.frame.maxX + 5
        closeButton.center.y = label.center.y
        bubbleView.addSubview(closeButton)
        
        var bubbleFrame = CGRect(x: point.x - triangleOffset,
                                 y: point.y,
                                 width: bottomSize.width,
                                 height: bottomSize.height + config.triangleSize.height)
        
        triangle.frame.origin.y = bottomSize.height
        bubbleView.frame.origin.y = 0
        bubbleFrame.origin.y = rect.minY - bubbleFrame.height - verticalSpacing
        
        self.frame = bubbleFrame
        addSubview(triangle)
        addSubview(bubbleView)
}

      required init?(coder: NSCoder) {
          fatalError("init(coder:) has not been implemented")
      }
    
    func createLabel(config: BubbleTipsConfig, containerWidth: CGFloat, tips: String) -> UILabel {
        let maxWidth = containerWidth - 2 * config.minHorizontalMargin
        let label = UILabel(frame: CGRect(x: config.horizontalPadding,
                                          y: config.verticalPadding,
                                          width: maxWidth,
                                          height: 0))
        
        label.font = config.font
        label.textColor = config.textColor
        label.text = tips
        label.numberOfLines = 0
        label.sizeToFit()
        
        return label
    }
    
    @objc private func didTapClose() {
        UIView.animate(withDuration: 0.20, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            EngineManager.shared.changeRaiseHandNoticeState(isShown: false)
        }
    }
    
    @discardableResult
    class func showBubble(_ tips: String, baseView: UIView, containerView: UIView?, verticalSpacing: CGFloat, config: BubbleTipsConfig) -> BubbleTipsView? {
        guard let containerView = containerView else {
            return nil
        }
        let bubble = BubbleTipsView(tips: tips, baseView: baseView, containerView: containerView, verticalSpacing: verticalSpacing, config: config)
        containerView.addSubview(bubble)
        return bubble
      }
}

