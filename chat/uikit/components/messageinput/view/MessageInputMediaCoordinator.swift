import UIKit
import AVFoundation
import AtomicXCore

final class MessageInputMediaCoordinator: NSObject {
    private weak var presentingView: UIView?

    private let viewModel: MessageInputViewModel

    private var voiceOverlay: MessageInputAudioRecorderView?

    private var voiceTranscriptionOverlay: VoiceTranscriptionOverlayView?

    private var speechPlayer: SpeechPlayer?

    private var currentRecordDuration: Int = 0

    private var currentRecordPower: Int = 0

    private var currentGestureState: AudioRecorderRecordUiState = .recording

    private var recordMaxDurationMs: Int {
        return viewModel.config.audioMaxRecordDurationMs
    }

    private var lastReleaseAction: AudioRecorderReleaseAction = .sendAudio

    private static let fileSizeLimit: Int64 = 1_000_000_000

    private static let videoThumbnailCompressionQuality: CGFloat = 0.7

    private static let imageSaveCompressionQuality: CGFloat = 0.8

    private static let toastDuration: TimeInterval = 3

    init(presentingView: UIView, viewModel: MessageInputViewModel) {
        self.presentingView = presentingView
        self.viewModel = viewModel
        super.init()
    }

    func showCamera() {
        showCamera(recordMode: .videoPhotoMix)
    }

    // MARK: - Camera（拍摄/录像，直接 present 命令式 VideoRecorderController）

    func showCamera(recordMode: RecordMode) {
        guard let presenter = findViewController() else { return }

        fetchVideoRecorderSignature()
        VideoRecorderConfigInternal.sharedInstance().setCustomConfig("{\"record_mode\": \(recordMode.rawValue)}")

        let recorder = VideoRecorderController()
        recorder.recordFilePath = makeMediaPath(messageType: .video, withExtension: "mov")
        recorder.modalPresentationStyle = .fullScreen
        recorder.resultCallback = { [weak self, weak recorder] videoPath, image, _ in
            recorder?.dismiss(animated: true)
            guard let self = self else { return }
            if let videoPath = videoPath {
                self.createThumbnailAndSendVideo(videoPath, nil)
                return
            }
            if let image = image, let imagePath = self.saveImage(image) {
                self.viewModel.sendImageMessage(imagePath)
            }
        }
        recorder.photoPreviewOverride = { controller, image in
            VideoRecorderPhotoEditBridge.present(from: controller, image: image, onConfirm: { editedImage in
                controller.resultCallback?(nil, editedImage, 0)
            }, onCancel: {})
        }
        presenter.present(recorder, animated: true)
    }

    // MARK: - File（文件，直接用系统 UIDocumentPickerViewController）

    func showFilePicker() {
        guard let presenter = findViewController() else { return }
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
    }

    // MARK: - Voice（语音，直接驱动命令式 AudioRecorder）

    func beginVoiceRecording() {
        guard voiceOverlay == nil,
              let inputView = presentingView,
              let window = inputView.window else { return }

        let overlay = MessageInputAudioRecorderView(
            frame: window.bounds,
            maxDurationMs: recordMaxDurationMs
        )
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        voiceOverlay = overlay

        let recorder = AudioRecorder.sharedRecorder
        recorder.onRecordTime = { [weak self] milliseconds in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentRecordDuration = milliseconds
                self.voiceOverlay?.update(
                    state: self.currentGestureState,
                    durationMs: self.currentRecordDuration,
                    powerLevel: self.currentRecordPower,
                    maxDurationMs: self.recordMaxDurationMs
                )
            }
        }
        recorder.onPowerLevel = { [weak self] power in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentRecordPower = power
                self.voiceOverlay?.update(
                    state: self.currentGestureState,
                    durationMs: self.currentRecordDuration,
                    powerLevel: self.currentRecordPower,
                    maxDurationMs: self.recordMaxDurationMs
                )
            }
        }
        recorder.onRecordingComplete = { [weak self] resultCode, filePath, duration in
            guard let self = self else { return }
            self.dismissVoiceOverlay()
            self.handleVoiceRecordingComplete(resultCode: resultCode, filePath: filePath, duration: duration)
        }
        NotificationCenter.default.post(name: MessageInputView.voiceRecordStartNotification, object: nil)
        recorder.startRecord()
        overlay.show()
        currentGestureState = .recording
        overlay.update(state: .recording, durationMs: 0, powerLevel: 0, maxDurationMs: recordMaxDurationMs)
    }

    func updateVoiceRecording(finger: CGPoint) {
        guard let overlay = voiceOverlay else { return }
        let action = overlay.releaseAction(for: finger)
        let state: AudioRecorderRecordUiState = action == .cancel
            ? .readyToCancel
            : (action == .transcribe ? .readyToTranscribe : .recording)
        guard state != currentGestureState else { return }
        currentGestureState = state
        overlay.update(
            state: state,
            durationMs: currentRecordDuration,
            powerLevel: currentRecordPower,
            maxDurationMs: recordMaxDurationMs
        )
    }

    func endVoiceRecording(finger: CGPoint) {
        guard let overlay = voiceOverlay else { return }
        let action = overlay.releaseAction(for: finger)
        overlay.dismiss()
        voiceOverlay = nil
        lastReleaseAction = action

        let recorder = AudioRecorder.sharedRecorder
        switch action {
        case .cancel:
            recorder.cancelRecord()
        case .sendAudio, .transcribe:
            recorder.stopRecord()
        }
    }

    // MARK: - Helpers

    private func handleFileSelection(_ fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        let filePath = makeMediaPath(messageType: .file, withExtension: fileName)
        guard let fullFilePath = (filePath as NSString).appendingPathExtension(fileURL.pathExtension) else { return }
        do {
            if FileManager.default.fileExists(atPath: fullFilePath) {
                try FileManager.default.removeItem(atPath: fullFilePath)
            }
            try FileManager.default.copyItem(at: fileURL, to: URL(fileURLWithPath: fullFilePath))
            let attributes = try FileManager.default.attributesOfItem(atPath: fullFilePath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            if fileSize > Self.fileSizeLimit || fileSize == 0 {
                WindowAlertManager.shared.showAlert(
                    message: LocalizedChatString("FileSizeCheckLimited"),
                    confirmText: LocalizedChatString("Confirm")
                )
                return
            }
            viewModel.sendFileMessage(fullFilePath, fileName: fileName, fileSize: Int(fileSize))
        } catch {}
    }

    private func handleVoiceRecordingComplete(resultCode: AudioRecordResultCode, filePath: String, duration: Int) {
        if resultCode == .errorLessThanMinDuration {
            WindowToastManager.shared.show(
                LocalizedChatString("AudioRecorderLessThanMinTime"), type: .warning, duration: Self.toastDuration
            )
        }
        if resultCode == .exceedMaxDuration {
            WindowToastManager.shared.show(
                LocalizedChatString("AudioRecordTimeLimitReached"), type: .warning, duration: Self.toastDuration
            )
        }
        if lastReleaseAction == .transcribe {
            if resultCode.rawValue >= 0, !filePath.isEmpty {
                showVoiceTranscriptionOverlay(filePath: filePath, duration: duration)
            }
            return
        }
        if resultCode.rawValue >= 0, !filePath.isEmpty {
            viewModel.sendVoiceMessage(filePath, duration: duration)
        }
    }

    private func showVoiceTranscriptionOverlay(filePath: String, duration: Int) {
        guard let window = presentingView?.window else { return }
        let callbacks = VoiceTranscriptionCallbacks(
            onCancel: { [weak self] in
                self?.voiceTranscriptionOverlay = nil
            },
            onSendAudio: { [weak self] path, dur in
                self?.voiceTranscriptionOverlay = nil
                self?.viewModel.sendVoiceMessage(path, duration: dur)
            },
            onSendText: { [weak self] text in
                self?.voiceTranscriptionOverlay = nil
                self?.viewModel.sendTextMessage(text)
            },
            onTranslate: { text, language, onSuccess, onFailure in
                AiMediaProcessManager.translateSingleText(
                    text: text, targetLanguage: language,
                    onSuccess: onSuccess,
                    onFailure: { _, _ in onFailure() }
                )
            },
            onStartSpeak: { [weak self] text, onStart, onComplete, onError in
                self?.startSpeak(text: text, onStart: onStart, onComplete: onComplete, onError: onError)
            },
            onStopSpeak: { [weak self] in
                self?.stopSpeak()
            }
        )
        let overlay = VoiceTranscriptionOverlayView(
            frame: window.bounds,
            audioPath: filePath,
            audioDurationSecond: duration,
            text: nil,
            callbacks: callbacks
        )
        voiceTranscriptionOverlay = overlay
        overlay.show(in: window)
        viewModel.convertLocalAudioToText(filePath: filePath) { [weak overlay] text in
            overlay?.updateResult(text)
        }
    }

    private func startSpeak(text: String,
                            onStart: @escaping (TimeInterval) -> Void,
                            onComplete: @escaping () -> Void,
                            onError: @escaping () -> Void) {
        AiMediaProcessManager.convertTextToVoice(text: text,
            onSuccess: { [weak self] url in
                guard let audioURL = URL(string: url) else { onError(); return }
                URLSession.shared.downloadTask(with: audioURL) { localURL, _, error in
                    guard let localURL = localURL, error == nil else { onError(); return }
                    self?.speechPlayer = SpeechPlayer()
                    self?.speechPlayer?.play(
                        url: localURL,
                        onStart: onStart,
                        onComplete: onComplete,
                        onError: onError
                    )
                }.resume()
            },
            onFailure: { _, _ in onError() }
        )
    }

    private func stopSpeak() {
        speechPlayer?.stop()
        speechPlayer = nil
    }

    private func dismissVoiceOverlay() {
        voiceOverlay?.stopAnimating()
        voiceOverlay?.removeFromSuperview()
        voiceOverlay = nil
    }

    private func createThumbnailAndSendVideo(_ videoPath: String, _ videoThumbnailPath: String?) {
        if let thumbnailPath = videoThumbnailPath, !thumbnailPath.isEmpty {
            viewModel.sendVideoMessage(videoPath, snapshotPath: thumbnailPath)
            return
        }
        let generatedPath = makeMediaPath(messageType: .image, withExtension: "jpg")
        if let thumbnail = makeVideoThumbnail(from: URL(fileURLWithPath: videoPath)),
           let imageData = thumbnail.jpegData(compressionQuality: Self.videoThumbnailCompressionQuality) {
            try? imageData.write(to: URL(fileURLWithPath: generatedPath))
        } else {
            try? Data().write(to: URL(fileURLWithPath: generatedPath))
        }
        viewModel.sendVideoMessage(videoPath, snapshotPath: generatedPath)
    }

    private func makeVideoThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(
            at: CMTime(seconds: 0, preferredTimescale: 60), actualTime: nil
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func saveImage(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: Self.imageSaveCompressionQuality) else { return nil }
        let path = makeMediaPath(messageType: .image, withExtension: "png")
        try? imageData.write(to: URL(fileURLWithPath: path))
        return path
    }

    private func makeMediaPath(messageType: MessageType, withExtension: String?) -> String {
        let path = ChatUtil.generateMediaPath(messageType: messageType, withExtension: withExtension)
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return path
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = presentingView
        while let next = responder?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            responder = next
        }
        return nil
    }
}

// MARK: - 朗读播放器（TTS 结果音频播放，对齐 Android `TtsPlaybackHelper`）

private final class SpeechPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    private var onComplete: (() -> Void)?

    private var onError: (() -> Void)?

    func play(url: URL,
              onStart: @escaping (TimeInterval) -> Void,
              onComplete: @escaping () -> Void,
              onError: @escaping () -> Void) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            self.onComplete = onComplete
            self.onError = onError
            player.delegate = self
            if player.play() {
                onStart(player.duration)
            } else {
                onError()
            }
        } catch {
            onError()
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            onComplete?()
        } else {
            onError?()
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension MessageInputMediaCoordinator: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let securityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        handleFileSelection(url)
    }
}
