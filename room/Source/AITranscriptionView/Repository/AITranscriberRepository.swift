//
//  AITranscriberRepository.swift
//  AITranscriptionView
//

import Foundation
import Combine
import AtomicXCore

// MARK: - Event

/// Data change events published by the repository for view-layer consumption.
public enum AISubtitleDataEvent {
    case added(AITranscriptionData)
    case updated(AITranscriptionData)
    case completed(AITranscriptionData)
    case clearedAll
}

// MARK: - AITranscriberRepository

/// Subscribes to `AITranscriberStore.realtimeMessageList`, converts `TranscriberMessage`
/// to `AITranscriptionData`, and publishes events via Combine for the view layer.
public class AITranscriberRepository {
    
    // MARK: - Published Properties
    
    /// Event stream consumed by `AISubtitleView` / `AIMinutesView`.
    public let subtitleEventSubject = PassthroughSubject<AISubtitleDataEvent, Never>()
    
    public private(set) var subtitleDataMap: [String: AITranscriptionData] = [:]
    public private(set) var orderedSegmentIds: [String] = []
    
    public let sourceLanguageList: [SourceLanguage] = [
        .chineseEnglish,
        .chinese,
        .english,
        .cantonese,
        .vietnamese,
        .japanese,
        .korean,
        .indonesian,
        .thai,
        .portuguese,
        .turkish,
        .arabic,
        .spanish,
        .hindi,
        .french,
        .malay,
        .filipino,
        .german,
        .italian,
        .russian,
    ]
    
    public let translationLanguageList: [TranslationLanguage?] = [
        nil,
        .chinese,
        .english,
        .vietnamese,
        .japanese,
        .korean,
        .indonesian,
        .thai,
        .portuguese,
        .arabic,
        .spanish,
        .french,
        .malay,
        .german,
        .italian,
        .russian,
    ]
    
    @Published public private(set) var selectedSourceLanguage: SourceLanguage = .chineseEnglish
    @Published public private(set) var selectedTranslationLanguage: TranslationLanguage? = .english
    @Published public var isBilingualEnabled: Bool = true
    
    // MARK: - Properties
    
    private let transcriberStore: AITranscriberStore
    private let roomID: String
    private(set) var isTranscriptionStart: Bool = false
    private(set) var currentConfig: TranscriberConfig?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(roomID: String) {
        self.roomID = roomID
        transcriberStore = AITranscriberStore.create(roomID: roomID)
        subscribeToTranscriberState()
    }
    
    deinit {
        clearAllData()
        cancellables.removeAll()
    }
    
    // MARK: - Transcription Control
    
    public func startTranscription(completion: CompletionClosure? = nil) {
        let config = TranscriberConfig(sourceLanguage: selectedSourceLanguage, translationLanguages: selectedTranslationLanguage.map { [$0] } ?? [])
        transcriberStore.startRealtimeTranscriber(config: config, completion: completion)
        currentConfig = config
    }
    
    public func updateTranscription(sourceLanguage: SourceLanguage, completion: CompletionClosure? = nil) {
        guard var config = currentConfig else {
            completion?(.failure(ErrorInfo(code: -1, message: String.enableTranscriptionFirst)))
            return
        }
        config.sourceLanguage = sourceLanguage
        selectedSourceLanguage = sourceLanguage
        transcriberStore.updateRealtimeTranscriber(config: config, completion: completion)
        currentConfig = config
    }
    
    public func updateTranscription(translationLanguage: TranslationLanguage?, completion: CompletionClosure? = nil) {
        guard var config = currentConfig else {
            completion?(.failure(ErrorInfo(code: -1, message: String.enableTranscriptionFirst)))
            return
        }
        config.translationLanguages = translationLanguage.map { [$0] } ?? []
        selectedTranslationLanguage = translationLanguage
        transcriberStore.updateRealtimeTranscriber(config: config, completion: completion)
        currentConfig = config
    }
    
    public func stopTranscription(completion: CompletionClosure? = nil) {
        transcriberStore.stopRealtimeTranscriber(completion: completion)
        currentConfig = nil
    }
    
    // MARK: - Data Access
    
    public func getData(for segmentId: String) -> AITranscriptionData? {
        return subtitleDataMap[segmentId]
    }
    
    /// Returns the localized display name for the given source language.
    public func displayName(for sourceLanguage: SourceLanguage) -> String {
        switch sourceLanguage {
        case .chineseEnglish:
            return "roomkit_transcription_auto_detect_chinese_english".localized
        case .chinese:
            return "roomkit_transcription_speaking_chinese".localized
        case .english:
            return "roomkit_transcription_speaking_english".localized
        case .cantonese:
            return "roomkit_transcription_speaking_cantonese".localized
        case .vietnamese:
            return "roomkit_transcription_speaking_vietnamese".localized
        case .japanese:
            return "roomkit_transcription_speaking_japanese".localized
        case .korean:
            return "roomkit_transcription_speaking_korean".localized
        case .indonesian:
            return "roomkit_transcription_speaking_indonesian".localized
        case .thai:
            return "roomkit_transcription_speaking_thai".localized
        case .portuguese:
            return "roomkit_transcription_speaking_portuguese".localized
        case .turkish:
            return "roomkit_transcription_speaking_turkish".localized
        case .arabic:
            return "roomkit_transcription_speaking_arabic".localized
        case .spanish:
            return "roomkit_transcription_speaking_spanish".localized
        case .hindi:
            return "roomkit_transcription_speaking_hindi".localized
        case .french:
            return "roomkit_transcription_speaking_french".localized
        case .malay:
            return "roomkit_transcription_speaking_malay".localized
        case .filipino:
            return "roomkit_transcription_speaking_filipino".localized
        case .german:
            return "roomkit_transcription_speaking_german".localized
        case .italian:
            return "roomkit_transcription_speaking_italian".localized
        case .russian:
            return "roomkit_transcription_speaking_russian".localized
        }
    }
    
    /// Returns the localized display name for the given translation language.
    public func displayName(for translationLanguage: TranslationLanguage?) -> String {
        guard let language = translationLanguage else {
            return "roomkit_transcription_no_translation".localized
        }
        switch language {
        case .chinese:     return "roomkit_transcription_language_chinese".localized
        case .english:     return "roomkit_transcription_language_english".localized
        case .vietnamese:  return "roomkit_transcription_language_vietnamese".localized
        case .japanese:    return "roomkit_transcription_language_japanese".localized
        case .korean:      return "roomkit_transcription_language_korean".localized
        case .indonesian:  return "roomkit_transcription_language_indonesian".localized
        case .thai:        return "roomkit_transcription_language_thai".localized
        case .portuguese:  return "roomkit_transcription_language_portuguese".localized
        case .arabic:      return "roomkit_transcription_language_arabic".localized
        case .spanish:     return "roomkit_transcription_language_spanish".localized
        case .french:      return "roomkit_transcription_language_french".localized
        case .malay:       return "roomkit_transcription_language_malay".localized
        case .german:      return "roomkit_transcription_language_german".localized
        case .italian:     return "roomkit_transcription_language_italian".localized
        case .russian:     return "roomkit_transcription_language_russian".localized
        }
    }
    
    // MARK: - State Subscription
    
    private func subscribeToTranscriberState() {
        cancellables.removeAll()
        
        let selector = StatePublisherSelector<TranscriberState, [TranscriberMessage]>(
            keyPath: \.realtimeMessageList
        )
        
        transcriberStore.state
            .subscribe(selector)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messageList in
                guard let self = self else { return }
                self.processMessageListUpdate(messageList)
            }
            .store(in: &cancellables)
        
        transcriberStore.aiTranscriberEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onRealtimeTranscriberStarted(let roomID, _):
                    if self.roomID == roomID {
                        isTranscriptionStart = true
                    }
                case .onRealtimeTranscriberStopped(let roomID, _, _):
                    if self.roomID == roomID {
                        isTranscriptionStart = false
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)

    }
    
    private func processMessageListUpdate(_ messageList: [TranscriberMessage]) {
        let groups = groupMessages(messageList)
        for groupData in groups {
            let groupId = groupData.segmentId
            if let existingData = subtitleDataMap[groupId] {
                guard groupData != existingData else { continue }
                subtitleDataMap[groupId] = groupData
                subtitleEventSubject.send(groupData.isCompleted ? .completed(groupData) : .updated(groupData))
            } else {
                subtitleDataMap[groupId] = groupData
                orderedSegmentIds.append(groupId)
                subtitleEventSubject.send(.added(groupData))
                if groupData.isCompleted {
                    subtitleEventSubject.send(.completed(groupData))
                }
            }
        }
    }
    
    // MARK: - Message Grouping
    
    /// Groups messages by: filter → sort → merge (same speaker + 60s time window).
    private func groupMessages(_ messageList: [TranscriberMessage]) -> [AITranscriptionData] {
        // Step 1: Filter — keep messages with displayable sourceText and valid timestamp
        let filtered = messageList.filter { message in
            let hasContent = !message.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasValidTimestamp = message.timestamp > 0 && message.timestamp < Int64.max
            return hasContent && hasValidTimestamp
        }
        
        // Step 2: Sort by timestamp ascending
        let sorted = filtered.sorted { $0.timestamp < $1.timestamp }
        
        // Step 3: Group by same speaker + 60s time window
        var groups: [AITranscriptionData] = []
        
        for message in sorted {
            guard let data = convertToSubtitleData(message) else { continue }
            
            if let lastGroup = groups.last,
               lastGroup.speakerUserId == data.speakerUserId,
               abs(data.timestamp - lastGroup.timestamp) <= 60 {
                // Merge into existing group
                var merged = lastGroup
                merged.sourceText += "\n" + data.sourceText
                if !data.translationText.isEmpty {
                    if merged.translationText.isEmpty {
                        merged.translationText = data.translationText
                    } else {
                        merged.translationText += "\n" + data.translationText
                    }
                }
                merged.isCompleted = data.isCompleted
                groups[groups.count - 1] = merged
            } else {
                // Start a new group (uses this message's segmentId as group ID)
                groups.append(data)
            }
        }
        
        return groups
    }
    
    private func clearAllData() {
        subtitleDataMap.removeAll()
        orderedSegmentIds.removeAll()
        subtitleEventSubject.send(.clearedAll)
    }
    
    // MARK: - Data Conversion
    
    private func convertToSubtitleData(_ message: TranscriberMessage) -> AITranscriptionData? {
        let translationText = message.translationTexts.first?.value ?? ""
        return AITranscriptionData(
            segmentId: message.segmentId,
            speakerUserId: message.speakerUserId,
            speakerUserName: message.speakerUserName,
            sourceText: message.sourceText,
            translationText: translationText,
            timestamp: message.timestamp,
            isCompleted: message.isCompleted
        )
    }
}

fileprivate extension String {
    static let enableTranscriptionFirst = "roomkit_transcription_enable_first".localized
}
