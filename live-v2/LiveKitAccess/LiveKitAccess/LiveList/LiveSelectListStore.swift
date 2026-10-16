import AtomicXCore
import Foundation

// 从 TUILiveKit 业务库迁移而来的直播列表数据获取。接入层自行调用 AtomicXCore 的 LiveListStore 拉取分页列表，
// 业务库不再向接入层暴露列表数据接口。
@MainActor
final class LiveSelectListStore {
    struct State {
        var liveList: [LiveInfo] = []
        var isLoading = false
        var canLoadMore = true
        var errorMessage: String?
    }

    var onStateChanged: ((State) -> Void)? {
        didSet { onStateChanged?(state) }
    }

    private(set) var state = State()
    private let liveListStore: LiveListStore
    private let pageSize = 6
    private var requestID = UUID()

    init(liveListStore: LiveListStore = .shared) {
        self.liveListStore = liveListStore
    }

    func refresh() {
        fetch(cursor: "")
    }

    func loadMore() {
        guard state.canLoadMore, !state.isLoading else { return }
        let cursor = liveListStore.state.value.liveListCursor
        guard !cursor.isEmpty else {
            state.canLoadMore = false
            notify()
            return
        }
        fetch(cursor: cursor)
    }

    private func fetch(cursor: String) {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.errorMessage = nil
        requestID = UUID()
        let currentRequestID = requestID
        notify()

        liveListStore.fetchLiveList(cursor: cursor, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.requestID == currentRequestID else { return }
                self.state.isLoading = false
                switch result {
                case .success:
                    let sdkState = self.liveListStore.state.value
                    self.state.liveList = self.deduplicated(sdkState.liveList)
                    self.state.canLoadMore = !sdkState.liveListCursor.isEmpty
                case .failure(let error):
                    self.state.errorMessage = Self.errorMessage(error)
                }
                self.notify()
            }
        }
    }

    private func deduplicated(_ list: [LiveInfo]) -> [LiveInfo] {
        var liveIDs = Set<String>()
        return list.filter { liveIDs.insert($0.liveID).inserted }
    }

    private static func errorMessage(_ error: ErrorInfo) -> String {
        let detail = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "AtomicXCore error (\(error.code))" : detail
    }

    private func notify() {
        onStateChanged?(state)
    }
}
