//
//  BeautyView.swift
//  TUICallKit
//
//

import UIKit
import Combine
import RTCRoomEngine
#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif
import TUICore
import AtomicX
import AtomicXCore

private let TUICore_TEBeautyExtension_GetBeautyPanel = "TUICore_TEBeautyExtension_GetBeautyPanel"
private let TUICore_TEBeautyService = "TUICore_TEBeautyService"
private let TUICore_TEBeautyService_ProcessVideoFrameWithPixelData = "TUICore_TEBeautyService_ProcessVideoFrameWithPixelData"
private let TUICore_TEBeautyService_ProcessVideoFrame_PixelValue = "TUICore_TEBeautyService_ProcessVideoFrame_PixelValue"
private let TUICore_TEBeautyService_CachedBeautyEffect = "TUICore_TEBeautyService_CachedBeautyEffect"

class TEBeautyView: UIView {

    // MARK: - Singleton

    private static var instance: TEBeautyView?

    static func shared() -> TEBeautyView {
        if let instance = instance {
            return instance
        }
        let view = TEBeautyView()
        instance = view
        return view
    }

    static func releaseSharedInstance() {
        instance = nil
    }

    var backClosure: (() -> Void)?

    private var isAdvancedBeauty = false
    private lazy var trtcCloud: TRTCCloud = {
        return TUICallEngine.createInstance().getTRTCCloudInstance()
    }()
    private weak var beautyPanel: UIView?

    private init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isAdvancedBeauty && self.window == nil {
            TUICore.callService(TUICore_TEBeautyService, method: TUICore_TEBeautyService_CachedBeautyEffect, param: nil)
        }
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }

    private func constructViewHierarchy() {
        guard let panel = getAdvancedBeautyPanel() else { return }
        addSubview(panel)
        beautyPanel = panel
        isAdvancedBeauty = true
    }

    private func activateConstraints() {
        beautyPanel?.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func bindInteraction() {
        guard isAdvancedBeauty else { return }
        trtcCloud.setLocalVideoProcessDelegete(self, pixelFormat: ._32BGRA, bufferType: .pixelBuffer)
    }

    private func getAdvancedBeautyPanel() -> UIView? {
        let screenWidth = UIScreen.main.bounds.size.width
        let beautyPanelList = TUICore.getExtensionList(
            TUICore_TEBeautyExtension_GetBeautyPanel,
            param: ["width": screenWidth, "height": CGFloat(250)]
        )
        return beautyPanelList.first?.data?[TUICore_TEBeautyExtension_GetBeautyPanel] as? UIView
    }

    private func removeObserver() {
        guard isAdvancedBeauty else { return }
        trtcCloud.setLocalVideoProcessDelegete(nil, pixelFormat: ._32BGRA, bufferType: .pixelBuffer)
    }

    deinit {
        removeObserver()
    }
}

// MARK: - TRTCVideoFrameDelegate

extension TEBeautyView: TRTCVideoFrameDelegate {
    func onProcessVideoFrame(_ srcFrame: TRTCVideoFrame, dstFrame: TRTCVideoFrame) -> UInt32 {
        guard let pixelBuffer = srcFrame.pixelBuffer else { return 0 }
        let pixelBufferValue = NSValue(pointer: Unmanaged.passUnretained(pixelBuffer).toOpaque())
        if let resultValue = TUICore.callService(
            TUICore_TEBeautyService,
            method: TUICore_TEBeautyService_ProcessVideoFrameWithPixelData,
            param: [TUICore_TEBeautyService_ProcessVideoFrame_PixelValue: pixelBufferValue]
        ) as? NSValue {
            guard let pointerValue = resultValue.pointerValue else { return 0 }
            let resultPixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(pointerValue).takeUnretainedValue()
            dstFrame.pixelBuffer = resultPixelBuffer
        }
        return 0
    }
}

