import UIKit

enum SearchHighlightBuilder {

    static func attributedText(text: String,
                               keyword: String,
                               font: UIFont,
                               normalColor: UIColor,
                               highlightColor: UIColor) -> NSAttributedString {
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor,
            .font: font
        ]
        let lowercasedText = text.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        if keyword.isEmpty || !lowercasedText.contains(lowercasedKeyword) {
            return NSAttributedString(string: text, attributes: normalAttributes)
        }

        let attributedString = NSMutableAttributedString(string: text, attributes: normalAttributes)
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: highlightColor,
            .font: font
        ]
        let nsText = lowercasedText as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: lowercasedKeyword, options: [], range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            attributedString.addAttributes(highlightAttributes, range: foundRange)
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }
        return attributedString
    }

    static func attributedTextWithEmoji(text: String,
                                        keyword: String,
                                        font: UIFont,
                                        normalColor: UIColor,
                                        highlightColor: UIColor) -> NSAttributedString {
        let base = NSMutableAttributedString(
            attributedString: EmojiManager.shared.createStyledAttributedString(
                fromEmojiCodes: text, font: font, textColor: normalColor
            )
        )
        let lowercasedText = base.string.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        guard !lowercasedKeyword.isEmpty, lowercasedText.contains(lowercasedKeyword) else {
            return base
        }
        let nsText = lowercasedText as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: lowercasedKeyword, options: [], range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            base.addAttributes([.foregroundColor: highlightColor], range: foundRange)
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }
        return base
    }
}
