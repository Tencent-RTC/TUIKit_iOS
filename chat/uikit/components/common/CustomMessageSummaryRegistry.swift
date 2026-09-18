import Foundation
import AtomicXCore

final class CustomMessageSummaryRegistry {
    static let shared = CustomMessageSummaryRegistry()

    private let lock = NSLock()

    private var providers: [String: (CustomMessagePayload) -> String?] = [:]

    private var matchers: [(CustomMessagePayload) -> String?] = []

    private init() {}

    func register(businessID: String, summaryProvider: @escaping (CustomMessagePayload) -> String?) {
        lock.lock()
        defer { lock.unlock() }
        providers[businessID] = summaryProvider
    }

    func registerMatcher(_ summaryProvider: @escaping (CustomMessagePayload) -> String?) {
        lock.lock()
        defer { lock.unlock() }
        matchers.append(summaryProvider)
    }

    func summary(for payload: CustomMessagePayload) -> String? {
        // 拍快照后释放锁再执行闭包，避免 matcher/provider 内部重入注册造成死锁
        lock.lock()
        let matchersSnapshot = matchers
        let providersSnapshot = providers
        lock.unlock()

        for matcher in matchersSnapshot {
            if let summary = matcher(payload), !summary.isEmpty {
                return summary
            }
        }
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String else {
            return nil
        }
        return providersSnapshot[businessID]?(payload)
    }
}
