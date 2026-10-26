import Foundation
import UIKit
import Combine
import Kingfisher

let defaultEmojiSize = CGSize(width: 23, height: 23)
class EmojiBundleHelper {
    static var bundlePath: String = BundleHelper.getBundlePath(bundleName: "EmojiFace", classType: EmojiBundleHelper.self, frameworkName: "TUIChatKitBundle")
    static func appendPath(_ path: String) -> String {
        return (bundlePath as NSString).appendingPathComponent(path)
    }

    static func getLocalizedString(_ key: String) -> String {
        return LanguageHelper.getLocalizedString(forKey: key, bundle: "EmojiFace", classType: EmojiBundleHelper.self, frameworkName: "TUIChatKitBundle")
    }
}

class EmojiGroup: NSObject {
    private static let littleEmojiRowCount: Int = 4

    private static let bigEmojiRowCount: Int = 3

    private static let littleEmojiItemCountPerRow: Int = 8

    private static let bigEmojiItemCountPerRow: Int = 5

    var id: String = ""
    var groupIndex: Int = 0
    var groupPath: String?
    var rowCount: Int = 0
    var itemCountPerRow: Int = 0
    var emojis: [EmojiData]?
    var needBackDelete: Bool = false
    var menuPath: String?
    var recentGroup: EmojiGroup?
    var isNeedAddInInputBar: Bool = false
    var groupName: String?
    var isLittleEmoji: Bool = true
    var supportReaction: Bool = true

    override init() {
        super.init()
    }

    init(id: String, name: String, iconPath: String?, emojis: [EmojiData], isLittleEmoji: Bool, supportReaction: Bool? = nil) {
        super.init()
        self.id = id
        self.groupName = name
        self.menuPath = iconPath
        self.emojis = emojis
        self.isLittleEmoji = isLittleEmoji
        self.supportReaction = supportReaction ?? isLittleEmoji
        self.rowCount = isLittleEmoji ? Self.littleEmojiRowCount : Self.bigEmojiRowCount
        self.itemCountPerRow = isLittleEmoji ? Self.littleEmojiItemCountPerRow : Self.bigEmojiItemCountPerRow
    }
    var emojisMap: [String: String] {
        if _emojisMap == nil || (_emojisMap?.count ?? 0) != (emojis?.count ?? 0) {
            var emojiDic: [String: String] = [:]
            if let emojis = emojis {
                for data in emojis {
                    if let name = data.name {
                        emojiDic[name] = data.path
                    }
                }
            }
            _emojisMap = emojiDic
        }
        return _emojisMap ?? [:]
    }

    private var _emojisMap: [String: String]?
}

class EmojiCache {
    public static let shared = EmojiCache()

    private var emojiCache: [String: UIImage] = [:]

    func addEmojiToCache(_ path: String) {
        asyncDecodeImage(path) { [weak self] key, image in
            guard let self = self, let key = key, let image = image else { return }
            self.emojiCache[key] = image
        }
    }

    func getImageFromCache(_ path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        if let image = emojiCache[path] {
            return image
        }
        if path.contains(".gif") {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return UIImage(data: data)
            }
            return nil
        }
        if let image = UIImage(contentsOfFile: path) {
            return image
        }

        let formatPath = path + ".gif"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: formatPath)) {
            return UIImage(data: data)
        }
        return nil
    }

    func asyncDecodeImage(_ path: String, complete: @escaping (String?, UIImage?) -> Void) {
        DispatchQueue.global().async {
            if let image = UIImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    complete(path, image)
                }
            } else {
                DispatchQueue.main.async {
                    complete(nil, nil)
                }
            }
        }
    }

    func setImage(_ image: UIImage, forKey key: String) {
        emojiCache[key] = image
    }

    func downloadRemoteImage(_ url: String) {
        guard !url.isEmpty, emojiCache[url] == nil, let target = URL(string: url) else { return }
        KingfisherManager.shared.retrieveImage(with: target) { [weak self] result in
            guard let self = self, case .success(let value) = result else { return }
            self.emojiCache[url] = value.image
            NotificationCenter.default.post(name: EmojiCache.didUpdateNotification, object: url)
        }
    }

    static let didUpdateNotification = NSNotification.Name("EmojiCacheDidUpdateNotification")

    private init() {}
}

class EmojiConfig: NSObject {
    public static let shared = EmojiConfig()

    static let builtInGroupID = "tui_built_in_little_emoji"

    private static let builtInEmojiRowCount: Int = 4

    private static let builtInEmojiItemCountPerRow: Int = 8

    public private(set) var emojiGroups: [EmojiGroup] = []
    var chatPopDetailGroups: [EmojiGroup] = []
    var chatContextEmojiDetailGroups: [EmojiGroup] = []

    let groupsDidChangePublisher = PassthroughSubject<Void, Never>()

    override private init() {
        super.init()
        if let group = createEmojiGroup() {
            emojiGroups.append(group)
        }
    }

    @discardableResult
    func addEmojiGroup(_ group: EmojiGroup) -> EmojiConfig {
        if let index = emojiGroups.firstIndex(where: { $0.id == group.id }) {
            emojiGroups.remove(at: index)
        }
        emojiGroups.append(group)
        didChangeGroups(prefetch: group)
        return self
    }

    @discardableResult
    func addEmojiGroup(_ group: EmojiGroup, index: Int) -> EmojiConfig {
        if let existing = emojiGroups.firstIndex(where: { $0.id == group.id }) {
            emojiGroups.remove(at: existing)
        }
        let safeIndex = max(0, min(index, emojiGroups.count))
        emojiGroups.insert(group, at: safeIndex)
        didChangeGroups(prefetch: group)
        return self
    }

    @discardableResult
    func addEmojiGroups(_ groups: [EmojiGroup]) -> EmojiConfig {
        for group in groups {
            if let existing = emojiGroups.firstIndex(where: { $0.id == group.id }) {
                emojiGroups.remove(at: existing)
            }
            emojiGroups.append(group)
            prefetchImages(for: group)
        }
        groupsDidChangePublisher.send()
        return self
    }

    @discardableResult
    func removeEmojiGroup(id: String) -> EmojiConfig {
        emojiGroups.removeAll { $0.id == id }
        groupsDidChangePublisher.send()
        return self
    }

    @discardableResult
    func removeEmojiGroups(_ groups: [EmojiGroup]) -> EmojiConfig {
        let ids = Set(groups.map { $0.id })
        emojiGroups.removeAll { ids.contains($0.id) }
        groupsDidChangePublisher.send()
        return self
    }

    @discardableResult
    func clearEmojiGroups() -> EmojiConfig {
        emojiGroups.removeAll()
        groupsDidChangePublisher.send()
        return self
    }

    @discardableResult
    func moveEmojiGroup(_ id: String, toIndex: Int) -> EmojiConfig {
        guard let from = emojiGroups.firstIndex(where: { $0.id == id }) else { return self }
        let group = emojiGroups.remove(at: from)
        let safeIndex = max(0, min(toIndex, emojiGroups.count))
        emojiGroups.insert(group, at: safeIndex)
        groupsDidChangePublisher.send()
        return self
    }

    func getEmojiGroup(_ id: String) -> EmojiGroup? {
        return emojiGroups.first { $0.id == id }
    }

    func containsEmojiGroup(_ id: String) -> Bool {
        return emojiGroups.contains { $0.id == id }
    }

    private func didChangeGroups(prefetch group: EmojiGroup) {
        prefetchImages(for: group)
        groupsDidChangePublisher.send()
    }

    private func prefetchImages(for group: EmojiGroup) {
        for emoji in group.emojis ?? [] {
            if let path = emoji.path, !path.isEmpty {
                EmojiCache.shared.addEmojiToCache(path)
            } else if let url = emoji.url, !url.isEmpty {
                EmojiCache.shared.downloadRemoteImage(url)
            }
        }
        if let iconPath = group.menuPath, !iconPath.isEmpty {
            if iconPath.hasPrefix("http") {
                EmojiCache.shared.downloadRemoteImage(iconPath)
            } else {
                EmojiCache.shared.addEmojiToCache(iconPath)
            }
        }
    }

    private func createEmojiGroup() -> EmojiGroup? {
        var emojiEmojis: [EmojiData] = []
        let plistPath = EmojiBundleHelper.appendPath("emoji/emoji.plist")
        if let emojiList = NSArray(contentsOfFile: plistPath) as? [[String: String]] {
            for dic in emojiList {
                let data = EmojiData()
                if let name = dic["face_name"], let fileName = dic["face_file"] {
                    let path = "emoji/\(fileName)@2x.png"
                    let localizableName = EmojiBundleHelper.getLocalizedString(name)
                    data.name = name
                    data.path = EmojiBundleHelper.appendPath(path)
                    data.localizableName = localizableName
                    if let path = data.path {
                        EmojiCache.shared.addEmojiToCache(path)
                    }
                    emojiEmojis.append(data)
                }
            }
        }
        if !emojiEmojis.isEmpty {
            let emojiGroup = EmojiGroup()
            emojiGroup.id = EmojiConfig.builtInGroupID
            emojiGroup.emojis = emojiEmojis
            emojiGroup.groupIndex = 0
            emojiGroup.groupPath = EmojiBundleHelper.appendPath("emoji/")
            emojiGroup.menuPath = EmojiBundleHelper.appendPath("emoji/menu")
            emojiGroup.isNeedAddInInputBar = true
            emojiGroup.groupName = "All"
            emojiGroup.rowCount = Self.builtInEmojiRowCount
            emojiGroup.itemCountPerRow = Self.builtInEmojiItemCountPerRow
            emojiGroup.needBackDelete = false
            if let path = emojiGroup.menuPath {
                EmojiCache.shared.addEmojiToCache(path)
            }
            EmojiCache.shared.addEmojiToCache(EmojiBundleHelper.appendPath("del_normal"))
            EmojiCache.shared.addEmojiToCache(EmojiBundleHelper.appendPath("ic_unknown_image@2x"))
            return emojiGroup
        }
        return nil
    }



}
