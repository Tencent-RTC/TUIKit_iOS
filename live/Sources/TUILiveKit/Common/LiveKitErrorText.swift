import AtomicXCore

enum LiveKitErrorText {
    static func message(_ error: ErrorInfo) -> String {
        let detail = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "AtomicXCore error (\(error.code))" : detail
    }
}
