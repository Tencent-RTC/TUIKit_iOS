//
//  InvitationBubbleView.swift
//  login
//

import UIKit
import AtomicX

class InvitationBubbleView: UIView {
    
    var cornerRadius: CGFloat = 6
    var triangleWidth: CGFloat = 10
    var triangleHeight: CGFloat = 6
    var triangleOffset: CGFloat?
    
    lazy var label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = ThemeStore.shared.typographyTokens.Medium14
        label.textColor = ThemeStore.shared.colorTokens.textColorButton
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        self.backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        let bubbleRect = CGRect(
            x: 0,
            y: 0,
            width: rect.width,
            height: rect.height - triangleHeight
        )
        
        let triangleX: CGFloat
        if let offset = triangleOffset {
            triangleX = offset
        } else {
            triangleX = (rect.width - triangleWidth) / 2
        }
        let triangleY = rect.height - triangleHeight
        
        let path = UIBezierPath(
            roundedRect: bubbleRect,
            cornerRadius: cornerRadius
        )
        
        path.move(to: CGPoint(x: triangleX, y: triangleY))
        path.addLine(to: CGPoint(x: triangleX + triangleWidth / 2, y: rect.height))
        path.addLine(to: CGPoint(x: triangleX + triangleWidth, y: triangleY))
        path.close()
        
        ThemeStore.shared.colorTokens.textColorPrimary.setFill()
        path.fill()
    }
    
    private func constructViewHierarchy() {
        addSubview(label)
    }
    
    private func activateConstraints() {
        label.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(8)
            make.top.equalToSuperview().inset(4)
            make.bottom.equalToSuperview().inset(triangleHeight + 4)
        }
    }
}
