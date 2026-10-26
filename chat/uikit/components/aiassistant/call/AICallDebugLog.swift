import Foundation

func AICallLog(_ message: String) {
    NSLog("%@", message)
    AICallDebugLog.shared.append(message)
}

final class AICallDebugLog {
    static let shared = AICallDebugLog()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.tencent.chatdemo.aicall.log")
    private static let maxBytes = 512 * 1024

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("aicall_debug.log")
    }

    func append(_ message: String) {
        queue.async {
            let line = "\(Date()): \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                defer { try? handle.close() }
                let offset = (try? handle.seekToEnd()) ?? 0
                if offset > Self.maxBytes {
                    try? handle.truncate(atOffset: 0)
                }
                try? handle.seekToEnd()
                handle.write(data)
            } else {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }
}
