import AVFoundation
import Foundation
import AtomicXCore

struct ListenPlaybackState {
    var isActive = false
    var isLoading = false
    var currentText = ""
}

struct ListenItem {
    let speechText: String
    let audioPath: String?
}

enum ListenPlanBuilder {

    static func build(messages: [MessageInfo]) -> [ListenItem] {
        var items: [ListenItem] = []
        var lastSpeakerKey: String?
        for message in messages {
            let speakerKey = message.isSentBySelf ? "self" : "user:\(message.from.userID)"
            let speaker = message.isSentBySelf
                ? LocalizedChatString("VoiceListenSelfSpeaker")
                : MessageListHelper.senderShowName(of: message)
            let sameAsPrevious = lastSpeakerKey == speakerKey
            switch message.messageType {
            case .text:
                guard case .text(let payload) = message.messagePayload else { continue }
                let content = TtsTextSanitizer.shared.sanitize(text: payload.text)
                if content.isEmpty { continue }
                let speechText = sameAsPrevious
                    ? content
                    : String(format: LocalizedChatString("VoiceListenSaysFormat"), speaker) + content
                items.append(ListenItem(speechText: speechText, audioPath: nil))
            case .image:
                items.append(ListenItem(
                    speechText: mediaSpeech(formatKey: "VoiceListenSentImageFormat", speaker: speaker, omitName: sameAsPrevious),
                    audioPath: nil
                ))
            case .video:
                items.append(ListenItem(
                    speechText: mediaSpeech(formatKey: "VoiceListenSentVideoFormat", speaker: speaker, omitName: sameAsPrevious),
                    audioPath: nil
                ))
            case .file:
                items.append(ListenItem(
                    speechText: mediaSpeech(formatKey: "VoiceListenSentFileFormat", speaker: speaker, omitName: sameAsPrevious),
                    audioPath: nil
                ))
            case .merged:
                guard case .merged(let payload) = message.messagePayload else { continue }
                let title = TtsTextSanitizer.shared.sanitize(text: payload.title)
                let name = sameAsPrevious ? "" : speaker
                items.append(ListenItem(
                    speechText: String(format: LocalizedChatString("VoiceListenSentMergedFormat"), name, title)
                        .trimmingCharacters(in: .whitespaces),
                    audioPath: nil
                ))
            case .audio:
                var path: String?
                if case .audio(let payload) = message.messagePayload {
                    if let audioPath = payload.audioPath, !audioPath.isEmpty {
                        path = audioPath
                    } else if let audioURL = payload.audioURL, !audioURL.isEmpty {
                        path = audioURL
                    }
                }
                let speechText = sameAsPrevious
                    ? ""
                    : String(format: LocalizedChatString("VoiceListenSaysFormat"), speaker)
                items.append(ListenItem(speechText: speechText, audioPath: path))
            default:
                continue
            }
            lastSpeakerKey = speakerKey
        }
        return items
    }

    private static func mediaSpeech(formatKey: String, speaker: String, omitName: Bool) -> String {
        let name = omitName ? "" : speaker
        return String(format: LocalizedChatString(formatKey), name)
            .trimmingCharacters(in: .whitespaces)
    }
}

final class ListenFromHereController {
    private(set) var state = ListenPlaybackState() {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ListenPlaybackState) -> Void)?

    private let tts = TtsPlaybackHelper()

    private var audioPlayer: AVPlayer?

    private var audioPlayerItem: AVPlayerItem?

    private var audioEndObserver: NSObjectProtocol?

    private var audioFailedObserver: NSObjectProtocol?

    private var queue: [ListenItem] = []

    private var index = -1

    private var active = false

    private var voiceId = ""

    private var session = 0

    func start(plan: [ListenItem]) {
        stop()
        guard !plan.isEmpty else { return }
        voiceId = VoiceMessageConfig.shared.getSelectedVoiceId()
        queue = plan
        index = 0
        active = true
        session += 1
        let currentSession = session
        state = ListenPlaybackState(isActive: true, isLoading: true, currentText: plan[0].speechText)
        playCurrent(showLoading: true, currentSession: currentSession)
    }

    func stop() {
        let wasActive = active || state.isActive
        active = false
        session += 1
        index = -1
        queue = []
        teardownAudioPlayer()
        tts.stop()
        if wasActive {
            state = ListenPlaybackState()
        }
    }

    deinit {
        teardownAudioPlayer()
    }

    private func playCurrent(showLoading: Bool, currentSession: Int) {
        guard active, currentSession == session, index >= 0, index < queue.count else { return }
        let item = queue[index]
        state.currentText = item.speechText
        state.isLoading = showLoading

        if item.speechText.isEmpty {
            if let audioPath = item.audioPath, !audioPath.isEmpty {
                playAudio(audioPath: audioPath, currentSession: currentSession)
            } else {
                advance(currentSession: currentSession)
            }
            return
        }

        tts.speak(
            text: item.speechText,
            voiceId: voiceId,
            onStart: { [weak self] in
                self?.clearLoading(currentSession: currentSession)
            },
            onComplete: { [weak self] in
                guard let self, self.active, currentSession == self.session else { return }
                if let audioPath = item.audioPath, !audioPath.isEmpty {
                    self.playAudio(audioPath: audioPath, currentSession: currentSession)
                } else {
                    self.advance(currentSession: currentSession)
                }
            },
            onError: { [weak self] _ in
                guard let self, self.active, currentSession == self.session else { return }
                self.advance(currentSession: currentSession)
            }
        )
    }

    private func playAudio(audioPath: String, currentSession: Int) {
        teardownAudioPlayer()
        let url = audioPath.hasPrefix("http") ? URL(string: audioPath) : URL(fileURLWithPath: audioPath)
        guard let url else {
            advance(currentSession: currentSession)
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            advance(currentSession: currentSession)
            return
        }
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .pause

        audioEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.active, currentSession == self.session else { return }
            self.advance(currentSession: currentSession)
        }
        audioFailedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.active, currentSession == self.session else { return }
            self.advance(currentSession: currentSession)
        }

        audioPlayerItem = item
        audioPlayer = avPlayer
        clearLoading(currentSession: currentSession)
        avPlayer.play()
    }

    private func advance(currentSession: Int) {
        guard active, currentSession == session else { return }
        index += 1
        if index >= queue.count {
            stop()
        } else {
            playCurrent(showLoading: false, currentSession: currentSession)
        }
    }

    private func clearLoading(currentSession: Int) {
        guard active, currentSession == session, state.isLoading else { return }
        state.isLoading = false
    }

    private func teardownAudioPlayer() {
        if let audioEndObserver {
            NotificationCenter.default.removeObserver(audioEndObserver)
            self.audioEndObserver = nil
        }
        if let audioFailedObserver {
            NotificationCenter.default.removeObserver(audioFailedObserver)
            self.audioFailedObserver = nil
        }
        audioPlayer?.pause()
        audioPlayer = nil
        audioPlayerItem = nil
    }
}
