//
//  GuideTableViewCell.swift
//  main
//

import UIKit
import AtomicX

class GuideTableViewCell: UITableViewCell {
    static let reuseId = "GuideTableViewCell"

    let avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        imageView.image = AppAssemblyBundle.image(named: "calling_guide_friendAvatar")
        return imageView
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular12
        return label
    }()

    let contextTextLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.font = ThemeStore.shared.typographyTokens.Regular14
        return label
    }()

    let leftContextImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let rightContextImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let contextContainer: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        return view
    }()

    let copyButtonContent: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()

    let copyButtonContentBorder: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return view
    }()

    let copyButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(GuideLocalize("Demo.TRTC.calling.detailGuidCopyURL"), for: .normal)
        button.setTitleColor(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault, for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium14
        return button
    }()

    var copyAction: () -> Void = {}

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        contextContainer.roundedRect(.allCorners, withCornerRatio: 10)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

extension GuideTableViewCell {
    private func constructViewHierarchy() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(contextContainer)
        contentView.addSubview(nameLabel)
        contextContainer.addSubview(contextTextLabel)
        contextContainer.addSubview(leftContextImageView)
        contextContainer.addSubview(rightContextImageView)
        contextContainer.addSubview(copyButtonContent)
        copyButtonContent.addSubview(copyButtonContentBorder)
        copyButtonContent.addSubview(copyButton)
    }

    private func activateConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.top.equalTo(contextContainer)
            make.left.equalToSuperview()
            make.height.width.equalTo(34.scale375Width())
        }
        contextContainer.snp.makeConstraints { make in
            make.width.equalTo(301.scale375Width())
            make.left.equalToSuperview()
            make.top.equalTo(contextTextLabel).offset(-12.scale375Height())
            make.bottom.equalTo(leftContextImageView).offset(12)
        }
        contextTextLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12.scale375())
        }
        leftContextImageView.snp.makeConstraints { make in
            make.top.equalTo(contextTextLabel.snp.bottom).offset(10.scale375Height())
            make.trailing.leading.equalToSuperview().inset(12.scale375Width())
            make.bottom.equalToSuperview().offset(-12.scale375Height())
        }

        copyButtonContent.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(44.scale375Height())
        }
        copyButtonContentBorder.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(1.scale375Height())
            make.left.equalTo(12.scale375Width())
            make.centerX.equalToSuperview()
        }
        copyButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bindInteraction() {
        copyButton.addTarget(self, action: #selector(copyUrlClicked), for: .touchUpInside)
    }
}

extension GuideTableViewCell {
    func config(model: GuideModel) {
        let avartarType = model.avartarType
        contextTextLabel.text = model.text
        nameLabel.text = model.name
        nameLabel.layoutSubviews()
        avatarImageView.image = AppAssemblyBundle.image(named: model.avatarImageName)
        leftContextImageView.image = AppAssemblyBundle.image(named: model.leftContextImageName)
        copyButtonContent.isHidden = !model.hasCopyButton
        contextTextLabel.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12.scale375())
            if model.hasCopyButton {
                make.bottom.equalTo(copyButtonContent.snp.top).offset(-16.scale375Height())
            }
        }
        if avartarType == .left {
            updateConstraintsToLeft()
        } else {
            updateConstraintsToRight()
        }
    }
}

extension GuideTableViewCell {

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        let size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority,
                                                 verticalFittingPriority: verticalFittingPriority)
        avatarImageView.layoutIfNeeded()
        contextContainer.layoutIfNeeded()
        contextTextLabel.layoutIfNeeded()
        let contextContainerHeight = contextContainer.frame.height
        return CGSize(width: size.width, height: contextContainerHeight + 20)
    }
}

extension GuideTableViewCell {
    private func updateConstraintsToLeft() {
        avatarImageView.snp.remakeConstraints { make in
            make.top.equalTo(contextContainer)
            make.left.equalToSuperview()
            make.height.width.equalTo(34.scale375Width())
        }
        contextContainer.snp.remakeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8.scale375Width())
            make.right.equalToSuperview().offset(-20.scale375Width())
            make.top.equalTo(contextTextLabel).offset(-12.scale375Height())
            if copyButtonContent.isHidden == false {
                make.bottom.equalTo(copyButtonContent)
            } else {
                make.bottom.equalTo(leftContextImageView).offset(12.scale375Height())
            }
        }
        nameLabel.snp.remakeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(4)
            make.centerX.equalTo(avatarImageView)
        }
    }

    private func updateConstraintsToRight() {
        avatarImageView.snp.remakeConstraints { make in
            make.top.equalTo(contextContainer)
            make.right.equalToSuperview()
            make.height.width.equalTo(34.scale375Width())
        }
        contextContainer.snp.remakeConstraints { make in
            make.right.equalTo(avatarImageView.snp.left).offset(-8.scale375Width())
            make.left.equalToSuperview().offset(20.scale375Width())
            make.top.equalTo(contextTextLabel).offset(-12.scale375Height())
            if copyButtonContent.isHidden == false {
                make.bottom.equalTo(copyButtonContent)
            } else {
                make.bottom.equalTo(leftContextImageView).offset(12)
            }
        }
        nameLabel.snp.remakeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(4)
            make.centerX.equalTo(avatarImageView)
        }
    }
}

extension GuideTableViewCell {
    @objc func copyUrlClicked() {
        copyAction()
    }
}
