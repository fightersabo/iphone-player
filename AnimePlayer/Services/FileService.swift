import Foundation
import Combine

class FileService: ObservableObject {
    @Published var videos: [VideoItem] = []

    private let documentsURL: URL
    private let videosKey = "saved_videos"

    init() {
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadVideos()
    }

    func importVideo(from url: URL) {
        let filename = url.lastPathComponent
        let destinationURL = documentsURL.appendingPathComponent(filename)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)

            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            let video = VideoItem(
                url: destinationURL,
                title: filename.deletingFileExtension,
                fileSize: fileSize
            )
            videos.append(video)
            saveVideos()
        } catch {
            print("Failed to import video: \(error)")
        }
    }

    func scanDocuments() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            for file in files where file.isVideoFile {
                if !videos.contains(where: { $0.url == file }) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    let video = VideoItem(
                        url: file,
                        title: file.lastPathComponent.deletingFileExtension,
                        fileSize: fileSize
                    )
                    videos.append(video)
                }
            }
            saveVideos()
        } catch {
            print("Failed to scan documents: \(error)")
        }
    }

    func deleteVideo(_ video: VideoItem) {
        do {
            try FileManager.default.removeItem(at: video.url)
            videos.removeAll { $0.id == video.id }
            saveVideos()
        } catch {
            print("Failed to delete video: \(error)")
        }
    }

    func updatePlaybackPosition(for video: VideoItem, time: TimeInterval) {
        if let index = videos.firstIndex(where: { $0.id == video.id }) {
            videos[index].lastPlayedTime = time
            saveVideos()
        }
    }

    func saveSubtitle(for video: VideoItem, subtitleURL: URL) {
        let destination = documentsURL
            .appendingPathComponent(video.title)
            .appendingPathExtension(subtitleURL.pathExtension)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: subtitleURL, to: destination)

            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                videos[index].subtitleURL = destination
                saveVideos()
            }
        } catch {
            print("Failed to save subtitle: \(error)")
        }
    }

    private func loadVideos() {
        guard let data = UserDefaults.standard.data(forKey: videosKey) else { return }
        guard let saved = try? JSONDecoder().decode([VideoItem].self, from: data) else { return }

        var valid: [VideoItem] = []
        for video in saved {
            if FileManager.default.fileExists(atPath: video.url.path) {
                valid.append(video)
            }
        }
        videos = valid
    }

    private func saveVideos() {
        guard let data = try? JSONEncoder().encode(videos) else { return }
        UserDefaults.standard.set(data, forKey: videosKey)
    }
}

extension URL {
    var isVideoFile: Bool {
        let ext = pathExtension.lowercased()
        return ["mkv", "mp4", "m4v", "mov", "avi", "wmv", "flv", "webm"].contains(ext)
    }
}

extension String {
    var deletingFileExtension: String {
        (self as NSString).deletingPathExtension
    }
}


