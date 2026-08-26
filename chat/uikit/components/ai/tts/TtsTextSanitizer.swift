import Foundation

final class TtsTextSanitizer {
    static let shared = TtsTextSanitizer()

    private let customEmojiRegex: NSRegularExpression?

    private let universalEmojiRegex: NSRegularExpression?

    private static let universalEmojiPattern: String = {
        let ri = "[\\x{1F1E6}-\\x{1F1FF}]"
        let support = "\\x{A9}|\\x{AE}|\\x{203C}|\\x{2049}|\\x{2122}|\\x{2139}|[\\x{2194}-\\x{2199}]|[\\x{21A9}-\\x{21AA}]" +
            "|[\\x{231A}-\\x{231B}]|\\x{2328}|\\x{23CF}|[\\x{23E9}-\\x{23EF}]|[\\x{23F0}-\\x{23F3}]|[\\x{23F8}-\\x{23FA}]|\\x{24C2}" +
            "|[\\x{25AA}-\\x{25AB}]|\\x{25B6}|\\x{25C0}|[\\x{25FB}-\\x{25FE}]|[\\x{2600}-\\x{2604}]|\\x{260E}|\\x{2611}|[\\x{2614}-\\x{2615}]" +
            "|\\x{2618}|\\x{261D}|\\x{2620}|[\\x{2622}-\\x{2623}]|\\x{2626}|\\x{262A}|[\\x{262E}-\\x{262F}]|[\\x{2638}-\\x{263A}]|\\x{2640}" +
            "|\\x{2642}|[\\x{2648}-\\x{264F}]|[\\x{2650}-\\x{2653}]|\\x{265F}|\\x{2660}|\\x{2663}|[\\x{2665}-\\x{2666}]|\\x{2668}|\\x{267B}" +
            "|[\\x{267E}-\\x{267F}]|[\\x{2692}-\\x{2697}]|\\x{2699}|[\\x{269B}-\\x{269C}]|[\\x{26A0}-\\x{26A1}]|\\x{26A7}|[\\x{26AA}-\\x{26AB}]" +
            "|[\\x{26B0}-\\x{26B1}]|[\\x{26BD}-\\x{26BE}]|[\\x{26C4}-\\x{26C5}]|\\x{26C8}|[\\x{26CE}-\\x{26CF}]|\\x{26D1}|[\\x{26D3}-\\x{26D4}]" +
            "|[\\x{26E9}-\\x{26EA}]|[\\x{26F0}-\\x{26F5}]|[\\x{26F7}-\\x{26FA}]|\\x{26FD}|\\x{2702}|\\x{2705}|[\\x{2708}-\\x{270D}]|\\x{270F}|\\x{2712}" +
            "|\\x{2714}|\\x{2716}|\\x{271D}|\\x{2721}|\\x{2728}|[\\x{2733}-\\x{2734}]|\\x{2744}|\\x{2747}|\\x{274C}|\\x{274E}|[\\x{2753}-\\x{2755}]" +
            "|\\x{2757}|[\\x{2763}-\\x{2764}]|[\\x{2795}-\\x{2797}]|\\x{27A1}|\\x{27B0}|\\x{27BF}|[\\x{2934}-\\x{2935}]|[\\x{2B05}-\\x{2B07}]" +
            "|[\\x{2B1B}-\\x{2B1C}]|\\x{2B50}|\\x{2B55}|\\x{3030}|\\x{303D}|\\x{3297}|\\x{3299}|\\x{1F004}|\\x{1F0CF}|[\\x{1F170}-\\x{1F171}]" +
            "|[\\x{1F17E}-\\x{1F17F}]|\\x{1F18E}|[\\x{1F191}-\\x{1F19A}]|[\\x{1F1E6}-\\x{1F1FF}]|[\\x{1F201}-\\x{1F202}]" +
            "|\\x{1F21A}|\\x{1F22F}|[\\x{1F232}-\\x{1F23A}]|[\\x{1F250}-\\x{1F251}]|[\\x{1F300}-\\x{1F30F}]" +
            "|[\\x{1F310}-\\x{1F31F}]|[\\x{1F320}-\\x{1F321}]|[\\x{1F324}-\\x{1F32F}]|[\\x{1F330}-\\x{1F33F}]" +
            "|[\\x{1F340}-\\x{1F34F}]|[\\x{1F350}-\\x{1F35F}]|[\\x{1F360}-\\x{1F36F}]|[\\x{1F370}-\\x{1F37F}]" +
            "|[\\x{1F380}-\\x{1F38F}]|[\\x{1F390}-\\x{1F393}]|[\\x{1F396}-\\x{1F397}]|[\\x{1F399}-\\x{1F39B}]" +
            "|[\\x{1F39E}-\\x{1F39F}]|[\\x{1F3A0}-\\x{1F3AF}]|[\\x{1F3B0}-\\x{1F3BF}]|[\\x{1F3C0}-\\x{1F3CF}]" +
            "|[\\x{1F3D0}-\\x{1F3DF}]|[\\x{1F3E0}-\\x{1F3EF}]|\\x{1F3F0}|[\\x{1F3F3}-\\x{1F3F5}]|[\\x{1F3F7}-\\x{1F3FF}]" +
            "|[\\x{1F400}-\\x{1F40F}]|[\\x{1F410}-\\x{1F41F}]|[\\x{1F420}-\\x{1F42F}]|[\\x{1F430}-\\x{1F43F}]" +
            "|[\\x{1F440}-\\x{1F44F}]|[\\x{1F450}-\\x{1F45F}]|[\\x{1F460}-\\x{1F46F}]|[\\x{1F470}-\\x{1F47F}]" +
            "|[\\x{1F480}-\\x{1F48F}]|[\\x{1F490}-\\x{1F49F}]|[\\x{1F4A0}-\\x{1F4AF}]|[\\x{1F4B0}-\\x{1F4BF}]" +
            "|[\\x{1F4C0}-\\x{1F4CF}]|[\\x{1F4D0}-\\x{1F4DF}]|[\\x{1F4E0}-\\x{1F4EF}]|[\\x{1F4F0}-\\x{1F4FF}]" +
            "|[\\x{1F500}-\\x{1F50F}]|[\\x{1F510}-\\x{1F51F}]|[\\x{1F520}-\\x{1F52F}]|[\\x{1F530}-\\x{1F53D}]" +
            "|[\\x{1F549}-\\x{1F54E}]|[\\x{1F550}-\\x{1F55F}]|[\\x{1F560}-\\x{1F56F}]|\\x{1F56F}|\\x{1F570}" +
            "|[\\x{1F573}-\\x{1F57A}]|\\x{1F587}|[\\x{1F58A}-\\x{1F58D}]|\\x{1F590}|[\\x{1F595}-\\x{1F596}]" +
            "|[\\x{1F5A4}-\\x{1F5A5}]|\\x{1F5A8}|[\\x{1F5B1}-\\x{1F5B2}]|\\x{1F5BC}|[\\x{1F5C2}-\\x{1F5C4}]" +
            "|[\\x{1F5D1}-\\x{1F5D3}]|[\\x{1F5DC}-\\x{1F5DE}]|\\x{1F5E1}|\\x{1F5E3}|\\x{1F5E8}|\\x{1F5EF}|\\x{1F5F3}" +
            "|[\\x{1F5FA}-\\x{1F5FF}]|[\\x{1F600}-\\x{1F60F}]|[\\x{1F610}-\\x{1F61F}]|[\\x{1F620}-\\x{1F62F}]" +
            "|[\\x{1F630}-\\x{1F63F}]|[\\x{1F640}-\\x{1F64F}]|[\\x{1F650}-\\x{1F65F}]|[\\x{1F660}-\\x{1F66F}]" +
            "|[\\x{1F670}-\\x{1F67F}]|[\\x{1F680}-\\x{1F68F}]|[\\x{1F690}-\\x{1F69F}]|[\\x{1F6A0}-\\x{1F6AF}]" +
            "|[\\x{1F6B0}-\\x{1F6BF}]|[\\x{1F6C0}-\\x{1F6C5}]|[\\x{1F6CB}-\\x{1F6CF}]|[\\x{1F6D0}-\\x{1F6D2}]" +
            "|[\\x{1F6D5}-\\x{1F6D7}]|[\\x{1F6DD}-\\x{1F6DF}]|[\\x{1F6E0}-\\x{1F6E5}]|\\x{1F6E9}|[\\x{1F6EB}-\\x{1F6EC}]" +
            "|\\x{1F6F0}|[\\x{1F6F3}-\\x{1F6FC}]|[\\x{1F7E0}-\\x{1F7EB}]|\\x{1F7F0}|[\\x{1F90C}-\\x{1F90F}]" +
            "|[\\x{1F910}-\\x{1F91F}]|[\\x{1F920}-\\x{1F92F}]|[\\x{1F930}-\\x{1F93A}]|[\\x{1F93C}-\\x{1F93F}]" +
            "|[\\x{1F940}-\\x{1F945}]|[\\x{1F947}-\\x{1F94C}]|[\\x{1F94D}-\\x{1F94F}]|[\\x{1F950}-\\x{1F95F}]" +
            "|[\\x{1F960}-\\x{1F96F}]|[\\x{1F970}-\\x{1F97F}]|[\\x{1F980}-\\x{1F98F}]|[\\x{1F990}-\\x{1F99F}]" +
            "|[\\x{1F9A0}-\\x{1F9AF}]|[\\x{1F9B0}-\\x{1F9BF}]|[\\x{1F9C0}-\\x{1F9CF}]|[\\x{1F9D0}-\\x{1F9DF}]" +
            "|[\\x{1F9E0}-\\x{1F9EF}]|[\\x{1F9F0}-\\x{1F9FF}]|[\\x{1FA70}-\\x{1FA74}]|[\\x{1FA78}-\\x{1FA7C}]" +
            "|[\\x{1FA80}-\\x{1FA86}]|[\\x{1FA90}-\\x{1FA9F}]|[\\x{1FAA0}-\\x{1FAAC}]|[\\x{1FAB0}-\\x{1FABA}]" +
            "|[\\x{1FAC0}-\\x{1FAC5}]|[\\x{1FAD0}-\\x{1FAD9}]|[\\x{1FAE0}-\\x{1FAE7}]|[\\x{1FAF0}-\\x{1FAF6}]"
        let keycapBase = "[\\x{0023}\\x{002A}\\x{0030}-\\x{0039}]"
        let eMod = "[\\x{1F3FB}-\\x{1F3FF}]"
        let variationSelector = "\\x{FE0F}"
        let keycap = "\\x{20E3}"
        let tags = "[\\x{E0020}-\\x{E007E}]"
        let termTag = "\\x{E007F}"
        let zwj = "\\x{200D}"
        let risequence = ri + ri
        let keycapEmoji = keycapBase + variationSelector + "?" + keycap
        let element = "(?:" + support + ")(?:" + eMod + "|" + variationSelector + "|" + tags + "+" + termTag + "?)?"
        return keycapEmoji + "|" + risequence + "|" + element + "(?:" + zwj + "(?:" + risequence + "|" + element + "))*"
    }()

    func sanitize(text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        if let regex = customEmojiRegex {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let regex = universalEmojiRegex {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Universal emoji pattern

    private init() {
        customEmojiRegex = try? NSRegularExpression(pattern: "\\[[^\\]]+\\]", options: [])
        universalEmojiRegex = try? NSRegularExpression(pattern: Self.universalEmojiPattern, options: [])
    }
}
