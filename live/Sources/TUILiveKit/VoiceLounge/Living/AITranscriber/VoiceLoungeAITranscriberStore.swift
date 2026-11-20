import AtomicXCore
import Combine
import Foundation

@MainActor final class VoiceLoungeAITranscriberStore {
    struct Line: Equatable {
        let speakerId: String
        let speaker: String
        let translated: String
        let source: String
        let updatedAt: TimeInterval
    }

    static let maxSpeakers = 2
    static let lineTTL: TimeInterval = 3
    static let hintDuration: TimeInterval = 3

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }
    private(set) var lines: [Line] = []
    private(set) var isHintActive = false

    var isEnabled: Bool { settings.isTranscriberEnabled }
    var showOriginal: Bool { settings.transcriberShowOriginal }
    var scale: VoiceLoungeTranscriberScale { settings.transcriberScale }
    var targetLanguage: TranslationLanguage { settings.transcriberLanguage }
    var isVisible: Bool { isEnabled }

    private let settings: VoiceLoungeSettings
    private let changeSubject = PassthroughSubject<Void, Never>()
    private var store: AITranscriberStore?
    private var liveID = ""
    private var isTranscribing = false
    private var lastEnabled = false
    private var lastLanguage: TranslationLanguage = .english
    private var cancellables = Set<AnyCancellable>()
    private var activeCancellables = Set<AnyCancellable>()
    private var cleanupTimer: Timer?
    private var hintTimer: Timer?

    init(settings: VoiceLoungeSettings) {
        self.settings = settings
        self.lastEnabled = settings.isTranscriberEnabled
        self.lastLanguage = settings.transcriberLanguage
        settings.changes.sink { [weak self] in self?.handleSettingsChanged() }.store(in: &cancellables)
    }

    func activate(liveID: String) {
        guard !liveID.isEmpty, store == nil else { return }
        self.liveID = liveID
        let store = AITranscriberStore.create(roomID: liveID)
        self.store = store
        store.state.subscribe(StatePublisherSelector(keyPath: \TranscriberState.realtimeMessageList)).receive(
            on: DispatchQueue.main
        ).sink { [weak self] list in self?.apply(list) }.store(in: &activeCancellables)
        syncTranscription()
        if isEnabled { startHint() }
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.cleanupExpired() }
        }
    }

    func deactivate() {
        activeCancellables.removeAll()
        if isTranscribing { store?.stopTranscription(completion: nil) }
        isTranscribing = false
        store = nil
        liveID = ""
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        hintTimer?.invalidate()
        hintTimer = nil
        isHintActive = false
        clearLines()
    }

    func dismissHint() {
        guard isHintActive else { return }
        isHintActive = false
        changeSubject.send()
    }

    private func handleSettingsChanged() {
        let enabled = settings.isTranscriberEnabled
        let language = settings.transcriberLanguage
        let enableChanged = enabled != lastEnabled
        let langChanged = language != lastLanguage
        if !enableChanged && !langChanged {
            changeSubject.send()
            return
        }
        lastEnabled = enabled
        lastLanguage = language
        syncTranscription()
        if !enabled { clearLines() }
        if enableChanged, enabled { startHint() }
        changeSubject.send()
    }

    private func startHint() {
        guard store != nil else { return }
        guard !isHintActive else { return }
        isHintActive = true
        changeSubject.send()
        hintTimer?.invalidate()
        hintTimer = Timer.scheduledTimer(withTimeInterval: Self.hintDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.isHintActive else { return }
                self.isHintActive = false
                self.changeSubject.send()
            }
        }
    }

    private func syncTranscription() {
        guard let store else { return }
        if isEnabled, !isTranscribing {
            isTranscribing = true
            let liveID = liveID
            store.startTranscription(myLanguage: .chineseEnglish, config: TranscriptionConfig(enableTranslation: true))
            { [weak self] result in
                guard case .failure(let error) = result else { return }
                LiveKitLog.error(
                    "[VoiceLounge] startTranscription failed liveID=\(liveID) code=\(error.code) message=\(error.message)"
                )
                Task { @MainActor in self?.isTranscribing = false }
            }
        } else if isEnabled, isTranscribing {
            store.updateTranscription(
                myLanguage: .chineseEnglish, config: TranscriptionConfig(enableTranslation: true), completion: nil)
        } else if !isEnabled, isTranscribing {
            isTranscribing = false
            store.stopTranscription(completion: nil)
        }
    }

    private func clearLines() {
        guard !lines.isEmpty else { return }
        lines = []
        changeSubject.send()
    }

    private func cleanupExpired() {
        guard !lines.isEmpty else { return }
        let cutoff = Date().timeIntervalSince1970 - Self.lineTTL
        let filtered = lines.filter { $0.updatedAt >= cutoff }
        guard filtered.count != lines.count else { return }
        lines = filtered
        changeSubject.send()
    }

    private func apply(_ list: [TranscriberMessage]) {
        guard isEnabled else { return }
        let sorted = list.sorted { $0.timestamp < $1.timestamp }
        let now = Date().timeIntervalSince1970
        var ordered: [(String, Line)] = lines.map { ($0.speakerId, $0) }
        for message in sorted {
            let source = message.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            let translated = (message.translationTexts[targetLanguage] ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines)
            let primary = translated.isEmpty ? source : translated
            guard !primary.isEmpty else { continue }
            let speakerId = message.speakerUserId.isEmpty ? message.speakerUserName : message.speakerUserId
            guard !speakerId.isEmpty else { continue }
            let display = message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName
            ordered.removeAll { $0.0 == speakerId }
            ordered.append(
                (
                    speakerId,
                    Line(speakerId: speakerId, speaker: display, translated: translated, source: source, updatedAt: now)
                ))
        }
        let newLines = Array(ordered.suffix(Self.maxSpeakers).map { $0.1 })
        guard newLines != lines else { return }
        lines = newLines
        if isHintActive {
            isHintActive = false
            hintTimer?.invalidate()
            hintTimer = nil
        }
        changeSubject.send()
    }
}
