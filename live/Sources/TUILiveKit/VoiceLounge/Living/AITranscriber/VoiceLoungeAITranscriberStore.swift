import AtomicXCore
import Combine
import Foundation

@MainActor final class VoiceLoungeAITranscriberStore {
    struct Line: Equatable {
        let id: String
        let speaker: String
        let text: String
    }

    static let maxLines = 3

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }
    private(set) var lines: [Line] = []
    var isEnabled: Bool { settings.isTranscriberEnabled }

    private let settings: VoiceLoungeSettings
    private let changeSubject = PassthroughSubject<Void, Never>()
    private var store: AITranscriberStore?
    private var liveID = ""
    private var isTranscribing = false
    private var cancellables = Set<AnyCancellable>()
    private var activeCancellables = Set<AnyCancellable>()

    init(settings: VoiceLoungeSettings) {
        self.settings = settings
        settings.changes.map { [weak settings] in settings?.isTranscriberEnabled ?? false }.removeDuplicates().sink {
            [weak self] _ in
            self?.syncTranscription()
            self?.changeSubject.send()
        }.store(in: &cancellables)
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
    }

    func deactivate() {
        activeCancellables.removeAll()
        if isTranscribing { store?.stopTranscription(completion: nil) }
        isTranscribing = false
        store = nil
        liveID = ""
        clearLines()
    }

    private func syncTranscription() {
        guard let store else { return }
        if isEnabled, !isTranscribing {
            isTranscribing = true
            let liveID = liveID
            store.startTranscription(myLanguage: .chineseEnglish) { [weak self] result in
                guard case .failure(let error) = result else { return }
                LiveKitLog.error(
                    "[VoiceLounge] startTranscription failed liveID=\(liveID) code=\(error.code) message=\(error.message)"
                )
                Task { @MainActor in self?.isTranscribing = false }
            }
        } else if !isEnabled, isTranscribing {
            isTranscribing = false
            store.stopTranscription(completion: nil)
            clearLines()
        }
    }

    private func clearLines() {
        guard !lines.isEmpty else { return }
        lines = []
        changeSubject.send()
    }

    private func apply(_ list: [TranscriberMessage]) {
        let next = list.sorted { $0.timestamp < $1.timestamp }.suffix(Self.maxLines).compactMap { message -> Line? in
            let text = message.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let speaker = message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName
            return Line(id: message.segmentId, speaker: speaker, text: text)
        }
        guard next != lines else { return }
        lines = next
        changeSubject.send()
    }
}
