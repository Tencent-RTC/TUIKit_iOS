//
//  CallingMenuHeaderView.swift
//  main
//

import UIKit
import AtomicX

class CallingMenuHeaderView: UIView {
    private var contentSources: String = ""
    private let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Medium14
        label.textColor = UIColor("262B32")
        label.textAlignment = .left
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let descTitleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = UIColor("262B32")
        label.textAlignment = .left
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect([.topLeft, .topRight], withCornerRatio: 5)
    }
}

extension CallingMenuHeaderView {
    public func config(_ model: CallingMenuModel) {
        if model.iconImageName.hasPrefix("http") {
            if let imageURL = URL(string: model.iconImageName) {
                iconImageView.kf.setImage(with: .network(imageURL))
            }
        } else {
            iconImageView.image = model.iconImage
        }
        titleLabel.text = model.title
        conficContent(content: model.content, stressItems: model.stressContent)
    }

    private func conficContent(content: String, stressItems: [String]) {
        let font = ThemeStore.shared.typographyTokens.Regular12
        let fontAttr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ThemeStore.shared.colorTokens.textColorSecondary]
        let contentAttrStr = NSMutableAttributedString(string: content, attributes: fontAttr)
        for stressStr in stressItems {
            if let range = content.range(of: stressStr) {
                let newColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
                let newColorAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: newColor]
                let nsRange = NSRange(range, in: contentAttrStr.string)
                contentAttrStr.addAttributes(newColorAttributes, range: nsRange)
            }
        }
        descTitleLabel.attributedText = contentAttrStr
    }
}

extension CallingMenuHeaderView {
    private func constructViewHierarchy() {
        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descTitleLabel)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(20)
            make.width.equalTo(300)
        }
        descTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalTo(titleLabel)
            make.width.equalTo(300)
        }
        iconImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview().offset(10)
        }
    }
}
