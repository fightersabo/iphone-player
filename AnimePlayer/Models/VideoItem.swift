import Foundation

struct VideoItem: Identifiable, Codable {
    let id: UUID
    var url: URL
    var title: String
    var duration: TimeInterval
    var lastPlayedTime: TimeInterval
    var subtitleLanguage: String?
    var subtitleURL: URL?
    var fileSize: Int64
    var createdAt: Date

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    var isMKV: Bool {
        fileExtension == "mkv"
    }

    var isMP4: Bool {
        fileExtension == "mp4"
    }

    var isPlayable: Bool {
        ["mkv", "mp4", "m4v", "mov", "avi", "wmv", "flv", "webm"].contains(fileExtension)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    init(url: URL, title: String? = nil, duration: TimeInterval = 0, fileSize: Int64 = 0) {
        self.id = UUID()
        self.url = url
        self.title = title ?? url.lastPathComponent
        self.duration = duration
        self.lastPlayedTime = 0
        self.fileSize = fileSize
        self.createdAt = Date()
    }
}
