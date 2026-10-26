import UIKit

final class UGCReflectVideoRecordCore: VideoRecordCore {
    private typealias StartCameraFunction = @convention(c) (AnyObject, Selector, AnyObject, UIView) -> Int32

    private typealias CGFloatArgumentFunction = @convention(c) (AnyObject, Selector, CGFloat) -> Void

    private typealias BoolArgumentBoolReturnFunction = @convention(c) (AnyObject, Selector, ObjCBool) -> ObjCBool

    private typealias StartRecordFunction = @convention(c) (AnyObject, Selector, NSString, NSString) -> Int32

    private typealias SnapshotBlock = @convention(block) (UIImage?) -> Void

    private typealias SnapshotFunction = @convention(c) (AnyObject, Selector, SnapshotBlock) -> Int32

    private let txUGCRecorderInstance: AnyObject

    private var listenerProxy: VideodioRecorderListenerProxy?

    static func create() -> UGCReflectVideoRecordCore? {
        guard let txClass = NSClassFromString("TXUGCRecord") else {
            print("can not find TXUGCRecord")
            return nil
        }
        guard let instance = VideoRecorderReflectUtil.invokeObjectMethod(txClass as AnyObject, methodName: "shareInstance") else {
            return nil
        }
        return UGCReflectVideoRecordCore(txUGCRecorderInstance: instance)
    }

    private init(txUGCRecorderInstance: AnyObject) {
        self.txUGCRecorderInstance = txUGCRecorderInstance
        super.init()
    }

    override func recordDelegateDidChange() {
        let proxy = VideodioRecorderListenerProxy()
        proxy.recordDelegate = recordDelegate
        listenerProxy = proxy
        VideoRecorderReflectUtil.invokeMethod(txUGCRecorderInstance, methodName: "setRecordDelegate:", argument: proxy)
    }

    @discardableResult
    override func startCameraCustom(_ configDict: [String: Any], preview: UIView) -> Int {
        guard let customConfig = VideoRecorderReflectUtil.createClassInstance("TXUGCCustomConfig") else {
            return 1
        }
        for (key, value) in configDict where customConfig.responds(to: NSSelectorFromString(key)) {
            customConfig.setValue(value, forKey: key)
        }
        if let invocation = VideoRecorderReflectUtil.invocation(txUGCRecorderInstance, methodName: "startCameraCustom:preview:",
                                                                as: StartCameraFunction.self) {
            _ = invocation.function(invocation.target, invocation.selector, customConfig, preview)
        }
        return 1
    }

    override func setZoom(_ distance: CGFloat) {
        guard let invocation = VideoRecorderReflectUtil.invocation(txUGCRecorderInstance, methodName: "setZoom:",
                                                                   as: CGFloatArgumentFunction.self) else { return }
        invocation.function(invocation.target, invocation.selector, distance)
    }

    @discardableResult
    override func switchCamera(_ isFront: Bool) -> Bool {
        return invokeBoolMethod("switchCamera:", argument: isFront)
    }

    @discardableResult
    override func toggleTorch(_ enable: Bool) -> Bool {
        print("toggleTorch @\(enable)")
        return invokeBoolMethod("toggleTorch:", argument: enable)
    }

    override func stopCameraPreview() {
        VideoRecorderReflectUtil.invokeVoidMethod(txUGCRecorderInstance, methodName: "stopCameraPreview")
    }

    override func setAspectRatio(_ videoRatio: VideoRecordAspectRatio) {
        VideoRecorderReflectUtil.invokeMethod(txUGCRecorderInstance, methodName: "setAspectRatio:", integerArgument: videoRatio.rawValue)
    }

    @discardableResult
    override func startRecord(_ path: String?) -> Int {
        guard let path = path else { return -1 }
        let withoutExtension = (path as NSString).deletingPathExtension as NSString
        let coverPath = withoutExtension.appendingPathExtension("jpg") ?? "\(withoutExtension).jpg"
        guard let invocation = VideoRecorderReflectUtil.invocation(txUGCRecorderInstance, methodName: "startRecord:coverPath:",
                                                                   as: StartRecordFunction.self) else { return -1 }
        return Int(invocation.function(invocation.target, invocation.selector, path as NSString, coverPath as NSString))
    }

    @discardableResult
    override func stopRecord() -> Int {
        if let invocation = VideoRecorderReflectUtil.invocation(txUGCRecorderInstance, methodName: "stopRecord",
                                                                as: VideoRecorderReflectUtil.IntReturnFunction.self) {
            _ = invocation.function(invocation.target, invocation.selector)
        }
        return 1
    }

    @discardableResult
    override func snapshot(_ snapshotCompletionBlock: @escaping (UIImage?) -> Void) -> Int {
        guard let invocation = VideoRecorderReflectUtil.invocation(txUGCRecorderInstance, methodName: "snapshot:",
                                                                   as: SnapshotFunction.self) else { return -1 }
        let block: SnapshotBlock = { image in
            snapshotCompletionBlock(image)
        }
        return Int(invocation.function(invocation.target, invocation.selector, block))
    }

    override func deleteTempFile() {
        let partsManager = VideoRecorderReflectUtil.safeValueForProperty(txUGCRecorderInstance, propertyName: "partsManager")
        VideoRecorderReflectUtil.invokeVoidMethod(partsManager, methodName: "deleteAllParts")
    }

    private func invokeBoolMethod(_ methodName: String, argument: Bool) -> Bool {
        guard let invocation = VideoRecorderReflectUtil.invocation(txUGCRecorderInstance, methodName: methodName,
                                                                   as: BoolArgumentBoolReturnFunction.self) else { return false }
        return invocation.function(invocation.target, invocation.selector, ObjCBool(argument)).boolValue
    }
}

final class VideodioRecorderListenerProxy: NSObject {
    weak var recordDelegate: VideoRecorderCoreListener?

    @objc func onRecordProgress(_ milliSecond: Int) {
        print("onRecordProgress:\(milliSecond)")
        recordDelegate?.onRecordProgress(milliSecond)
    }

    @objc func onRecordComplete(_ result: AnyObject?) {
        guard let recordDelegate = recordDelegate else { return }

        var retCode = -1
        var descMsg = ""
        var videoPath = ""

        if let result = result as? NSObject {
            if let retCodeValue = result.value(forKey: "retCode") as? NSNumber {
                retCode = retCodeValue.intValue
            }
            if let descMsgValue = result.value(forKey: "descMsg") as? String {
                descMsg = descMsgValue
            }
            if let videoPathValue = result.value(forKey: "videoPath") as? String {
                videoPath = videoPathValue
            }
        }

        print("on record complete. retcode:\(retCode) descMsg:\(descMsg) videoPath:\(videoPath)")

        let videoRecordResult = VideoRecordResult()
        videoRecordResult.retCode = VideoRecordResultCode(rawValue: retCode)
        videoRecordResult.videoPath = videoPath
        videoRecordResult.descMsg = descMsg
        recordDelegate.onRecordComplete(videoRecordResult)
    }

    @objc func onRecordEvent(_ evt: AnyObject?) {}
}
