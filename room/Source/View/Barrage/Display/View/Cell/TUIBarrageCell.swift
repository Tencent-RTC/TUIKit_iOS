//
// TUIBarrageCell.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/3/19.
//

import AtomicX
import SnapKit
import UIKit
import AtomicXCore

private let cellMargin: CGFloat = 6.scale375Height()
private let barrageContentMaxWidth: CGFloat = 240.scale375Width()

class BarrageCell: UITableViewCell {
    static let identifier: String = "BarrageCell"
    private var contentCell: UIView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(_ barrage: Barrage, ownerId: String, adminIdList: [String] = []) {
        if let cell = contentCell {
            cell.safeRemoveFromSuperview()
        }
        let cell = BarrageDefaultCell(barrage: barrage, ownerId: ownerId, adminIdList: adminIdList)
        contentView.addSubview(cell)
        contentCell = cell
        cell.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setContent(_ view: UIView) {
        if let cell = contentCell {
            cell.safeRemoveFromSuperview()
        }
        let cell = BarrageCustomCell(customView: view)
        contentView.addSubview(cell)
        contentCell = cell
        cell.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

class BarrageDefaultCell: UIView {
    private let barrage: Barrage
    private let ownerId: String
    private let adminIdList: [String]
    
    private var isOwner: Bool {
        barrage.sender.userID == ownerId
    }
    
    private var isAdmin: Bool {
        adminIdList.contains(barrage.sender.userID)
    }

    private lazy var ownerTagImage: UIImage = {
        createRoleTagImage(title: .ownerText, backgroundColor: UIColor("4086FF"))
    }()
    
    private lazy var adminTagImage: UIImage = {
        createRoleTagImage(title: .adminText, backgroundColor: UIColor("E37F32"))
    }()
    
    private func createRoleTagImage(title: String, backgroundColor: UIColor) -> UIImage {
        let button = UIButton()
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 7
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 8, weight: .semibold)
        button.clipsToBounds = true

        button.frame = CGRect(x: 0, y: 0, width: 42, height: 14)

        let renderer = UIGraphicsImageRenderer(size: button.bounds.size)
        return renderer.image { _ in
            button.layer.render(in: UIGraphicsGetCurrentContext()!)
        }
    }

    private lazy var barrageLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .semibold)
        label.numberOfLines = 0
        label.textColor = .white
        return label
    }()

    private lazy var backgroundView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black.withAlphaComponent(0.25)
        view.layer.cornerRadius = 13
        view.clipsToBounds = true
        return view
    }()

    init(barrage: Barrage, ownerId: String, adminIdList: [String] = []) {
        self.barrage = barrage
        self.ownerId = ownerId
        self.adminIdList = adminIdList
        super.init(frame: .zero)
        backgroundColor = .clear
        barrageLabel.attributedText = getBarrageLabelAttributedText(barrage: barrage)
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func constructViewHierarchy() {
        addSubview(backgroundView)
        backgroundView.addSubview(barrageLabel)
    }

    func activateConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.equalToSuperview().offset(cellMargin)
        }

        barrageLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview().inset(4)
            make.width.lessThanOrEqualTo(barrageContentMaxWidth)
        }
    }

    func getBarrageLabelAttributedText(barrage: Barrage) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        let isRTL = isRTLLanguage()

        if isOwner {
            let attachment = NSTextAttachment()
            attachment.image = ownerTagImage
            let font = RoomFonts.pingFangSCFont(size: 12, weight: .semibold)
            let imageHeight: CGFloat = 14
            let imageWidth: CGFloat = 42
            let yOffset = (font.capHeight - imageHeight) / 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: imageWidth, height: imageHeight)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " "))
        } else if isAdmin {
            let attachment = NSTextAttachment()
            attachment.image = adminTagImage
            let font = RoomFonts.pingFangSCFont(size: 12, weight: .semibold)
            let imageHeight: CGFloat = 14
            let imageWidth: CGFloat = 42
            let yOffset = (font.capHeight - imageHeight) / 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: imageWidth, height: imageHeight)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " "))
        }

        let userName = barrage.sender.userName
        let displayName = userName.isEmpty ? barrage.sender.userID : userName
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: RoomColors.b1d,
            .font: RoomFonts.pingFangSCFont(size: 12, weight: .semibold)
        ]
        result.append(NSAttributedString(string: FSI + displayName + PDI + "：", attributes: userNameAttributes))

        let contentAttr = getBarrageContentAttributedText(content: barrage.textContent)
        let wrappedContent = NSMutableAttributedString(string: FSI)
        wrappedContent.append(contentAttr)
        wrappedContent.append(NSAttributedString(string: PDI))
        result.append(wrappedContent)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        paragraphStyle.alignment = isRTL ? .right : .left
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func getBarrageContentAttributedText(content: String) -> NSMutableAttributedString {
        return EmotionHelper.shared.obtainImagesAttributedString(byText: content,
                                                                 font: RoomFonts.pingFangSCFont(size: 12, weight: .semibold))
    }
}

class BarrageCustomCell: UIView {
    private var customView: UIView
    init(customView: UIView) {
        self.customView = customView
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }

    func constructViewHierarchy() {
        addSubview(customView)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let height = customView.bounds.height
        layer.cornerRadius = height < 40 ? height * 0.5 : 13
    }

    func activateConstraints() {
        customView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(cellMargin)
            make.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }
}

private extension String {
    static let ownerText = "roomkit_role_owner".localized
    static let adminText = "roomkit_role_admin".localized
}
