import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var video: VideoItem
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoadingSubtitles = false
    @Published var subtitleResults: [SubtitleSearchResult] = []
    @Published var showSubtitlePicker = false
    @Published var errorMessage: String?
    @Published var subtitleURL: URL?
    @Published var hasActiveSubtitle = false

    let subtitleService: OpenSubtitlesService
    private let fileService: FileService

    init(video: VideoItem, fileService: FileService, subtitleService: OpenSubtitlesService) {
        self.video = video
        self.fileService = fileService
        self.subtitleService = subtitleService
        self.subtitleURL = video.subtitleURL
        self.hasActiveSubtitle = video.subtitleURL != nil
    }

    func searchSubtitles() {
        guard subtitleService.isLoggedIn else {
            errorMessage = "Configure OpenSubtitles API key in Settings first"
            return
        }
        showSubtitlePicker = true
        isLoadingSubtitles = true

        Task {
            do {
                try await subtitleService.searchSubtitles(query: video.title)
                subtitleResults = subtitleService.results
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingSubtitles = false
        }
    }

    func downloadSubtitle(_ subtitle: SubtitleSearchResult) {
        isLoadingSubtitles = true
        Task {
            do {
                let url = try await subtitleService.downloadSubtitle(subtitle)
                fileService.saveSubtitle(for: video, subtitleURL: url)
                subtitleURL = url
                hasActiveSubtitle = true
                showSubtitlePicker = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingSubtitles = false
        }
    }

    func removeSubtitle() {
        subtitleURL = nil
        hasActiveSubtitle = false
    }

    func saveProgress(time: TimeInterval) {
        fileService.updatePlaybackPosition(for: video, time: time)
    }

    func clearError() {
        errorMessage = nil
    }
}
