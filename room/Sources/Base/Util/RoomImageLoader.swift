import UIKit

enum RoomImageLoader {

    private static let cache = NSCache<NSString, UIImage>()

    static func load(url: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = url, !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        let key = urlString as NSString
        if let image = cache.object(forKey: key) {
            completion(image)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard let data, let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                cache.setObject(image, forKey: key)
                completion(image)
            }
        }.resume()
    }
}
