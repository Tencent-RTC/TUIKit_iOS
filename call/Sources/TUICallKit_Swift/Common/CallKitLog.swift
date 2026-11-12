import AtomicXCore
import Foundation

enum CallKitLog {

    static func info(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: 0, file: file, line: line)
    }

    static func warning(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: 1, file: file, line: line)
    }

    static func error(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: 2, file: file, line: line)
    }

    private static func log(_ message: String, level: Int, file: String, line: Int) {
        let text = "TUICallKit - \(message)"
        let dictionary: [String: Any] = [
            "api": "TuikitLog",
            "params": [
                "level": level,
                "message": text,
                "file": file,
                "line": line,
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let json = String(data: data, encoding: .utf8) else { return }
        CallStore.shared.callExperimentalAPI(jsonStr: json)
    }
}
