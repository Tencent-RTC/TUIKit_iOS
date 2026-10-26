import tui_cmark_gfm
import UIKit

public enum MarkdownRenderer {
    private final class StabilityTracker {
        var unstableOffsets: [Int] = []
    }

    private static let unstableLookbackLimit = 80
    private static let unstableDelimiterUnits: Set<UInt16> = Set("*_`~[".utf16)
    private static let intrawordDelimiterUnit = UInt16(UInt8(ascii: "_"))
    private static let tableRowPrefix = "|"

    private static let headingScaleH1: CGFloat = 1.4
    private static let headingScaleH2: CGFloat = 1.25
    private static let headingScaleH3: CGFloat = 1.15
    private static let headingScaleDefault: CGFloat = 1.0
    private static let codeFontScale: CGFloat = 0.85
    private static let inlineCodeFontScale: CGFloat = 0.9
    private static let codeBackgroundAlpha: CGFloat = 0.08
    private static let quoteTextAlpha: CGFloat = 0.75
    private static let quoteIndent: CGFloat = 12
    private static let listIndent: CGFloat = 18
    private static let lineSpacingRatio: CGFloat = 0.3
    private static let paragraphSpacingRatio: CGFloat = 0.4
    private static let codeLineSpacing: CGFloat = 2
    private static let taskListCheckedMarker = "☑"
    private static let taskListUncheckedMarker = "☐"
    private static let bulletMarker = "•"
    private static let cmarkDefaultOptions: Int32 = 0
    private static let cmarkOrderedListType: Int32 = 2

    public static func render(markdown: String, isStreaming: Bool, textColor: UIColor) -> NSAttributedString {
        return renderResult(markdown: markdown, isStreaming: isStreaming, textColor: textColor).attributedText
    }

    static func renderResult(markdown: String, isStreaming: Bool, textColor: UIColor) -> MarkdownRenderResult {
        let baseFont = FontScheme.caption1Regular
        let source = isStreaming ? dropTrailingIncompleteTableRow(markdown) : markdown
        guard let document = parseDocument(source) else {
            let plain = NSAttributedString(string: markdown, attributes: [.font: baseFont, .foregroundColor: textColor])
            return MarkdownRenderResult(attributedText: plain, stableLength: plain.length)
        }
        defer { cmark_node_free(document) }
        let tracker = StabilityTracker()
        let result = NSMutableAttributedString()
        var child = cmark_node_first_child(document)
        while let node = child {
            let isLast = cmark_node_next(node) == nil
            let environment = BlockEnvironment(
                font: baseFont,
                textColor: textColor,
                headIndent: 0,
                tracker: isStreaming && isLast ? tracker : nil
            )
            renderBlock(node, into: result, environment: environment, listDepth: 0, isLast: isLast)
            child = cmark_node_next(node)
        }
        while result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return MarkdownRenderResult(attributedText: result, stableLength: stableLength(of: tracker, totalLength: result.length))
    }

    private static func stableLength(of tracker: StabilityTracker, totalLength: Int) -> Int {
        let boundary = tracker.unstableOffsets.first { totalLength - $0 <= unstableLookbackLimit }
        return min(boundary ?? totalLength, totalLength)
    }

    private static func recordUnstableDelimiters(in text: String, baseOffset: Int, tracker: StabilityTracker) {
        let units = Array(text.utf16)
        for (index, unit) in units.enumerated() where unstableDelimiterUnits.contains(unit) {
            if unit == intrawordDelimiterUnit, isIntraword(units, at: index) {
                continue
            }
            tracker.unstableOffsets.append(baseOffset + index)
        }
    }

    private static func isIntraword(_ units: [UInt16], at index: Int) -> Bool {
        guard index > 0, index + 1 < units.count else { return false }
        return isWordUnit(units[index - 1]) && isWordUnit(units[index + 1])
    }

    private static func isWordUnit(_ unit: UInt16) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
    }

    private static func startsWithTableRow(_ paragraph: OpaquePointer) -> Bool {
        guard let first = cmark_node_first_child(paragraph), nodeType(first) == "text" else { return false }
        return literal(first).trimmingCharacters(in: .whitespaces).hasPrefix(tableRowPrefix)
    }

    private static func dropTrailingIncompleteTableRow(_ source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        guard let last = lines.last?.trimmingCharacters(in: .whitespaces),
              last.hasPrefix("|"), last.filter({ $0 == "|" }).count < 2 else {
            return source
        }
        lines.removeLast()
        return lines.joined(separator: "\n")
    }

    private static func parseDocument(_ markdown: String) -> OpaquePointer? {
        cmark_gfm_core_extensions_ensure_registered()
        let parser = cmark_parser_new(cmarkDefaultOptions)
        defer { cmark_parser_free(parser) }
        for name in ["autolink", "strikethrough", "tagfilter", "tasklist", "table"] {
            if let extension_ = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, extension_)
            }
        }
        cmark_parser_feed(parser, markdown, markdown.utf8.count)
        return cmark_parser_finish(parser)
    }

    private struct BlockEnvironment {
        let font: UIFont
        let textColor: UIColor
        let headIndent: CGFloat
        let tracker: StabilityTracker?
    }

    private static func nodeType(_ node: OpaquePointer) -> String {
        guard let type = cmark_node_get_type_string(node) else { return "" }
        return String(cString: type)
    }

    private static func literal(_ node: OpaquePointer) -> String {
        guard let value = cmark_node_get_literal(node) else { return "" }
        return String(cString: value)
    }

    private static func renderBlock(_ node: OpaquePointer,
                                    into result: NSMutableAttributedString,
                                    environment: BlockEnvironment,
                                    listDepth: Int,
                                    isLast: Bool) {
        switch nodeType(node) {
        case "paragraph":
            renderParagraph(node, into: result, environment: environment, isLast: isLast)
        case "heading":
            renderHeading(node, into: result, environment: environment, isLast: isLast)
        case "code_block":
            renderCodeBlock(node, into: result, environment: environment, isLast: isLast)
        case "block_quote":
            renderBlockQuote(node, into: result, environment: environment, isLast: isLast)
        case "list":
            renderList(node, into: result, environment: environment, listDepth: listDepth)
        case "table":
            renderTable(node, into: result, environment: environment, isLast: isLast)
        default:
            break
        }
    }

    private static func renderParagraph(_ node: OpaquePointer,
                                        into result: NSMutableAttributedString,
                                        environment: BlockEnvironment,
                                        isLast: Bool) {
        let style = paragraphStyle(lineSpacing: environment.font.lineHeight * lineSpacingRatio,
                                   blockSpacing: isLast ? 0 : environment.font.lineHeight * paragraphSpacingRatio)
        style.headIndent = environment.headIndent
        style.firstLineHeadIndent = environment.headIndent
        if let tracker = environment.tracker, startsWithTableRow(node) {
            tracker.unstableOffsets.append(result.length)
        }
        renderInlines(node, into: result, font: environment.font, textColor: environment.textColor,
                      paragraphStyle: style, tracker: environment.tracker)
        result.append(NSAttributedString(string: "\n", attributes: [.font: environment.font, .paragraphStyle: style]))
    }

    private static func renderHeading(_ node: OpaquePointer,
                                      into result: NSMutableAttributedString,
                                      environment: BlockEnvironment,
                                      isLast: Bool) {
        let scale: CGFloat
        switch cmark_node_get_heading_level(node) {
        case 1: scale = headingScaleH1
        case 2: scale = headingScaleH2
        case 3: scale = headingScaleH3
        default: scale = headingScaleDefault
        }
        let font = boldFont(environment.font, scale: scale)
        let style = paragraphStyle(lineSpacing: font.lineHeight * lineSpacingRatio,
                                   blockSpacing: isLast ? 0 : font.lineHeight * lineSpacingRatio)
        style.headIndent = environment.headIndent
        style.firstLineHeadIndent = environment.headIndent
        renderInlines(node, into: result, font: font, textColor: environment.textColor,
                      paragraphStyle: style, tracker: environment.tracker)
        result.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: style]))
    }

    private static func renderCodeBlock(_ node: OpaquePointer,
                                        into result: NSMutableAttributedString,
                                        environment: BlockEnvironment,
                                        isLast: Bool) {
        let code = literal(node)
        guard !code.isEmpty else { return }
        let font = UIFont.monospacedSystemFont(ofSize: environment.font.pointSize * codeFontScale, weight: .regular)
        let style = paragraphStyle(lineSpacing: codeLineSpacing,
                                   blockSpacing: isLast ? 0 : environment.font.lineHeight * paragraphSpacingRatio)
        style.headIndent = environment.headIndent
        style.firstLineHeadIndent = environment.headIndent
        result.append(NSAttributedString(string: code, attributes: [
            .font: font,
            .foregroundColor: environment.textColor,
            .backgroundColor: codeBackgroundColor(environment.textColor),
            .paragraphStyle: style
        ]))
    }

    private static func renderBlockQuote(_ node: OpaquePointer,
                                         into result: NSMutableAttributedString,
                                         environment: BlockEnvironment,
                                         isLast: Bool) {
        let quoteEnvironment = BlockEnvironment(
            font: environment.font,
            textColor: environment.textColor.withAlphaComponent(quoteTextAlpha),
            headIndent: environment.headIndent + quoteIndent,
            tracker: environment.tracker
        )
        var child = cmark_node_first_child(node)
        while let childNode = child {
            let childIsLast = isLast && cmark_node_next(childNode) == nil
            renderBlock(childNode, into: result, environment: quoteEnvironment, listDepth: 0, isLast: childIsLast)
            child = cmark_node_next(childNode)
        }
    }

    private static func renderList(_ node: OpaquePointer,
                                   into result: NSMutableAttributedString,
                                   environment: BlockEnvironment,
                                   listDepth: Int) {
        let ordered = cmark_node_get_list_type(node) == cmarkOrderedListType
        var index = Int(cmark_node_get_list_start(node))
        var child = cmark_node_first_child(node)
        while let item = child {
            let marker: String
            if nodeType(item) == "tasklist" {
                marker = cmark_gfm_extensions_get_tasklist_item_checked(item) ? taskListCheckedMarker : taskListUncheckedMarker
            } else {
                marker = ordered ? "\(index)." : bulletMarker
            }
            renderListItem(item, marker: marker, into: result, environment: environment, listDepth: listDepth)
            index += 1
            child = cmark_node_next(item)
        }
    }

    private static func renderListItem(_ item: OpaquePointer,
                                       marker: String,
                                       into result: NSMutableAttributedString,
                                       environment: BlockEnvironment,
                                       listDepth: Int) {
        let style = paragraphStyle(lineSpacing: environment.font.lineHeight * lineSpacingRatio, blockSpacing: 0)
        style.headIndent = environment.headIndent + listIndent * CGFloat(listDepth + 1)
        style.firstLineHeadIndent = environment.headIndent + listIndent * CGFloat(listDepth)
        result.append(NSAttributedString(string: marker + " ", attributes: [
            .font: environment.font,
            .foregroundColor: environment.textColor,
            .paragraphStyle: style
        ]))
        var child = cmark_node_first_child(item)
        while let childNode = child {
            if nodeType(childNode) == "paragraph" {
                renderInlines(childNode, into: result, font: environment.font, textColor: environment.textColor,
                              paragraphStyle: style, tracker: environment.tracker)
                result.append(NSAttributedString(string: "\n", attributes: [.font: environment.font, .paragraphStyle: style]))
            } else {
                renderBlock(childNode, into: result, environment: environment, listDepth: listDepth + 1, isLast: false)
            }
            child = cmark_node_next(childNode)
        }
    }

    private static func renderTable(_ node: OpaquePointer,
                                    into result: NSMutableAttributedString,
                                    environment: BlockEnvironment,
                                    isLast: Bool) {
        let font = UIFont.monospacedSystemFont(ofSize: environment.font.pointSize * codeFontScale, weight: .regular)
        let style = paragraphStyle(lineSpacing: 0,
                                   blockSpacing: isLast ? 0 : environment.font.lineHeight * paragraphSpacingRatio)
        style.headIndent = environment.headIndent
        style.firstLineHeadIndent = environment.headIndent
        var row = cmark_node_first_child(node)
        while let rowNode = row {
            var cells: [String] = []
            var cell = cmark_node_first_child(rowNode)
            while let cellNode = cell {
                cells.append(plainText(cellNode))
                cell = cmark_node_next(cellNode)
            }
            result.append(NSAttributedString(string: "| " + cells.joined(separator: " | ") + " |\n", attributes: [
                .font: font,
                .foregroundColor: environment.textColor,
                .paragraphStyle: style
            ]))
            row = cmark_node_next(rowNode)
        }
    }

    private static func plainText(_ node: OpaquePointer) -> String {
        var text = ""
        switch nodeType(node) {
        case "text", "code":
            text += literal(node)
        case "softbreak", "linebreak":
            text += " "
        default:
            break
        }
        var child = cmark_node_first_child(node)
        while let childNode = child {
            text += plainText(childNode)
            child = cmark_node_next(childNode)
        }
        return text
    }

    private static func renderInlines(_ node: OpaquePointer,
                                      into result: NSMutableAttributedString,
                                      font: UIFont,
                                      textColor: UIColor,
                                      paragraphStyle: NSParagraphStyle,
                                      tracker: StabilityTracker?) {
        var child = cmark_node_first_child(node)
        while let childNode = child {
            renderInline(childNode, into: result, font: font, textColor: textColor,
                         paragraphStyle: paragraphStyle, tracker: tracker)
            child = cmark_node_next(childNode)
        }
    }

    private static func renderInline(_ node: OpaquePointer,
                                     into result: NSMutableAttributedString,
                                     font: UIFont,
                                     textColor: UIColor,
                                     paragraphStyle: NSParagraphStyle,
                                     tracker: StabilityTracker?) {
        switch nodeType(node) {
        case "text":
            let text = literal(node)
            if let tracker {
                recordUnstableDelimiters(in: text, baseOffset: result.length, tracker: tracker)
            }
            appendPlain(result, text, font: font, textColor: textColor, paragraphStyle: paragraphStyle)
        case "softbreak", "linebreak":
            let style = tightParagraphStyle(from: paragraphStyle)
            result.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: style]))
        case "code":
            let codeFont = UIFont.monospacedSystemFont(ofSize: font.pointSize * inlineCodeFontScale, weight: .regular)
            result.append(NSAttributedString(string: literal(node), attributes: [
                .font: codeFont,
                .foregroundColor: textColor,
                .backgroundColor: codeBackgroundColor(textColor),
                .paragraphStyle: paragraphStyle
            ]))
        case "emph":
            renderInlines(node, into: result, font: italicFont(font), textColor: textColor,
                          paragraphStyle: paragraphStyle, tracker: tracker)
        case "strong":
            renderInlines(node, into: result, font: boldFont(font, scale: 1.0), textColor: textColor,
                          paragraphStyle: paragraphStyle, tracker: tracker)
        case "strikethrough":
            let content = renderDetachedInlines(node, baseOffset: result.length, font: font, textColor: textColor,
                                                paragraphStyle: paragraphStyle, tracker: tracker)
            content.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                                 range: NSRange(location: 0, length: content.length))
            result.append(content)
        case "link":
            let content = renderDetachedInlines(node, baseOffset: result.length, font: font, textColor: textColor,
                                                paragraphStyle: paragraphStyle, tracker: tracker)
            let range = NSRange(location: 0, length: content.length)
            content.addAttribute(.foregroundColor, value: TUIChatKitTheme.colors.textColorLink, range: range)
            if let urlString = cmark_node_get_url(node), let url = URL(string: String(cString: urlString)) {
                content.addAttribute(.link, value: url, range: range)
                content.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            result.append(content)
        case "image":
            renderInlines(node, into: result, font: font, textColor: textColor,
                          paragraphStyle: paragraphStyle, tracker: tracker)
        default:
            break
        }
    }

    private static func renderDetachedInlines(_ node: OpaquePointer,
                                              baseOffset: Int,
                                              font: UIFont,
                                              textColor: UIColor,
                                              paragraphStyle: NSParagraphStyle,
                                              tracker: StabilityTracker?) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        let localTracker = tracker.map { _ in StabilityTracker() }
        renderInlines(node, into: content, font: font, textColor: textColor,
                      paragraphStyle: paragraphStyle, tracker: localTracker)
        if let tracker, let localTracker {
            tracker.unstableOffsets.append(contentsOf: localTracker.unstableOffsets.map { $0 + baseOffset })
        }
        return content
    }

    private static func appendPlain(_ result: NSMutableAttributedString,
                                    _ text: String,
                                    font: UIFont,
                                    textColor: UIColor,
                                    paragraphStyle: NSParagraphStyle) {
        guard !text.isEmpty else { return }
        result.append(NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]))
    }

    private static func paragraphStyle(lineSpacing: CGFloat, blockSpacing: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .natural
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = blockSpacing
        return style
    }

    private static func tightParagraphStyle(from style: NSParagraphStyle) -> NSParagraphStyle {
        guard let copy = style.mutableCopy() as? NSMutableParagraphStyle else { return style }
        copy.paragraphSpacing = 0
        return copy
    }

    private static func boldFont(_ font: UIFont, scale: CGFloat) -> UIFont {
        let size = font.pointSize * scale
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.boldSystemFont(ofSize: size)
    }

    private static func italicFont(_ font: UIFont) -> UIFont {
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return UIFont.italicSystemFont(ofSize: font.pointSize)
    }

    private static func codeBackgroundColor(_ textColor: UIColor) -> UIColor {
        return textColor.withAlphaComponent(codeBackgroundAlpha)
    }
}
