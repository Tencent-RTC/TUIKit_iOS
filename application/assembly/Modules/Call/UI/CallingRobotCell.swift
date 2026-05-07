//
//  CallingRobotCell.swift
//  main
//

import UIKit
import AtomicX

class CallingRobotCell: UITableViewCell {
    static let reuseId = "CallingRobotCell"
    var clickedDialBotHandler: (_ avatarImage: UIImage, _ callType: CallBotType) -> Void = { _, _ in }

    var callType: CallBotType = .initCall
    private let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private let topIntervalLineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        return view
    }()

    private let botIntervalLineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Medium16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.textAlignment = .left
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let buttonIconImage: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let buttonTitleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textColor = UIColor("1C66E5")
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let dialButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.borderColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius16
        button.layer.masksToBounds = true
        return button
    }()

    private let dialButtonContentView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

extension CallingRobotCell {
    public func config(_ model: CallingRobotModel) {
        avatarImageView.image = AppAssemblyBundle.image(named: model.imageName)
        titleLabel.text = model.title
        buttonIconImage.image = AppAssemblyBundle.image(named: model.buttonIconImage)
        botIntervalLineView.isHidden = !model.hasBotBorder
        topIntervalLineView.isHidden = !model.hasTopBorder
        self.callType = model.callType
        if model.callType == .initCall {
            buttonTitleLabel.text = CallingLocalize("Demo.TRTC.Calling.robotInitCalling")
        } else {
            buttonTitleLabel.text = CallingLocalize("Demo.TRTC.Calling.robotHostCalling")
        }
    }
}

extension CallingRobotCell {
    private func constructViewHierarchy() {
        contentView.addSubview(containerView)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(dialButton)
        containerView.addSubview(topIntervalLineView)
        containerView.addSubview(botIntervalLineView)
        containerView.insertSubview(dialButtonContentView, belowSubview: dialButton)
        dialButtonContentView.addSubview(buttonIconImage)
        dialButtonContentView.addSubview(buttonTitleLabel)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        topIntervalLineView.snp.makeConstraints { make in
            make.top.right.left.equalToSuperview()
            make.height.equalTo(1)
        }
        botIntervalLineView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
            make.height.equalTo(1)
        }
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8)
            make.centerY.equalToSuperview()
        }
        dialButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
            make.width.equalTo(100)
        }
        dialButtonContentView.snp.makeConstraints { make in
            make.center.equalTo(dialButton)
            make.height.equalTo(20)
            make.width.equalTo(76)
        }
        buttonIconImage.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        buttonTitleLabel.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    func bindInteraction() {
        dialButton.addTarget(self, action: #selector(dialToRobotClicked), for: .touchUpInside)
    }
}

extension CallingRobotCell {
    @objc func dialToRobotClicked() {
        self.clickedDialBotHandler(self.avatarImageView.image ?? UIImage(), self.callType)
    }
}
