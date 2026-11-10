import UIKit

enum LiveListPalette {
    static let background = UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)
    static let secondaryText = UIColor(white: 1, alpha: 0.68)
    static let defaultCoverURL =
        "https://liteav-test-1252463788.cos.ap-guangzhou.myqcloud.com/live/live_cover1.png"
}

enum LiveListImageLoader {
    private static let cache = NSCache<NSURL, UIImage>()

    @discardableResult
    static func load(
        urlString: String,
        completion: @escaping (UIImage?) -> Void
    ) -> URLSessionDataTask? {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return nil
        }

        if let image = cache.object(forKey: url as NSURL) {
            DispatchQueue.main.async { completion(image) }
            return nil
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, _ in
            let isSuccessfulResponse = (response as? HTTPURLResponse).map { 200 ..< 300 ~= $0.statusCode } ?? false
            let image = isSuccessfulResponse ? data.flatMap(UIImage.init(data:)) : nil
            if let image {
                cache.setObject(image, forKey: url as NSURL)
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
        return task
    }
}
