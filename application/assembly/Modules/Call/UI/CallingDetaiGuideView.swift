//
//  CallingDetaiGuideView.swift
//  main
//

import UIKit
import AtomicX

class CallingDetaiGuideView: UIView {

    private let guideImageContainerView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()

    private let guideImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        imageView.image = AppAssemblyBundle.image(named: "calling_call_guide")
        return imageView
    }()

    private let guideButtonContainerView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()

    private let guideButtonTitleLable: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = CallingLocalize("Demo.TRTC.calling.detailGuide")
        label.font = ThemeStore.shared.typographyTokens.Medium14
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.textColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        return label
    }()

    private let guideArrowImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        imageView.image = AppAssemblyBundle.image(named: "calling_call_pushArrow")
        return imageView
    }()

    private let guideButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()

    var guideButtonClickHandler: () -> Void = {}
    var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
}

extension CallingDetaiGuideView {
    private func constructViewHierarchy() {
        addSubview(guideButtonContainerView)
        guideButtonContainerView.addSubview(guideButtonTitleLable)
        guideButtonContainerView.addSubview(guideArrowImageView)
        guideButtonContainerView.addSubview(guideButton)
        addSubview(guideImageContainerView)
        guideImageContainerView.addSubview(guideImageView)
    }

    private func activateConstraints() {
        guideButtonContainerView.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.width.equalTo(160)
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        guideButtonTitleLable.snp.makeConstraints { make in
            make.width.equalTo(142)
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        guideArrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.height.width.equalTo(14)
            make.centerY.equalToSuperview()
        }
        guideButton.snp.makeConstraints { make in
            make.edges.equalTo(guideButtonContainerView)
        }
        guideImageContainerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(guideButtonContainerView.snp.top)
        }
        guideImageView.snp.makeConstraints { make in
            make.height.equalTo(118)
            make.width.equalTo(172)
            make.center.equalToSuperview()
        }
    }

    func bindInteraction() {
        self.guideButton.addTarget(self, action: #selector(guideButtonClicked), for: .touchUpInside)
    }
}

extension CallingDetaiGuideView {
    @objc func guideButtonClicked() {
        self.guideButtonClickHandler()
    }
}
