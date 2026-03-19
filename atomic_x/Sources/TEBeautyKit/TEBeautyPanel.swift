//
//  TEBeautyPanel.swift
//  TEBeautyKit
//
//  Created by jack on 2024/12/31.
//  Copyright (c) 2024 Tencent.

import Foundation
import CoreVideo
import TEBeautyKit
import SnapKit

class TEBeautyPanel: UIView {
    
    private var xmagic: XMagic?
    private var beautyKit: TEBeautyKit?
    private var panelView: TEPanelView?
    private var isComparing: Bool = false
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = frame
        initBeautyKit(frame: frame)
    }
    
    deinit {
        unInitBeautyKit()
    }
    
    private func initBeautyKit(frame: CGRect) {
        TEUIConfig.shareInstance().panelBackgroundColor = UIColor(red: 0x1F/255.0,
                                                                  green: 0x20/255.0,
                                                                  blue: 0x24/255.0,
                                                                  alpha: 1.0)
        initBeautyJson()

        panelView = TEPanelView()
        panelView?.delegate = self
        addSubview(panelView!)
        panelView?.snp.makeConstraints({ make in
            make.edges.equalToSuperview()
            make.size.equalTo(frame.size)
        })
        initXMagic()
    }
    
    private func unInitBeautyKit() {
        if let xmagic = self.xmagic {
            xmagic.onPause()
            xmagic.clearListeners()
            xmagic.deinit()
            self.xmagic = nil
        }
        beautyKit = nil
        panelView?.removeFromSuperview()
    }
    
    private func initBeautyJson() {
        let bundle = Bundle.main
        
        var resources: [[String: String]] = []

        
        if let templatePath = bundle.path(forResource: "beauty_template", ofType: "json") {
            resources.append(["BEAUTY_TEMPLATE": templatePath])
        }

        if let beautyPath = bundle.path(forResource: "beauty", ofType: "json") {
            resources.append(["BEAUTY": beautyPath])
        }

        if let lutPath = bundle.path(forResource: "lut", ofType: "json") {
            resources.append(["LUT": lutPath])
        }

        if let bodyPath = bundle.path(forResource: "beauty_body", ofType: "json") {
            resources.append(["BEAUTY_BODY": bodyPath])
        }

        if let shapePath = bundle.path(forResource: "beauty_shape", ofType: "json") {
            resources.append(["BEAUTY_FACE_SHAPE": shapePath])
        }

        if let imagePath = bundle.path(forResource: "beauty_image", ofType: "json") {
            resources.append(["BEAUTY_IMAGE": imagePath])
        }

        if let makeupPath = bundle.path(forResource: "beauty_makeup", ofType: "json") {
            resources.append(["BEAUTY_MAKEUP": makeupPath])
        }

        if let motion2dPath = bundle.path(forResource: "motion_2d", ofType: "json") {
            resources.append(["MOTION_2D": motion2dPath])
        }

        if let motion3dPath = bundle.path(forResource: "motion_3d", ofType: "json") {
            resources.append(["MOTION_3D": motion3dPath])
        }

        if let makeupPath = bundle.path(forResource: "makeup", ofType: "json") {
            resources.append(["MAKEUP": makeupPath])
        }

        if let lightMakeupPath = bundle.path(forResource: "light_makeup", ofType: "json") {
            resources.append(["LIGHT_MAKEUP": lightMakeupPath])
        }

        if let segPath = bundle.path(forResource: "segmentation", ofType: "json") {
            resources.append(["SEGMENTATION": segPath])
        }

        TEUIConfig.shareInstance().setTEPanelViewResources(resources as [[AnyHashable: Any]])
    }

    private func initXMagic() {
        TEBeautyKit.create { [weak self] beautyKit in
            guard let self = self else { return }
            
            guard let beautyKit = beautyKit else { return}
            self.beautyKit = beautyKit
            self.xmagic = beautyKit.xmagicApi
            self.beautyKit?.setLogLevel(.YT_SDK_ERROR_LEVEL)

            self.panelView?.teBeautyKit = self.beautyKit
            self.panelView?.beautyKitApi = beautyKit.xmagicApi
            
            self.panelView?.setDefaultBeauty()
        }
    }
}

// MARK: - Public
extension TEBeautyPanel {
    
    public static func checkResource(completion: (() -> ())?) -> Bool {
        completion?()
        return true
    }
    
    public func processVideoFrame(textureId: Int32, textureWidth: Int32, textureHeight: Int32) -> Int32 {
        guard let beautyKit = beautyKit else {
            return textureId
        }
        let output = beautyKit.processTexture(UInt32(Int32(textureId)),
                                              textureWidth: Int32(textureWidth),
                                              textureHeight: Int32(textureHeight),
                                              with: .topLeft,
                                              with: .cameraRotation0)
        return Int32(output?.textureData?.texture ?? UInt32(textureId))
    }
    
    public func processVideoFrame(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        guard let beautyKit = beautyKit else {
            return pixelBuffer
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let output = beautyKit.processPixelData(pixelBuffer,
                                                pixelDataWidth: Int32(width),
                                                pixelDataHeight: Int32(height),
                                                with: .topLeft,
                                                with: .cameraRotation0)
        return output?.pixelData?.data ?? pixelBuffer
    }
}

// MARK: - Private
extension TEBeautyPanel {
    
    private static func getCurrentWindowViewController() -> UIViewController? {
        var keyWindow: UIWindow?
        for window in UIApplication.shared.windows {
            if window.isMember(of: UIWindow.self), window.isKeyWindow {
                keyWindow = window
                break
            }
        }
        guard let rootController = keyWindow?.rootViewController else {
            return nil
        }
        func findCurrentController(from vc: UIViewController?) -> UIViewController? {
            if let nav = vc as? UINavigationController {
                return findCurrentController(from: nav.topViewController)
            } else if let tabBar = vc as? UITabBarController {
                return findCurrentController(from: tabBar.selectedViewController)
            } else if let presented = vc?.presentedViewController {
                return findCurrentController(from: presented)
            }
            return vc
        }
        let viewController = findCurrentController(from: rootController)
        return viewController
    }
    
}

// MARK: - TEPanelViewDelegate
extension TEBeautyPanel: TEPanelViewDelegate {

    func showBeautyChanged(_ open: Bool) {
        beautyKit?.enableBeauty(open)
    }
}
