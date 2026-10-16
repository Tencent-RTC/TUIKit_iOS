import Foundation

/// Access App diagnostics. Matches super_player's LiteAV .xlog/.clog scope.
enum LogShareFiles {
    struct Entry {
        let url: URL
        let modified: Date
        let size: Int64
    }

    struct Export {
        let directory: URL
        let file: URL

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    static func scan() throws -> [Entry] {
        let manager = FileManager.default
        let documents = try manager.url(for: .documentDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: false)
        let directory = documents.appendingPathComponent("log", isDirectory: true)
        guard manager.fileExists(atPath: directory.path) else { return [] }
        return try manager.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles])
            .filter { ["xlog", "clog"].contains($0.pathExtension.lowercased()) }
            .compactMap { url in
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
                return Entry(url: url, modified: values.contentModificationDate ?? .distantPast,
                             size: Int64(values.fileSize ?? 0))
            }
            .sorted { $0.modified == $1.modified ? $0.url.lastPathComponent > $1.url.lastPathComponent : $0.modified > $1.modified }
    }

    /// Called on a worker queue. Only copies logs; never modifies the SDK directory.
    static func prepare(_ entries: [Entry], archive: Bool) throws -> Export {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("LiveKitLogExports", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let oldExports = (try? manager.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for url in oldExports {
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               date < Date().addingTimeInterval(-86400) {
                try? manager.removeItem(at: url)
            }
        }
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            guard !entries.isEmpty else { throw CocoaError(.fileNoSuchFile) }
            let snapshot = directory.appendingPathComponent("Logs", isDirectory: true)
            try manager.createDirectory(at: snapshot, withIntermediateDirectories: true)
            for entry in entries {
                try manager.copyItem(at: entry.url, to: snapshot.appendingPathComponent(entry.url.lastPathComponent))
            }
            if !archive {
                return Export(directory: directory, file: snapshot.appendingPathComponent(entries[0].url.lastPathComponent))
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let zip = directory.appendingPathComponent("LiveKit-Logs-\(formatter.string(from: Date())).zip")
            // Foundation supplies a ZIP representation of a directory without a new dependency.
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: snapshot, options: .forUploading,
                                           error: &coordinationError) { archiveURL in
                do { try manager.copyItem(at: archiveURL, to: zip) }
                catch { copyError = error }
            }
            if let error = coordinationError { throw error }
            if let error = copyError { throw error }
            guard manager.fileExists(atPath: zip.path) else { throw CocoaError(.fileReadUnknown) }
            try manager.removeItem(at: snapshot)
            return Export(directory: directory, file: zip)
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }
}
