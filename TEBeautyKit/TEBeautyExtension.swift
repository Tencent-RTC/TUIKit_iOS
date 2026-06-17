//
//  TUIBeautyExtension.swift
//  TEBeautyKit
//
//  Created by jackyixue on 2024/7/15.
//  Copyright (c) 2024 Tencent.

import Foundation
import TUICore
import TEBeautyKit

@objcMembers
public class TUIBeautyExtension: NSObject {

    static let shared = TUIBeautyExtension()
    private weak var beautyPanel: TUIBeautyKit?

    static func register() {
        TUICore.registerExtension(
            String.TUICORE_TEBEAUTYEXTENSION_GETBEAUTYPANEL,
            object: TUIBeautyExtension.shared
        )
        TUICore.registerService(
            String.TUICORE_TEBEAUTYSERVICE,
            object: TUIBeautyExtension.shared
        )
    }
}

// MARK: - TUIExtensionProtocol

extension TUIBeautyExtension: TUIExtensionProtocol {
    public func onGetExtension(_ extensionID: String, param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let params = param as? [String: Any] else { return nil }
        if extensionID == .TUICORE_TEBEAUTYEXTENSION_GETBEAUTYPANEL {
            guard let width = params["width"] as? CGFloat,
                  let height = params["height"] as? CGFloat else { return nil }
            var panel: TUIBeautyKit? = beautyPanel
            if panel == nil {
                panel = TUIBeautyKit(frame: CGRect(x: 0, y: 0, width: width, height: height))
            }
            beautyPanel = panel
            let info = TUIExtensionInfo()
            info.data = [String.TUICORE_TEBEAUTYEXTENSION_GETBEAUTYPANEL: panel!]
            return [info]
        }
        return nil
    }
}

// MARK: - TUIServiceProtocol

extension TUIBeautyExtension: TUIServiceProtocol {
    public func onCall(_ method: String, param: [AnyHashable: Any]?) -> Any? {
        if method == .TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAMEWITHTEXTURE {
            guard let textureId = param?[String.TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_TEXTUREID] as? Int32,
                  let textureWidth = param?[String.TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_TEXTUREWIDTH] as? Int32,
                  let textureHeight = param?[String.TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_TEXTUREHEIGHT] as? Int32 else {
                return nil
            }
            return beautyPanel?.processVideoFrame(textureId: textureId,
                                                  textureWidth: textureWidth,
                                                  textureHeight: textureHeight)
        }
        if method == .TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAMEWITHPIXELDATA {
            guard let pixelBufferValue = param?[String.TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_PIXELVALUE] as? NSValue else {
                return nil
            }
            let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(pixelBufferValue.pointerValue!).takeUnretainedValue()
            guard let result = beautyPanel?.processVideoFrame(pixelBuffer: pixelBuffer) else {
                return pixelBufferValue
            }
            return NSValue(pointer: Unmanaged.passUnretained(result).toOpaque())
        }
        if method == .TUICORE_TEBEAUTYEXTENSION_DESTROY_BEAUTYPANEL {
            beautyPanel?.removeFromSuperview()
            beautyPanel = nil
        }
        if method == .TUICORE_TEBEAUTYSERVICE_SETPANELLEVEL {
            if let level = param?[String.TUICORE_TEBEAUTYSERVICE_PANELLEVEL] as? String {
                TUIBeautyKit.currentBeautyLevel = TUIBeautyKit.BeautyLevel(rawValue: level) ?? .S1_07
            }
        }
        if method == .TUICORE_TEBEAUTYSERVICE_CHECKRESOURCE {
            return TUIBeautyKit.checkResource(completion: nil)
        }
        return nil
    }

    public func onCall(_ method: String, param: [AnyHashable: Any]?, resultCallback: @escaping TUICallServiceResultCallback) -> Any? {
        if method == .TUICORE_TEBEAUTYSERVICE_SETLICENSE {
            guard let licenseUrl = param?[String.TUICORE_TEBEAUTYSERVICE_LICENSEURL] as? String,
                  let licenseKey = param?[String.TUICORE_TEBEAUTYSERVICE_LICENSEKEY] as? String else {
                return nil
            }
            TEBeautyKit.setTELicense(licenseUrl, key: licenseKey) { code, msg in
                resultCallback(code, msg ?? "", [:])
            }
        }
        if method == .TUICORE_TEBEAUTYSERVICE_CHECKRESOURCE {
            return TUIBeautyKit.checkResource {
                resultCallback(0, "", [:])
            }
        }
        return nil
    }
}

// MARK: - TUICore Keys

fileprivate extension String {
    static let TUICORE_TEBEAUTYEXTENSION_GETBEAUTYPANEL = "TUICore_TEBeautyExtension_GetBeautyPanel"
    static let TUICORE_TEBEAUTYEXTENSION_DESTROY_BEAUTYPANEL = "TUICore_TEBeautyExtension_Destroy_BeautyPanel"
    static let TUICORE_TEBEAUTYSERVICE = "TUICore_TEBeautyService"
    static let TUICORE_TEBEAUTYSERVICE_SETLICENSE = "TUICore_TEBeautyService_SetLicense"
    static let TUICORE_TEBEAUTYSERVICE_LICENSEURL = "TUICore_TEBeautyService_LicenseUrl"
    static let TUICORE_TEBEAUTYSERVICE_LICENSEKEY = "TUICore_TEBeautyService_LicenseKey"
    static let TUICORE_TEBEAUTYSERVICE_CHECKRESOURCE = "TUICore_TEBeautyService_CheckResource"
    static let TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAMEWITHTEXTURE = "TUICore_TEBeautyService_ProcessVideoFrameWithTexture"
    static let TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_TEXTUREID = "TUICore_TEBeautyService_ProcessVideoFrame_TextureId"
    static let TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_TEXTUREWIDTH = "TUICore_TEBeautyService_ProcessVideoFrame_TextureWidth"
    static let TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_TEXTUREHEIGHT = "TUICore_TEBeautyService_ProcessVideoFrame_TextureHeight"
    static let TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAMEWITHPIXELDATA = "TUICore_TEBeautyService_ProcessVideoFrameWithPixelData"
    static let TUICORE_TEBEAUTYSERVICE_PROCESSVIDEOFRAME_PIXELVALUE = "TUICore_TEBeautyService_ProcessVideoFrame_PixelValue"
    static let TUICORE_TEBEAUTYSERVICE_SETPANELLEVEL = "TUICore_TEBeautyService_SetPanelLevel"
    static let TUICORE_TEBEAUTYSERVICE_PANELLEVEL = "TUICore_TEBeautyService_PanelLevel"
}
