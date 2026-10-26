import Foundation

enum AICallBargeIn {
    static func significantCharCount(_ text: String) -> Int {
        text.reduce(0) { count, ch in
            if ch.isLetter || ch.isNumber || ("\u{4e00}" ... "\u{9fff}").contains(ch) {
                return count + 1
            }
            return count
        }
    }

    static func normalize(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            if ch.isWhitespace || punctuation.contains(ch) { continue }
            result.append(ch)
        }
        return result
    }

    static func looksLikeCommitted(_ asrText: String, committed: String) -> Bool {
        let asr = normalize(asrText)
        let sent = normalize(committed)
        if asr.isEmpty || sent.isEmpty { return false }
        return asr == sent || sent.hasPrefix(asr)
    }

    static func extraBeyondCommitted(_ asrText: String, committed: String) -> String? {
        let asr = normalize(asrText)
        let sent = normalize(committed)
        if sent.isEmpty || !asr.hasPrefix(sent) || asr.count <= sent.count { return nil }
        return String(asr.dropFirst(sent.count))
    }

    static func looksLikeTtsEcho(_ asrText: String, llmText: String) -> Bool {
        let asr = normalize(asrText)
        let llm = normalize(llmText)
        if asr.count < 2 || llm.isEmpty { return false }
        if llm.contains(asr) { return true }
        let common = longestCommonRunLength(asr, llm)
        return common >= echoMinCommonRun && common * 3 >= asr.count * 2
    }

    static func longestCommonRunLength(_ a: String, _ b: String) -> Int {
        let x = Array(a)
        let y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: y.count + 1)
        var best = 0
        for i in 1 ... x.count {
            var current = [Int](repeating: 0, count: y.count + 1)
            for j in 1 ... y.count where x[i - 1] == y[j - 1] {
                current[j] = previous[j - 1] + 1
                best = max(best, current[j])
            }
            previous = current
        }
        return best
    }

    private static let echoMinCommonRun = 4

    static func isStableContinuation(previous: String, current: String) -> Bool {
        let prev = normalize(previous)
        let curr = normalize(current)
        if prev.isEmpty || curr.isEmpty { return false }
        if curr.hasPrefix(prev) || prev.hasPrefix(curr) { return true }
        return curr.commonPrefix(with: prev).count >= 2
    }

    static func shouldBargeIn(asrText: String, committed: String, llmText: String, minChars: Int) -> Bool {
        let extra = extraBeyondCommitted(asrText, committed: committed)
        let candidate = extra ?? asrText
        if extra == nil && looksLikeCommitted(asrText, committed: committed) { return false }
        if significantCharCount(candidate) < minChars { return false }
        if looksLikeTtsEcho(candidate, llmText: llmText) { return false }
        return true
    }

    private static let punctuation = CharacterSet(charactersIn: "，。、；：？！,“”‘’\"'（）()[]【】…—-,:;?!.")
}

private extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { contains($0) }
    }
}
