import Foundation

final class RealtimeASRResponseListenerImpl {
    weak var owner: RealtimeASRResponseListener?

    private let onResponse: (RealtimeASRResponse) -> Void

    init(onResponse: @escaping (RealtimeASRResponse) -> Void) {
        self.onResponse = onResponse
    }

    func onExperimentalNotify(key: String, param: NSObject?) {
        guard key == RealtimeASRResponse.notificationKey, let dict = param as? [String: Any] else { return }
        let response = RealtimeASRResponse(dict: dict)
        DispatchQueue.main.async { [weak self] in
            guard let self, let owner = self.owner else { return }
            withExtendedLifetime(owner) {
                self.onResponse(response)
            }
        }
    }
}

