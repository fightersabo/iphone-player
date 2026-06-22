import SwiftUI

@main
struct AnimePlayerApp: App {
    @StateObject private var fileService = FileService()
    @StateObject private var subtitleService = OpenSubtitlesService()

    var body: some Scene {
        WindowGroup {
            VideoListView(
                viewModel: VideoLibraryViewModel(
                    fileService: fileService,
                    subtitleService: subtitleService
                )
            )
            .onAppear {
                tryAutoLogin()
            }
        }
    }

    private func tryAutoLogin() {
        guard let creds = OpenSubtitlesCredentials.load() else { return }
        Task {
            try? await subtitleService.login(
                apiKey: creds.apiKey,
                username: creds.username,
                password: creds.password
            )
        }
    }
}
