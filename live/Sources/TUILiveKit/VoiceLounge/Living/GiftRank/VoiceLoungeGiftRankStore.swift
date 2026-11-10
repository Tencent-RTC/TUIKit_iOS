import AtomicXCore
import Combine
import Foundation

@MainActor final class VoiceLoungeGiftRankStore {
    struct Entry: Equatable, Codable {
        let userID: String
        let name: String
        let avatarURL: String
        var coins: UInt

        enum CodingKeys: String, CodingKey { case userID = "u", name = "n", avatarURL = "a", coins = "c" }
    }

    static let metaKey = "vl_rank"
    static let countMetaKey = "vl_gift_count"
    private static let maxPublishedEntries = 20
    private static let maxPublishedBytes = 3800

    var onPublish: (() -> Void)?

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

    private let changeSubject = PassthroughSubject<Void, Never>()
    private var liveID = ""
    private var store: GiftStore?
    private var role: VoiceLoungeRole = .audience
    private var hostUserID = ""
    private var localTotals: [String: Entry] = [:]
    private var remoteRanking: [Entry]?
    private var localGiftCount = 0
    private var remoteGiftCount: Int?
    private var cancellables = Set<AnyCancellable>()
    private var publishWork: DispatchWorkItem?
    private var refreshWork: DispatchWorkItem?
    private var refreshToken = 0

    var ranking: [Entry] {
        if role == .audience, let remoteRanking { return remoteRanking }
        return localRanking
    }

    private var localRanking: [Entry] { localTotals.values.sorted { $0.coins > $1.coins } }

    var giftCount: Int {
        if role == .audience, let remoteGiftCount { return max(remoteGiftCount, localGiftCount) }
        return localGiftCount
    }

    func activate(liveID: String, role: VoiceLoungeRole, hostUserID: String) {
        guard !liveID.isEmpty, store == nil else { return }
        self.role = role
        self.liveID = liveID
        self.hostUserID = hostUserID
        let store = GiftStore.create(liveID: liveID)
        self.store = store
        store.giftEventPublisher.receive(on: DispatchQueue.main).sink { [weak self] event in self?.handle(event) }
            .store(in: &cancellables)
        guard role == .audience else { return }
        LiveListStore.shared.state.subscribe().map(\.currentLive).filter { $0.liveID == liveID }.map(\.metaData)
            .receive(on: DispatchQueue.main).sink { [weak self] metaData in self?.applyRemote(metaData: metaData) }
            .store(in: &cancellables)
        refresh()
    }

    func updateHostUserID(_ userID: String) {
        guard !userID.isEmpty, userID != hostUserID else { return }
        hostUserID = userID
    }

    func deactivate() {
        cancellables.removeAll()
        publishWork?.cancel()
        refreshWork?.cancel()
        refreshToken += 1
        store = nil
        liveID = ""
        localTotals = [:]
        remoteRanking = nil
        localGiftCount = 0
        remoteGiftCount = nil
        changeSubject.send()
    }

    func refresh() {
        guard role == .audience, !liveID.isEmpty else { return }
        refreshToken += 1
        let token = refreshToken
        let liveID = liveID
        LiveListStore.shared.queryMetaData(keys: [Self.metaKey, Self.countMetaKey]) { [weak self] result in
            Task { @MainActor in
                guard let self, token == self.refreshToken else { return }
                switch result {
                case .success(let metaData): self.applyRemote(metaData: metaData)
                case .failure(let error):
                    LiveKitLog.error(
                        "[VoiceLounge] query gift rank failed liveID=\(liveID) code=\(error.code) message=\(error.message)"
                    )
                }
            }
        }
    }

    private func applyRemote(metaData: [String: String]) {
        guard role == .audience else { return }
        if let raw = metaData[Self.countMetaKey], let count = Int(raw), count != remoteGiftCount {
            remoteGiftCount = count
            changeSubject.send()
        }
        guard let raw = metaData[Self.metaKey], let data = raw.data(using: .utf8),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return }
        let sorted = entries.sorted { $0.coins > $1.coins }
        guard sorted != remoteRanking else { return }
        remoteRanking = sorted
        changeSubject.send()
    }

    func publishedMetaData() -> [String: String] {
        var entries = Array(localRanking.prefix(Self.maxPublishedEntries))
        let encoder = JSONEncoder()
        while true {
            guard let data = try? encoder.encode(entries), let json = String(data: data, encoding: .utf8) else {
                return [:]
            }
            if data.count <= Self.maxPublishedBytes || entries.isEmpty {
                return [Self.metaKey: json, Self.countMetaKey: String(localGiftCount)]
            }
            entries.removeLast()
        }
    }

    private func handle(_ event: GiftEvent) {
        guard case let .onReceiveGiftWithReceiver(_, gift, count, sender, receiver) = event else { return }
        let receiverID = receiver?.userID ?? ""
        let receivedByHost = receiverID.isEmpty || hostUserID.isEmpty || receiverID == hostUserID
        guard receivedByHost, !sender.userID.isEmpty else { return }
        let add = gift.coins * count
        localGiftCount += Int(count)
        if var entry = localTotals[sender.userID] {
            entry.coins += add
            localTotals[sender.userID] = entry
        } else {
            localTotals[sender.userID] = Entry(
                userID: sender.userID, name: sender.userName.isEmpty ? sender.userID : sender.userName,
                avatarURL: sender.avatarURL, coins: add)
        }

        switch role {
        case .host:
            changeSubject.send()
            schedulePublish()
        case .audience:
            changeSubject.send()
            scheduleRefresh()
        }
    }

    private func schedulePublish() {
        publishWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onPublish?() }
        publishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func scheduleRefresh() {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}
