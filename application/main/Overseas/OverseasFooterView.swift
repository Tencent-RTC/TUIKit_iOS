//
//  OverseasFooterView.swift
//  main
//

import UIKit
import SnapKit
import AtomicX

class OverseasFooterView: UICollectionReusableView {

    // MARK: - UI Elements

    let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "main_entrance_experience")
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        label.textAlignment = .left
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.text = MainLocalize("Demo.TRTC.Portal.Main.ScenarioExperience")
        return label
    }()

    private let descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.textAlignment = .left
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.text = MainLocalize("Demo.TRTC.Portal.Main.ScenarioExperienceDesc")
        return label
    }()

    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = UIImage(named: "main_entrance_pusharrow")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect(
            rect: containerView.bounds,
            byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: 10, height: 10)
        )
        containerView.gradient(
            colors: [ThemeStore.shared.colorTokens.buttonColorPrimaryDisabled, .white],
            bounds: containerView.bounds,
            isVertical: true
        )
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(arrowImageView)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.bottom.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(convertPixel(w: 16))
            make.topMargin.equalToSuperview().offset(convertPixel(h: 12))
            make.size.equalTo(CGSize(width: convertPixel(w: 24), height: convertPixel(h: 24)))
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(convertPixel(w: 6))
            make.centerY.equalTo(iconImageView)
        }

        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalTo(iconImageView)
            make.right.equalToSuperview().offset(-22)
            make.size.equalTo(CGSize(width: convertPixel(w: 16), height: convertPixel(w: 16)))
        }

        descLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(convertPixel(h: 8))
            make.left.equalToSuperview().offset(convertPixel(w: 15))
            make.right.equalToSuperview().offset(convertPixel(w: -15))
            make.bottom.equalToSuperview().offset(convertPixel(h: -12))
        }
    }
}
