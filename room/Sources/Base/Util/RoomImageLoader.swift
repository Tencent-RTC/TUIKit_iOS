import UIKit

enum RoomImageLoader {

    private static var latestRequestIDs: [String: UUID] = [:]

    static func load(url: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = url, !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        let requestID = UUID()
        latestRequestIDs[urlString] = requestID
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard Self.latestRequestIDs[urlString] == requestID else {
                    completion(nil)
                    return
                }
                Self.latestRequestIDs[urlString] = nil
                guard let data, let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                completion(image)
            }
        }.resume()
    }
}
