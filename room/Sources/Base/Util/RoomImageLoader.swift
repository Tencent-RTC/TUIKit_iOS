import UIKit

enum RoomImageLoader {

    static func load(url: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = url, !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard let data, let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                completion(image)
            }
        }.resume()
    }
}
