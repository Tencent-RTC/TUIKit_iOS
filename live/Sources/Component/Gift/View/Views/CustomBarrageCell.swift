//
//  GiftBarrageCell.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/4/8.
//

import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

public class GiftBarrageCell: UIView {
    
    private static let barrageContentMaxWidth: CGFloat = 240.scale375Width()
    private static let giftIconSize: CGFloat = 14
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.25)
        view.layer.cornerRadius = 13
        view.layer.masksToBounds = true
        return view
    }()
    
    private let barrageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        return label
    }()
    
    private let barrage: Barrage
    
    public init(barrage: Barrage) {
        self.barrage = barrage
        super.init(frame: .zero)
        backgroundColor = .clear
        barrageLabel.attributedText = getBarrageAttributedText(barrage: barrage, giftImage: nil)
        loadGiftIconIfNeeded()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady = false
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
    
    private func loadGiftIconIfNeeded() {
        guard let extensionInfo = barrage.extensionInfo,
              let giftIconUrlString = extensionInfo["gift_icon_url"],
              let giftIconUrl = URL(string: giftIconUrlString) else {
            return
        }
        KingfisherManager.shared.retrieveImage(with: giftIconUrl) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let value):
                self.barrageLabel.attributedText = self.getBarrageAttributedText(barrage: self.barrage, giftImage: value.image)
            case .failure:
                break
            }
        }
    }
    
    private func getBarrageAttributedText(barrage: Barrage, giftImage: UIImage?) -> NSMutableAttributedString {
        let font = UIFont.customFont(ofSize: 12, weight: .semibold)
        let userNameColor = UIColor("80BEF6")
        let result = NSMutableAttributedString()
        
        let userName = barrage.sender.userName ?? ""
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: userNameColor,
            .font: font
        ]
        result.append(NSAttributedString(string: userName, attributes: userNameAttributes))
        
        let sendAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: font
        ]
        result.append(NSAttributedString(string: " " + .sendText + " ", attributes: sendAttributes))
        
        guard let extensionInfo = barrage.extensionInfo,
              let giftName = extensionInfo["gift_name"],
              let receiver = extensionInfo["gift_receiver_username"] else {
            return result
        }
        
        let receiverAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: userNameColor,
            .font: font
        ]
        result.append(NSAttributedString(string: receiver, attributes: receiverAttributes))
        
        let colors: [UIColor] = [.red, .blue, .yellow]
        let random = Int(arc4random_uniform(UInt32(colors.count)))
        let giftNameAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: colors[random],
            .font: font
        ]
        result.append(NSAttributedString(string: " " + giftName, attributes: giftNameAttributes))
        
        if let giftImage = giftImage {
            let attachment = NSTextAttachment()
            attachment.image = giftImage
            let iconSize = Self.giftIconSize
            let yOffset = (font.capHeight - iconSize) / 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: iconSize, height: iconSize)
            result.append(NSAttributedString(string: " "))
            result.append(NSAttributedString(attachment: attachment))
        }
        
        let giftCount = barrage.extensionInfo?["gift_count"] ?? "0"
        let countAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: font
        ]
        result.append(NSAttributedString(string: " x\(giftCount)", attributes: countAttributes))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        result.addAttribute(.paragraphStyle,
                            value: paragraphStyle,
                            range: NSRange(location: 0, length: result.length))
        
        return result
    }
}


// MARK: - Layout
extension GiftBarrageCell {
    private func constructViewHierarchy() {
        addSubview(containerView)
        containerView.addSubview(barrageLabel)
    }
    
    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.width.lessThanOrEqualTo(Self.barrageContentMaxWidth)
        }
        barrageLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview().inset(5)
        }
    }
}

private extension String {
    static let sendText = internalLocalized("common_sent")
}
