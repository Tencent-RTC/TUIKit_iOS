//  Created by eddard on 2025/10/21.
//  Copyright © 2025 Tencent. All rights reserved.

import UIKit
import SnapKit

enum ImageSourceType {
    case camera
    case album
}

protocol ImageSourceBottomSheetDelegate: AnyObject {
    func imageSourceBottomSheet(_ sheet: ImageSourceBottomSheetView, didSelectSource source: ImageSourceType)
    func imageSourceBottomSheetDidCancel(_ sheet: ImageSourceBottomSheetView)
}

final class ImageSourceBottomSheetView: UIView {
    weak var delegate: ImageSourceBottomSheetDelegate?
    
    private static let animationDuration: TimeInterval = 0.25
    private static let optionHeight: CGFloat = 56
    
    private let space = SpaceTokens.standard
    private let borderRadius = BorderRadiusToken.standard
    private var typography: TypographyToken { ThemeStore.shared.typographyTokens }
    private var colorTokens: ColorTokens { ThemeStore.shared.colorTokens }
    
    private lazy var dimBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.alpha = 0
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleCancel)))
        return view
    }()
    
    private lazy var bottomSheetView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = borderRadius.radius12
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var cameraOptionView = createOptionView(
        iconName: "camera.fill",
        title: "image_uploader_camera".atomicLocalized,
        action: #selector(handleCameraTap)
    )
    
    private lazy var albumOptionView = createOptionView(
        iconName: "photo.fill",
        title: "image_uploader_album".atomicLocalized,
        action: #selector(handleAlbumTap)
    )
    
    private lazy var separatorView = UIView()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("cancel".atomicLocalized, for: .normal)
        button.titleLabel?.font = typography.Medium16
        button.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
    
    func show(in parentView: UIView) {
        parentView.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        layoutIfNeeded()
        updateColors()
        bottomSheetView.transform = CGAffineTransform(translationX: 0, y: bottomSheetView.bounds.height)
        UIView.animate(withDuration: Self.animationDuration) {
            self.dimBackgroundView.alpha = 1
            self.bottomSheetView.transform = .identity
        }
    }
    
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: Self.animationDuration, animations: {
            self.dimBackgroundView.alpha = 0
            self.bottomSheetView.transform = CGAffineTransform(translationX: 0, y: self.bottomSheetView.bounds.height)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

private extension ImageSourceBottomSheetView {
    
    func setupUI() {
        addSubview(dimBackgroundView)
        addSubview(bottomSheetView)
        bottomSheetView.addSubview(cameraOptionView)
        bottomSheetView.addSubview(albumOptionView)
        bottomSheetView.addSubview(separatorView)
        bottomSheetView.addSubview(cancelButton)
        
        dimBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        bottomSheetView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        cameraOptionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(space.space16)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.optionHeight)
        }
        albumOptionView.snp.makeConstraints { make in
            make.top.equalTo(cameraOptionView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.optionHeight)
        }
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(albumOptionView.snp.bottom).offset(space.space8 + space.space4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(space.space4)
        }
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.optionHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
        updateColors()
    }
    
    func updateColors() {
        let tokens = colorTokens
        bottomSheetView.backgroundColor = tokens.bgColorDialog
        separatorView.backgroundColor = tokens.strokeColorSecondary
        cancelButton.setTitleColor(tokens.buttonColorPrimaryDefault, for: .normal)
        for optionView in [cameraOptionView, albumOptionView] {
            for subview in optionView.subviews {
                if let imageView = subview as? UIImageView {
                    imageView.tintColor = tokens.textColorSecondary
                } else if let label = subview as? UILabel {
                    label.textColor = tokens.textColorPrimary
                }
            }
        }
    }
    
    func createOptionView(iconName: String, title: String, action: Selector) -> UIView {
        let container = UIView()
        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = title
        label.font = typography.Medium16
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.contentMode = .scaleAspectFit
        
        container.addSubview(icon)
        container.addSubview(label)
        container.addSubview(arrow)
        
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(space.space16)
            make.centerY.equalToSuperview()
            make.size.equalTo(space.space24)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(space.space8 + space.space4)
            make.centerY.equalToSuperview()
        }
        arrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-space.space16)
            make.centerY.equalToSuperview()
            make.size.equalTo(space.space20)
        }
        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        return container
    }
    
    @objc func handleCancel() {
        delegate?.imageSourceBottomSheetDidCancel(self)
    }
    
    @objc func handleCameraTap() {
        delegate?.imageSourceBottomSheet(self, didSelectSource: .camera)
    }
    
    @objc func handleAlbumTap() {
        delegate?.imageSourceBottomSheet(self, didSelectSource: .album)
    }
}
