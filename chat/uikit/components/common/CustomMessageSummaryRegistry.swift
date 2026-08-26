import Foundation
import AtomicXCore

final class CustomMessageSummaryRegistry {
    static let shared = CustomMessageSummaryRegistry()

    private var providers: [String: (CustomMessagePayload) -> String?] = [:]

    private init() {}

    func register(businessID: String, summaryProvider: @escaping (CustomMessagePayload) -> String?) {
        providers[businessID] = summaryProvider
    }

    func summary(for payload: CustomMessagePayload) -> String? {
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String else {
            return nil
        }
        return providers[businessID]?(payload)
    }
}
