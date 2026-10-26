import AVFoundation
import UIKit

final class SystemVideoRecordCore: VideoRecordCore {
    private static let millisecondsPerSecond = 1000

    private static let bitrateUnit = 1024

    private static let recordTimerInterval: TimeInterval = 0.1

    private static let recordTimerStepMs = 100

    private static let jpegQuality = 0.9

    private static let resolution1080P = CGSize(width: 1920, height: 1080)

    private static let resolution720P = CGSize(width: 1280, height: 720)

    private static let resolution540P = CGSize(width: 960, height: 540)

    private static let resolution360P = CGSize(width: 640, height: 360)

    private var captureSession: AVCaptureSession?

    private var videoInput: AVCaptureDeviceInput?

    private var audioInput: AVCaptureDeviceInput?

    private var stillImageOutput: AVCaptureStillImageOutput?

    private var movieFileOutput: AVCaptureMovieFileOutput?

    private var previewLayer: AVCaptureVideoPreviewLayer?

    private var currentCamera: AVCaptureDevice?

    private var recordTime = 0

    private var recordTimer: Timer?

    private var outputFileURL: URL?

    private var minDuration = 0

    private var maxDuration = 0

    private var videoBitrate = 0

    private var videoFPS = 0

    private var isFrontCamera = false

    private var videoResolution: CGSize = .zero

    @discardableResult
    override func startCameraCustom(_ configDict: [String: Any], preview: UIView) -> Int {
        print("start camera custom")
        if captureSession != nil {
            print("start camera already")
            return 0
        }

        isFrontCamera = (configDict["frontCamera"] as? NSNumber)?.boolValue ?? false
        minDuration = Self.intValue(configDict["minDuration"]) * Self.millisecondsPerSecond
        maxDuration = Self.intValue(configDict["maxDuration"]) * Self.millisecondsPerSecond
        videoFPS = Self.intValue(configDict["videoFPS"])
        videoBitrate = Self.intValue(configDict["videoBitratePIN"]) * Self.bitrateUnit
        let compress = Self.intValue(configDict["videoResolution"])
        videoResolution = getResolutionFromCompress(VideoRecordResolution(rawValue: compress))

        let session = AVCaptureSession()
        session.sessionPreset = .high
        captureSession = session

        session.beginConfiguration()
        if !setupVideoInput() || !setupAudioInput() || !setupVideoOutput() || !setupImageOutput() {
            session.commitConfiguration()
            print("start camera setup fail")
            return -1
        }
        setVideoResolution(videoResolution)
        setVideoFrameRate(videoFPS)
        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupPreview(preview)
            DispatchQueue.global(qos: .default).async {
                self.captureSession?.startRunning()
            }
        }
        return 0
    }

    @discardableResult
    override func switchCamera(_ isFront: Bool) -> Bool {
        print("switch camera isFront:\(isFront)")
        if isFront == isFrontCamera {
            return true
        }
        isFrontCamera = isFront

        guard let session = captureSession, session.isRunning else {
            return false
        }

        session.beginConfiguration()
        if let videoInput = videoInput {
            session.removeInput(videoInput)
        }
        currentCamera = nil
        if !setupVideoInput() {
            print("Failed to switch to \(isFront ? "front" : "back") camera, restore to \(!isFront ? "front" : "back") camera")
            isFrontCamera = !isFront
            setupVideoInput()
        }
        session.commitConfiguration()
        return true
    }

    @discardableResult
    override func toggleTorch(_ enable: Bool) -> Bool {
        guard let camera = currentCamera, camera.hasTorch,
              (try? camera.lockForConfiguration()) != nil else {
            return false
        }
        camera.torchMode = enable ? .on : .off
        camera.unlockForConfiguration()
        return true
    }

    override func setZoom(_ distance: CGFloat) {
        guard let camera = currentCamera else { return }
        let maxZoom = camera.activeFormat.videoMaxZoomFactor
        let zoomFactor = min(max(distance, 1.0), maxZoom)
        guard (try? camera.lockForConfiguration()) != nil else { return }
        camera.videoZoomFactor = zoomFactor
        camera.unlockForConfiguration()
    }

    override func stopCameraPreview() {
        print("stopCameraPreview")
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
        captureSession = nil
        currentCamera = nil
        movieFileOutput = nil
        stillImageOutput = nil
    }

    @discardableResult
    override func startRecord(_ path: String?) -> Int {
        guard let path = path else { return -1 }
        if movieFileOutput?.isRecording == true {
            return -1
        }

        let url = URL(fileURLWithPath: path)
        outputFileURL = url
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }

        setVideoBitrate(videoBitrate)
        movieFileOutput?.startRecording(to: url, recordingDelegate: self)

        recordTime = 0
        recordTimer = Timer.scheduledTimer(timeInterval: Self.recordTimerInterval, target: self,
                                           selector: #selector(updateRecordTime), userInfo: nil, repeats: true)
        return 0
    }

    @discardableResult
    override func stopRecord() -> Int {
        guard let output = movieFileOutput, output.isRecording else {
            return -1
        }
        output.stopRecording()
        recordTimer?.invalidate()
        recordTimer = nil
        return 0
    }

    @discardableResult
    override func snapshot(_ snapshotCompletionBlock: @escaping (UIImage?) -> Void) -> Int {
        guard captureSession?.isRunning == true else {
            snapshotCompletionBlock(nil)
            return -1
        }
        guard let stillImageOutput = stillImageOutput else {
            snapshotCompletionBlock(nil)
            return -2
        }
        let videoConnection = stillImageOutput.connections.first { connection in
            connection.inputPorts.contains { $0.mediaType == .video }
        }
        guard let videoConnection = videoConnection else {
            snapshotCompletionBlock(nil)
            return -3
        }

        videoConnection.isVideoMirrored = isFrontCamera
        stillImageOutput.captureStillImageAsynchronously(from: videoConnection) { sampleBuffer, error in
            var image: UIImage?
            if error == nil, let sampleBuffer = sampleBuffer,
               let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer) {
                image = UIImage(data: imageData)
            }
            snapshotCompletionBlock(image)
        }
        return 0
    }

    @objc private func updateRecordTime() {
        recordTime += Self.recordTimerStepMs
        recordDelegate?.onRecordProgress(recordTime)

        if recordTime > maxDuration {
            print("Reaching maximum recording time")
            stopRecord()
        }
    }

    @discardableResult
    private func setupVideoInput() -> Bool {
        guard let session = captureSession else { return false }
        if currentCamera != nil {
            return true
        }

        currentCamera = getCaptureDevice(isFrontCamera)
        guard let camera = currentCamera else { return false }

        videoInput = try? AVCaptureDeviceInput(device: camera)
        guard let input = videoInput else { return false }

        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        return true
    }

    private func getCaptureDevice(_ isFront: Bool) -> AVCaptureDevice? {
        let position: AVCaptureDevice.Position = isFront ? .front : .back
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInDualCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
        return session.devices.first
    }

    private func setupAudioInput() -> Bool {
        guard let session = captureSession else { return false }
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return false }

        audioInput = try? AVCaptureDeviceInput(device: audioDevice)
        guard let input = audioInput else { return false }

        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        return true
    }

    private func setupVideoOutput() -> Bool {
        if movieFileOutput != nil {
            return true
        }
        let output = AVCaptureMovieFileOutput()
        movieFileOutput = output
        guard let session = captureSession, session.canAddOutput(output) else { return false }
        session.addOutput(output)
        return true
    }

    private func setupImageOutput() -> Bool {
        if stillImageOutput != nil {
            return true
        }
        let output = AVCaptureStillImageOutput()
        output.outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.jpeg,
            AVVideoQualityKey: Self.jpegQuality
        ]
        stillImageOutput = output
        guard let session = captureSession, session.canAddOutput(output) else { return false }
        session.addOutput(output)
        return true
    }

    private func setupPreview(_ preview: UIView) {
        guard let session = captureSession else { return }
        previewLayer?.removeFromSuperlayer()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = preview.bounds
        preview.layer.addSublayer(layer)
        preview.layer.masksToBounds = true
        previewLayer = layer
    }

    private func setVideoResolution(_ resolution: CGSize) {
        guard let session = captureSession else { return }
        if resolution == Self.resolution1080P {
            session.sessionPreset = .hd1920x1080
            return
        }
        if resolution == Self.resolution720P {
            session.sessionPreset = .hd1280x720
            return
        }

        session.sessionPreset = .inputPriority
        guard let camera = currentCamera, (try? camera.lockForConfiguration()) != nil else { return }
        let matchedFormat = camera.formats.first { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return CGFloat(dimensions.width) == resolution.width && CGFloat(dimensions.height) == resolution.height
        }
        if let matchedFormat = matchedFormat {
            camera.activeFormat = matchedFormat
        }
        camera.unlockForConfiguration()
    }

    private func setVideoBitrate(_ bitrate: Int) {
        guard let output = movieFileOutput, let videoConnection = output.connection(with: .video) else { return }
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate
            ]
        ]
        output.setOutputSettings(videoSettings, for: videoConnection)
    }

    private func setVideoFrameRate(_ frameRate: Int) {
        guard let camera = currentCamera else { return }
        do {
            try camera.lockForConfiguration()
        } catch {
            print("lock for configuration fail.error: \(error)")
            return
        }

        let targetFrameRate = Double(frameRate)
        let desiredRange = camera.activeFormat.videoSupportedFrameRateRanges.first { range in
            range.minFrameRate <= targetFrameRate && targetFrameRate <= range.maxFrameRate
        }
        if desiredRange != nil {
            let frameDuration = CMTime(value: 1, timescale: Int32(frameRate))
            camera.activeVideoMinFrameDuration = frameDuration
            camera.activeVideoMaxFrameDuration = frameDuration
        } else {
            print("do not surpport \(frameRate) fps")
        }
        camera.unlockForConfiguration()
    }

    private func getResolutionFromCompress(_ compress: VideoRecordResolution?) -> CGSize {
        switch compress {
        case .resolution360x640?:
            return Self.resolution360P
        case .resolution540x960?:
            return Self.resolution540P
        case .resolution720x1280?:
            return Self.resolution720P
        default:
            return Self.resolution1080P
        }
    }

    private static func intValue(_ value: Any?) -> Int {
        return (value as? NSNumber)?.intValue ?? 0
    }
}

extension SystemVideoRecordCore: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        recordTimer?.invalidate()
        recordTimer = nil

        let videoRecordResult = VideoRecordResult()
        videoRecordResult.retCode = recordTime > maxDuration ? .okBeyondMaxDuration : .ok
        videoRecordResult.videoPath = outputFileURL.path

        if error != nil {
            videoRecordResult.retCode = .failed
            videoRecordResult.videoPath = nil
        }

        recordDelegate?.onRecordComplete(videoRecordResult)
    }
}
