class EmojiData: NSObject {
    public var name: String?
    var localizableName: String?
    public var path: String?
    public var url: String?

    public convenience init(key: String, emojiName: String, url: String) {
        self.init()
        self.name = key
        self.localizableName = emojiName
        self.url = url
    }
}

class EmojiTextAttachment: NSTextAttachment {
    private static let verticalOffsetRatio: CGFloat = 0.4

    var faceCellData: EmojiData?
    var emojiTag: String?
    var emojiSize: CGSize = .zero
    override public func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return CGRect(x: 0, y: -Self.verticalOffsetRatio * lineFrag.size.height, width: defaultEmojiSize.width, height: defaultEmojiSize.height)
    }
}

class EmojiManager {
    public static let shared = EmojiManager()

    private static let emojiCodeAttachmentSize: CGFloat = 20

    private static let emojiCodeAttachmentVerticalOffset: CGFloat = -4

    private static let styledAttachmentSizeRatio: CGFloat = 1.5

    private static let styledAttachmentVerticalOffsetRatio: CGFloat = -0.2
    func createAttributedStringFromEmojiData(_ emoji: EmojiData) -> NSAttributedString {
        let emojiTextAttachment = EmojiTextAttachment()
        emojiTextAttachment.faceCellData = emoji
        emojiTextAttachment.emojiTag = emoji.name
        emojiTextAttachment.image = EmojiManager.cachedImage(for: emoji) ?? UIImage()
        emojiTextAttachment.emojiSize = defaultEmojiSize
        return NSAttributedString(attachment: emojiTextAttachment)
    }

    func createAttributedStringWithTextAndStyle(text: String, withFont textFont: UIFont, textColor: UIColor) -> NSMutableAttributedString {
        guard !text.isEmpty else {
            print("createAttributedStringWithTextAndStyle failed, current text is nil")
            return NSMutableAttributedString(string: "")
        }
        let attributeString = NSMutableAttributedString(string: text)
        let allFaces = getAllEmojis()
        guard !allFaces.isEmpty else {
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            return attributeString
        }
        let regexEmoji = EmojiManager.getEmojiRegex()
        do {
            let regex = try NSRegularExpression(pattern: regexEmoji, options: .caseInsensitive)
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            var imageArray = [(range: NSRange, imageStr: NSAttributedString)]()
            for match in results {
                let range = match.range
                let subStr = (text as NSString).substring(with: range)
                for face in allFaces {
                    if face.name == subStr || face.localizableName == subStr {
                        let emojiTextAttachment = EmojiTextAttachment()
                        emojiTextAttachment.faceCellData = face
                        emojiTextAttachment.emojiTag = face.name
                        if let path = face.path {
                            emojiTextAttachment.image = EmojiCache.shared.getImageFromCache(path)
                        } else if let url = face.url {
                            emojiTextAttachment.image = EmojiCache.shared.getImageFromCache(url)
                        }
                        emojiTextAttachment.emojiSize = defaultEmojiSize
                        let imageStr = NSAttributedString(attachment: emojiTextAttachment)
                        imageArray.append((range, imageStr))
                        break
                    }
                }
            }
            var locations = [(originRange: NSRange, originStr: NSAttributedString, currentStr: NSAttributedString)]()
            for item in imageArray.reversed() {
                let originRange = item.range
                let originStr = attributeString.attributedSubstring(from: originRange)
                let currentStr = item.imageStr
                locations.insert((originRange, originStr, currentStr), at: 0)
                attributeString.replaceCharacters(in: originRange, with: currentStr)
            }
            var offsetLocation = 0
            for location in locations {
                var currentRange = location.originRange
                currentRange.location += offsetLocation
                currentRange.length = location.currentStr.length
                offsetLocation += location.currentStr.length - location.originStr.length
            }
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            attributeString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributeString.length))
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        return attributeString
    }

    func createAttributedStringFromEmojiCodes(from text: String) -> NSAttributedString {
        let pattern = "\\[TUIEmoji_[^\\]]+\\]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        let attributedString = NSMutableAttributedString()
        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let textString = nsString.substring(with: textRange)
                attributedString.append(NSAttributedString(string: textString))
            }
            let emojiCode = nsString.substring(with: match.range)
            if let emojiData = getAllEmojis().first(where: { $0.name == emojiCode }),
               let image = EmojiManager.cachedImage(for: emojiData)
            {

                let attachment = EmojiTextAttachment()
                attachment.image = image
                attachment.emojiTag = emojiCode
                attachment.faceCellData = emojiData
                attachment.emojiSize = defaultEmojiSize
                attachment.bounds = CGRect(x: 0, y: Self.emojiCodeAttachmentVerticalOffset, width: Self.emojiCodeAttachmentSize, height: Self.emojiCodeAttachmentSize)
                let imageString = NSAttributedString(attachment: attachment)
                attributedString.append(imageString)
            } else {
                attributedString.append(NSAttributedString(string: emojiCode))
            }
            lastIndex = match.range.location + match.range.length
        }
        if lastIndex < nsString.length {
            let textRange = NSRange(location: lastIndex, length: nsString.length - lastIndex)
            let textString = nsString.substring(with: textRange)
            attributedString.append(NSAttributedString(string: textString))
        }
        return attributedString
    }

    func createStyledAttributedString(fromEmojiCodes text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
        let source = createAttributedStringFromEmojiCodes(from: text)
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let emojiSize = font.pointSize * Self.styledAttachmentSizeRatio
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                attachment.bounds = CGRect(
                    x: 0,
                    y: emojiSize * Self.styledAttachmentVerticalOffsetRatio,
                    width: emojiSize,
                    height: emojiSize
                )
            } else {
                mutable.addAttribute(.font, value: font, range: range)
                mutable.addAttribute(.foregroundColor, value: textColor, range: range)
            }
        }
        return mutable
    }

    func createLocalizedStringFromEmojiCodes(_ text: String) -> String {
        let regex = try? NSRegularExpression(pattern: EmojiManager.getEmojiRegex(), options: [])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        var result = text
        for match in matches.reversed() {
            let emojiCode = nsString.substring(with: match.range)
            if let emojiData = getAllEmojis().first(where: { $0.name == emojiCode }),
               let localizedName = emojiData.localizableName
            {
                result = (result as NSString).replacingCharacters(in: match.range, with: localizedName)
            }
        }
        return result
    }

    private init() {}
    private func getStickerFromCache(_ path: String) -> UIImage {
        return EmojiCache.shared.getImageFromCache(path) ?? UIImage()
    }

    static func cachedImage(for emoji: EmojiData) -> UIImage? {
        if let path = emoji.path, !path.isEmpty {
            return EmojiCache.shared.getImageFromCache(path)
        }
        if let url = emoji.url, !url.isEmpty {
            return EmojiCache.shared.getImageFromCache(url)
        }
        return nil
    }

    private static func getEmojiRegex() -> String {
        return "\\[[a-zA-Z0-9_\\u4e00-\\u9fa5]+\\]"
    }
}

extension EmojiManager {
    private static let kRecentEmojiKey = "recent_emoji_list"

    private static let chineseElementEmojiKeys: Set<String> = [
        "[TUIEmoji_Rich]", "[TUIEmoji_Bless]", "[TUIEmoji_Fortune]",
        "[TUIEmoji_Convinced]", "[TUIEmoji_Prohibit]", "[TUIEmoji_666]", "[TUIEmoji_857]"
    ]

    private var userDefaults: UserDefaults { UserDefaults.standard }

    private var maxRecentCount: Int { 8 }

    func getAllEmojis() -> [EmojiData] {
        return EmojiConfig.shared.emojiGroups.flatMap { $0.emojis ?? [] }
    }

    func pickerVisibleEmojis(in group: EmojiGroup?) -> [EmojiData] {
        guard let group = group else { return [] }
        let emojis = group.emojis ?? []
        guard group.id == EmojiConfig.builtInGroupID,
              !LanguageHelper.getCurrentLanguage().hasPrefix("zh") else { return emojis }
        return emojis.filter { !EmojiManager.chineseElementEmojiKeys.contains($0.name ?? "") }
    }

    func getReactionEmojis() -> [EmojiData] {
        let group = EmojiConfig.shared.emojiGroups.first(where: { $0.supportReaction })
            ?? EmojiConfig.shared.emojiGroups.first
        return pickerVisibleEmojis(in: group)
    }

    func getPickerEmojis() -> [EmojiData] {
        return getReactionEmojis()
    }

    func getRecentEmojiDataList(groupID: String = EmojiConfig.builtInGroupID) -> [EmojiData] {
        let group = EmojiConfig.shared.getEmojiGroup(groupID)
        let visible = pickerVisibleEmojis(in: group)
        return getRecentEmojis(groupID: groupID).compactMap { id in
            visible.first(where: { $0.name == id })
        }
    }

    func getRecentEmojis(groupID: String = EmojiConfig.builtInGroupID) -> [String] {
        return userDefaults.stringArray(forKey: Self.recentKey(for: groupID)) ?? []
    }

    func addRecentEmoji(_ emoji: EmojiData, groupID: String = EmojiConfig.builtInGroupID) {
        guard let id = emoji.name else { return }
        var list = getRecentEmojis(groupID: groupID)
        list.removeAll { $0 == id }
        list.insert(id, at: 0)
        if list.count > maxRecentCount {
            list = Array(list.prefix(maxRecentCount))
        }
        userDefaults.set(list, forKey: Self.recentKey(for: groupID))
    }

    func reactionGroupID() -> String {
        return EmojiConfig.shared.emojiGroups.first(where: { $0.supportReaction })?.id
            ?? EmojiConfig.builtInGroupID
    }

    private static func recentKey(for groupID: String) -> String {
        if groupID == EmojiConfig.builtInGroupID { return kRecentEmojiKey }
        return "\(kRecentEmojiKey)_\(groupID)"
    }
}
