//
//  TUIBeautyKit.swift
//  TEBeautyKit
//
//  Created by jack on 2024/12/31.
//  Copyright (c) 2024 Tencent.

import Foundation
import CoreVideo
import TEBeautyKit
import SnapKit
import TUICore

@objcMembers
public class TUIBeautyKit: UIView {

    // MARK: - Beauty Level Enum
    public enum BeautyLevel: String, CaseIterable {
        case A1_00 = "A1-00"
        case A1_01 = "A1-01"
        case A1_02 = "A1-02"
        case A1_03 = "A1-03"
        case A1_04 = "A1-04"
        case A1_05 = "A1-05"
        case A1_06 = "A1-06"
        case S1_00 = "S1-00"
        case S1_01 = "S1-01"
        case S1_02 = "S1-02"
        case S1_03 = "S1-03"
        case S1_04 = "S1-04"
        case S1_05 = "S1-05"
        case S1_06 = "S1-06"
        case S1_07 = "S1-07"

        struct ModuleConfig {
            let key: String
            let jsonFileName: String
        }

        var allowedModules: [ModuleConfig] {
            switch self {
            case .A1_00:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                ]
            case .A1_01:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_base_shape"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                ]
            case .A1_02:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_base_shape"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                ]
            case .A1_03:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_general_shape"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                ]
            case .A1_04:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_general_shape"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                ]
            case .A1_05:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_general_shape"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "SEGMENTATION", jsonFileName: "segmentation"),
                ]
            case .A1_06:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_general_shape"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                ]
            case .S1_00:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                ]
            case .S1_01:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                ]
            case .S1_02:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MOTION_GESTURE", jsonFileName: "motion_gesture"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                ]
            case .S1_03:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                    ModuleConfig(key: "SEGMENTATION", jsonFileName: "segmentation"),
                ]
            case .S1_04:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MOTION_GESTURE", jsonFileName: "motion_gesture"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                    ModuleConfig(key: "SEGMENTATION", jsonFileName: "segmentation"),
                ]
            case .S1_05:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "BEAUTY_BODY", jsonFileName: "beauty_body"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                    ModuleConfig(key: "SEGMENTATION", jsonFileName: "segmentation"),
                ]
            case .S1_06:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "BEAUTY_BODY", jsonFileName: "beauty_body"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MOTION_GESTURE", jsonFileName: "motion_gesture"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                    ModuleConfig(key: "SEGMENTATION", jsonFileName: "segmentation"),
                ]
            case .S1_07:
                return [
                    ModuleConfig(key: "BEAUTY_TEMPLATE", jsonFileName: "beauty_template"),
                    ModuleConfig(key: "BEAUTY", jsonFileName: "beauty"),
                    ModuleConfig(key: "BEAUTY_IMAGE", jsonFileName: "beauty_image"),
                    ModuleConfig(key: "BEAUTY_SHAPE", jsonFileName: "beauty_shape"),
                    ModuleConfig(key: "BEAUTY_MAKEUP", jsonFileName: "beauty_makeup"),
                    ModuleConfig(key: "LUT", jsonFileName: "lut"),
                    ModuleConfig(key: "BEAUTY_BODY", jsonFileName: "beauty_body"),
                    ModuleConfig(key: "MOTION_2D", jsonFileName: "motion_2d"),
                    ModuleConfig(key: "MOTION_3D", jsonFileName: "motion_3d"),
                    ModuleConfig(key: "MOTION_GESTURE", jsonFileName: "motion_gesture"),
                    ModuleConfig(key: "MAKEUP", jsonFileName: "makeup"),
                    ModuleConfig(key: "LIGHT_MAKEUP", jsonFileName: "light_makeup"),
                    ModuleConfig(key: "SEGMENTATION", jsonFileName: "segmentation"),
                ]
            }
        }
    }

    // MARK: - Static Configuration

    static var currentBeautyLevel: BeautyLevel = .S1_07

    /// One-step initialization: register TUICore services, set license, and configure beauty level.
    /// Call this in AppDelegate before any beauty panel usage.
    /// - Parameters:
    ///   - licenseUrl: TEBeautyKit license URL
    ///   - licenseKey: TEBeautyKit license key
    ///   - beautyLevel: Beauty package level string, e.g. "A1-00", "S1-07". Defaults to "S1-07" if invalid.
    ///   - completion: License verification callback
    public static func initialize(licenseUrl: String, licenseKey: String, beautyLevel: BeautyLevel = .S1_07, completion: ((_ code: Int, _ message: String?) -> Void)? = nil) {
        currentBeautyLevel = beautyLevel
        TUIBeautyExtension.register()
        TEBeautyKit.setTELicense(licenseUrl, key: licenseKey) { code, message in
            completion?(code, message)
        }
    }

    // MARK: - Instance

    private var xmagic: XMagic?
    private var beautyKit: TEBeautyKit?
    private var panelView: TEPanelView?

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
        let beautyLevel = TUIBeautyKit.currentBeautyLevel
        var resources: [[String: String]] = []

        for module in beautyLevel.allowedModules {
            if let path = bundle.path(forResource: module.jsonFileName, ofType: "json") {
                resources.append([module.key: path])
            }
        }

        TEUIConfig.shareInstance().setTEPanelViewResources(resources as [[AnyHashable: Any]])
    }

    private func initXMagic() {
        TEBeautyKit.create { [weak self] beautyKit in
            guard let self = self else { return }
            guard let beautyKit = beautyKit else { return }
            self.beautyKit = beautyKit
            self.xmagic = beautyKit.xmagicApi
            self.xmagic?.setAudioMute(true)
            self.beautyKit?.setLogLevel(.YT_SDK_ERROR_LEVEL)

            self.panelView?.teBeautyKit = self.beautyKit
            self.panelView?.beautyKitApi = beautyKit.xmagicApi

            self.panelView?.setDefaultBeauty()
        }
    }
}

// MARK: - Public

extension TUIBeautyKit {

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

// MARK: - TEPanelViewDelegate

extension TUIBeautyKit: TEPanelViewDelegate {

    public func showBeautyChanged(_ open: Bool) {
        beautyKit?.enableBeauty(open)
    }
}
