import UIKit

class VideoRecordCore: NSObject {
    weak var recordDelegate: VideoRecorderCoreListener? {
        didSet {
            recordDelegateDidChange()
        }
    }

    func recordDelegateDidChange() {}

    @discardableResult
    func startCameraCustom(_ configDict: [String: Any], preview: UIView) -> Int {
        print("recorder currently not supported start Camera Custom")
        return 1
    }

    func stopCameraPreview() {
        print("recorder currently not supported stop camera preview")
    }

    func setZoom(_ distance: CGFloat) {
        print("recorder currently not supported set zoom")
    }

    @discardableResult
    func switchCamera(_ isFront: Bool) -> Bool {
        print("recorder currently not supported switch camera")
        return false
    }

    @discardableResult
    func toggleTorch(_ enable: Bool) -> Bool {
        print("recorder currently not supported toggle torch")
        return false
    }

    func setAspectRatio(_ videoRatio: VideoRecordAspectRatio) {
        print("recorder currently not supported set aspect ratio")
    }

    @discardableResult
    func startRecord(_ path: String?) -> Int {
        print("recorder currently not supported start record")
        return 1
    }

    @discardableResult
    func stopRecord() -> Int {
        print("recorder currently not supported stop record")
        return 1
    }

    func deleteTempFile() {
        print("recorder currently not supported delete temp file")
    }

    @discardableResult
    func snapshot(_ snapshotCompletionBlock: @escaping (UIImage?) -> Void) -> Int {
        print("recorder currently not supported delete snapshot")
        return 1
    }
}
