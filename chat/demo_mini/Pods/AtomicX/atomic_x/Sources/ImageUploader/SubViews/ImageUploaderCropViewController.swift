//  Created by eddard on 2025/10/21.
//  Copyright © 2025 Tencent. All rights reserved.

import UIKit
import Photos
import SnapKit

private let kCropSizeRatio: CGFloat = 0.9
private let kMaskOpacityHigh: CGFloat = 0.8
private let kMaskOpacityLow: CGFloat = 0.2

protocol ImageUploaderCropViewControllerDelegate: AnyObject {
    func imageCropViewController(_ viewController: ImageUploaderCropViewController, didFinishCroppingImage image: UIImage)
    func imageCropViewControllerDidCancel(_ viewController: ImageUploaderCropViewController)
}

class ImageUploaderCropViewController: UIViewController {
    weak var delegate: ImageUploaderCropViewControllerDelegate?
    
    private let overlayShape: ImageUploaderConfig.CropOverlayShape
    private let sourceImage: UIImage
    
    private var image: UIImage?
    private var zoomState = ImageUploaderZoomState()
    private var maskOpacity: CGFloat = kMaskOpacityHigh
    private var maskWorkItem: DispatchWorkItem?
    private var isViewReady = false
    
    private lazy var scrollView: ImageUploaderScrollView = {
        let scrollView = ImageUploaderScrollView()
        scrollView.delegate = self
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    private lazy var maskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.black.cgColor
        layer.fillRule = .evenOdd
        return layer
    }()
    
    private lazy var overlayShapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 1
        layer.fillColor = UIColor.clear.cgColor
        return layer
    }()
    
    private lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("cancel".atomicLocalized, for: .normal)
        button.setTitleColor(ThemeStore.shared.colorTokens.textColorButton, for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium16
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: ButtonSize.small.horizontalPadding,
                                                bottom: 0, right: ButtonSize.small.horizontalPadding)
        button.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        return button
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("done".atomicLocalized, for: .normal)
        button.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        button.setTitleColor(ThemeStore.shared.colorTokens.textColorAntiPrimary, for: .normal)
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium16
        button.layer.cornerRadius = ButtonSize.small.height / 2
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: ButtonSize.small.horizontalPadding,
                                                bottom: 0, right: ButtonSize.small.horizontalPadding)
        button.addTarget(self, action: #selector(handleConfirmCrop), for: .touchUpInside)
        return button
    }()
    
    init(overlayShape: ImageUploaderConfig.CropOverlayShape,
         image: UIImage) {
        self.overlayShape = overlayShape
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        isViewReady = true
        loadImage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateMaskAndOverlay()
    }
    
    func constructViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        view.layer.addSublayer(maskLayer)
        view.layer.addSublayer(overlayShapeLayer)
        
        view.addSubview(bottomBar)
        bottomBar.addSubview(cancelButton)
        bottomBar.addSubview(doneButton)
    }
    
    func activateConstraints() {
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(0)
        }
        
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(bottomBarHeight)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(CGFloat(ThemeStore.shared.space.space16))
            make.centerY.equalToSuperview()
            make.height.equalTo(ButtonSize.small.height)
        }
        
        doneButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-CGFloat(ThemeStore.shared.space.space16))
            make.centerY.equalToSuperview()
            make.height.equalTo(ButtonSize.small.height)
            make.width.greaterThanOrEqualTo(ButtonSize.small.minWidth)
        }
    }
    
    func bindInteraction() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        scrollView.setupHandler = { [weak self] containerSize in
            guard let self = self, self.image != nil else { return }
            self.setupInitialZoomAndCenter(containerSize: containerSize)
        }
    }
    
    func setupViewStyle() {
        view.backgroundColor = .black
        maskOpacity = kMaskOpacityHigh
    }
    
    private func loadImage() {
        let normalized = sourceImage.imageOrientation != .up ? normalizeImageOrientation(sourceImage) : sourceImage
        self.image = normalized
        self.imageView.image = normalized
        self.imageView.frame = CGRect(origin: .zero, size: normalized.size)
        self.scrollView.contentSize = normalized.size
            
        self.scrollView.hasCalledSetup = false
        self.scrollView.hasAppliedInitialOffset = false
        self.scrollView.setNeedsLayout()
        self.scrollView.layoutIfNeeded()
            
        self.zoomState = ImageUploaderZoomState()
        self.maskOpacity = kMaskOpacityHigh
        self.updateMaskAndOverlay()
    }
    
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
    
    private func setupInitialZoomAndCenter(containerSize: CGSize) {
        guard let image = image else { return }
        let imageSize = image.size
        let cropSize = calculateCropSize(for: containerSize)
        let minZoom = calculateMinZoomScale(imageSize: imageSize, cropSize: cropSize)
        let contentInset = calculateContentInset(containerSize: containerSize, cropSize: cropSize)
        
        scrollView.minimumZoomScale = minZoom
        scrollView.zoomScale = minZoom
        scrollView.contentInset = contentInset
        
        let scaledSize = CGSize(width: imageSize.width * minZoom, height: imageSize.height * minZoom)
        let idealOffsetX = (scaledSize.width - containerSize.width) / 2
        let idealOffsetY = (scaledSize.height - containerSize.height) / 2
        
        scrollView.pendingInitialOffset = CGPoint(x: idealOffsetX, y: idealOffsetY)
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        
        updateZoomState()
    }
    
    private var bottomBarHeight: CGFloat {
        ButtonSize.small.height + CGFloat(ThemeStore.shared.space.space16 + ThemeStore.shared.space.space8)
    }
    
    private func updateZoomState() {
        zoomState = ImageUploaderZoomState(
            zoomScale: scrollView.zoomScale,
            contentOffset: scrollView.contentOffset,
            hasInteracted: zoomState.hasInteracted
        )
    }
    
    private func calculateCropSize(for containerSize: CGSize) -> CGSize {
        let maxDimension = min(containerSize.width, containerSize.height) * kCropSizeRatio
        let aspectRatio = getAspectRatio()
        
        if overlayShape == .circle {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        
        if aspectRatio >= 1.0 {
            cropWidth = min(containerSize.width * kCropSizeRatio, maxDimension)
            cropHeight = cropWidth / aspectRatio
            
            if cropHeight > containerSize.height * kCropSizeRatio {
                let adjustedHeight = containerSize.height * kCropSizeRatio
                return CGSize(width: adjustedHeight * aspectRatio, height: adjustedHeight)
            }
        } else {
            cropHeight = min(containerSize.height * kCropSizeRatio, maxDimension)
            cropWidth = cropHeight * aspectRatio
            
            if cropWidth > containerSize.width * kCropSizeRatio {
                let adjustedWidth = containerSize.width * kCropSizeRatio
                return CGSize(width: adjustedWidth, height: adjustedWidth / aspectRatio)
            }
        }
        
        return CGSize(width: cropWidth, height: cropHeight)
    }
    
    private func getAspectRatio() -> CGFloat {
        switch overlayShape {
        case .circle, .rectangle_1_1:
            return 1.0
        case .rectangle_4_3:
            return 4.0 / 3.0
        case .rectangle_3_4:
            return 3.0 / 4.0
        case .rectangle_16_9:
            return 16.0 / 9.0
        case .rectangle_9_16:
            return 9.0 / 16.0
        }
    }
    
    private func calculateMinZoomScale(imageSize: CGSize, cropSize: CGSize) -> CGFloat {
        let zoomToFitWidth = cropSize.width / imageSize.width
        let zoomToFitHeight = cropSize.height / imageSize.height
        return max(zoomToFitWidth, zoomToFitHeight)
    }
    
    private func calculateContentInset(containerSize: CGSize, cropSize: CGSize) -> UIEdgeInsets {
        let insetX = max((containerSize.width - cropSize.width) / 2, 0)
        let insetY = max((containerSize.height - cropSize.height) / 2, 0)
        return UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }
    
    private func updateMaskAndOverlay() {
        let viewSize = view.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        
        let containerSize = CGSize(width: viewSize.width, height: viewSize.height)
        let cropSize = calculateCropSize(for: containerSize)
        let cropRect = CGRect(
            x: (viewSize.width - cropSize.width) / 2,
            y: (containerSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )
        
        let fullPath = UIBezierPath(rect: CGRect(origin: .zero, size: viewSize))
        let cropPath: UIBezierPath
        
        if overlayShape == .circle {
            cropPath = UIBezierPath(ovalIn: cropRect)
        } else {
            cropPath = UIBezierPath(rect: cropRect)
        }
        
        fullPath.append(cropPath)
        maskLayer.path = fullPath.cgPath
        maskLayer.opacity = Float(maskOpacity)
        
        if overlayShape == .circle {
            overlayShapeLayer.path = UIBezierPath(ovalIn: cropRect).cgPath
        } else {
            overlayShapeLayer.path = UIBezierPath(rect: cropRect).cgPath
        }
    }
    
    private func handleMaskOpacityChange() {
        maskWorkItem?.cancel()
        maskOpacity = kMaskOpacityLow
        updateMaskAndOverlay()
        
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.maskOpacity = kMaskOpacityHigh
                self?.updateMaskAndOverlay()
            }
        }
        maskWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
    
    @objc private func handleCancel() {
        delegate?.imageCropViewControllerDidCancel(self)
    }
    
    @objc private func handleConfirmCrop() {
        guard let image = image, let cgImage = image.cgImage else { return }
        
        let viewSize = view.bounds.size
        let containerSize = CGSize(width: viewSize.width, height: viewSize.height)
        let cropSize = calculateCropSize(for: containerSize)
        
        let cropRectInView = CGRect(
            x: (viewSize.width - cropSize.width) / 2,
            y: (containerSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )
        
        let cropRectInImageView = view.convert(cropRectInView, to: imageView)
        
        let imageSize = image.size
        let rectInImagePoints = cropRectInImageView
        
        let imagePointsBounds = CGRect(origin: .zero, size: imageSize)
        let clampedInPoints = rectInImagePoints.intersection(imagePointsBounds)
        guard clampedInPoints.width > 0, clampedInPoints.height > 0 else { return }
        
        let pixelRect = CGRect(
            x: clampedInPoints.origin.x * image.scale,
            y: clampedInPoints.origin.y * image.scale,
            width: clampedInPoints.width * image.scale,
            height: clampedInPoints.height * image.scale
        ).integral
        
        let cgImageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let finalPixelRect = pixelRect.intersection(cgImageBounds)
        guard finalPixelRect.width > 0, finalPixelRect.height > 0 else { return }
        
        guard let croppedCGImage = cgImage.cropping(to: finalPixelRect) else { return }
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
        
        delegate?.imageCropViewController(self, didFinishCroppingImage: croppedImage)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        zoomState.hasInteracted = true
        
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let location = gesture.location(in: imageView)
            let zoomScale: CGFloat = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.0)
            let zoomRect = zoomRectForScale(zoomScale, center: location)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        let width = scrollView.bounds.width / scale
        let height = scrollView.bounds.height / scale
        let x = center.x - width / 2
        let y = center.y - height / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

extension ImageUploaderCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        zoomState.hasInteracted = true
        handleMaskOpacityChange()
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        zoomState.hasInteracted = true
        handleMaskOpacityChange()
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateZoomState()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateZoomState()
    }
}

struct ImageUploaderZoomState {
    var zoomScale: CGFloat = 1.0
    var contentOffset: CGPoint = .zero
    var hasInteracted: Bool = false
}

final class ImageUploaderScrollView: UIScrollView {
    var pendingInitialOffset: CGPoint?
    var setupHandler: ((CGSize) -> Void)?
    
    var hasCalledSetup = false
    var hasAppliedInitialOffset = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if !hasCalledSetup && bounds.size.width > 0 && bounds.size.height > 0 {
            hasCalledSetup = true
            setupHandler?(bounds.size)
        }
        
        if !hasAppliedInitialOffset, let offset = pendingInitialOffset {
            contentOffset = offset
            hasAppliedInitialOffset = true
            pendingInitialOffset = nil
        }
    }
}
