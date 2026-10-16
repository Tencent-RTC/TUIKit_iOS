import UIKit

// 说明：本文件是从 TUILiveKit 业务库迁移到接入层的两列瀑布流直播列表所需的自包含支撑能力。
// 迁移背景对齐 Android：直播选择列表（两列 Grid）属于接入 App（Android livekitaccess/app 的 WaterfallActivity），
// 不属于业务库；因此业务库不再对外暴露列表数据接口，接入层自行调色、加载图片与拉取列表数据。

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
