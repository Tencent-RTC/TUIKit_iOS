import AtomicXCore
import Foundation

public enum RoomRandomUtils {

    private static let maxRetryCount = 5
    private static let timestampPrefixLength = 6

    public static func generateRoomID(completion: @escaping (String) -> Void) {
        attempt(retriesLeft: maxRetryCount, completion: completion)
    }

    static func randomRoomID() -> String {
        String(Int.random(in: 100_000...999_999))
    }

    static func fallbackRoomID(base: String, timestampMillis: Int64) -> String {
        "\(base)-\(String(timestampMillis).prefix(timestampPrefixLength))"
    }

    private static func attempt(retriesLeft: Int, completion: @escaping (String) -> Void) {
        let candidate = randomRoomID()
        RoomStore.shared.getRoomInfo(roomID: candidate) { result in
            switch result {
            case .failure:
                completion(candidate)
            case .success:
                if retriesLeft > 0 {
                    attempt(retriesLeft: retriesLeft - 1, completion: completion)
                } else {
                    let millis = Int64(Date().timeIntervalSince1970 * 1000)
                    completion(fallbackRoomID(base: candidate, timestampMillis: millis))
                }
            }
        }
    }
}
