import UIKit

enum CallKitAvatarLoader {

    private static let imageCache = NSCache<NSString, UIImage>()

    static func image(from urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let url = validURL(urlString) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        if let cached = imageCache.object(forKey: url.absoluteString as NSString) {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            if let image {
                imageCache.setObject(image, forKey: url.absoluteString as NSString)
            }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    static func file(from urlString: String?, name: String, completion: @escaping (String?) -> Void) {
        guard let url = validURL(urlString) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        URLSession.shared.downloadTask(with: url) { tmpURL, _, _ in
            guard let tmpURL else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let dest = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("callkit_avatar_\(name).\(ext)")
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: tmpURL, to: dest)
                DispatchQueue.main.async { completion(dest.path) }
            } catch {
                CallKitLog.warning("avatar file move failed for \(name): \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    private static func validURL(_ urlString: String?) -> URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}
