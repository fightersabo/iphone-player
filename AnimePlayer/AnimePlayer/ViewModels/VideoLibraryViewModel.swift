import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class VideoLibraryViewModel: ObservableObject {
    @Published var fileService: FileService
    @Published var subtitleService: OpenSubtitlesService
    @Published var showDocumentPicker = false
    @Published var showSettings = false
    @Published var searchText = ""
    @Published var selectedVideo: VideoItem?
    @Published var showSubtitleSearch = false

    var videos: [VideoItem] {
        if searchText.isEmpty {
            return fileService.videos
        }
        return fileService.videos.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    init(fileService: FileService, subtitleService: OpenSubtitlesService) {
        self.fileService = fileService
        self.subtitleService = subtitleService
        fileService.scanDocuments()
    }

    func importVideo(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        fileService.importVideo(from: url)
    }

    func deleteVideo(_ video: VideoItem) {
        fileService.deleteVideo(video)
    }

    func openSettings() {
        showSettings = true
    }
}
