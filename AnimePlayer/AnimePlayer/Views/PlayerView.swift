import SwiftUI
import MobileVLCKit

struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(video: VideoItem) {
        let fileService = FileService()
        let subtitleService = OpenSubtitlesService()
        _viewModel = StateObject(wrappedValue: PlayerViewModel(
            video: video,
            fileService: fileService,
            subtitleService: subtitleService
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCPlayerView(
                video: viewModel.video,
                subtitleURL: viewModel.subtitleURL,
                onTimeChange: { time in
                    viewModel.currentTime = time
                    viewModel.saveProgress(time: time)
                },
                onDuration: { dur in
                    viewModel.duration = dur
                }
            )

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if viewModel.hasActiveSubtitle {
                        Button {
                            viewModel.showSubtitlePicker = true
                        } label: {
                            Image(systemName: "captions.bubble.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .padding(12)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    } else {
                        Button {
                            if viewModel.subtitleService.isLoggedIn {
                                viewModel.searchSubtitles()
                            } else {
                                viewModel.errorMessage = "Configure OpenSubtitles API key in Settings first"
                            }
                        } label: {
                            Image(systemName: "captions.bubble")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)

                Spacer()

                if viewModel.isLoadingSubtitles {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Searching Arabic subtitles...")
                            .foregroundStyle(.white)
                            .font(.caption)
                    }
                    .padding(16)
                    .background(.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .sheet(isPresented: $viewModel.showSubtitlePicker) {
            SubtitlePickerView(
                results: viewModel.subtitleResults,
                isLoading: viewModel.isLoadingSubtitles,
                onSelect: { subtitle in
                    viewModel.downloadSubtitle(subtitle)
                }
            )
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            Task {
                let creds = OpenSubtitlesCredentials.load()
                if let creds = creds {
                    try? await viewModel.subtitleService.login(
                        apiKey: creds.apiKey,
                        username: creds.username,
                        password: creds.password
                    )
                }
            }
        }
    }
}

struct VLCPlayerView: UIViewRepresentable {
    let video: VideoItem
    let subtitleURL: URL?
    let onTimeChange: (TimeInterval) -> Void
    let onDuration: (TimeInterval) -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let mediaPlayer = VLCMediaPlayer()
        mediaPlayer.drawable = container

        let media = VLCMedia(url: video.url)
        if let subURL = subtitleURL {
            media.addOptions([
                "sub-file": subURL.path
            ])
        }
        mediaPlayer.media = media

        if video.lastPlayedTime > 0 {
            mediaPlayer.position = Float(video.lastPlayedTime / max(video.duration, 1))
        }

        mediaPlayer.play()
        context.coordinator.mediaPlayer = mediaPlayer
        context.coordinator.startUpdates()

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if subtitleURL != context.coordinator.loadedSubtitleURL {
            context.coordinator.loadedSubtitleURL = subtitleURL
            if let subURL = subtitleURL {
                context.coordinator.mediaPlayer?.addPlaybackSlave(subURL, type: .subtitle, enforce: true)
            }
        }
    }

    func makeCoordinator() -> VLCPlayerCoordinator {
        VLCPlayerCoordinator(onTimeChange: onTimeChange, onDuration: onDuration)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: VLCPlayerCoordinator) {
        coordinator.mediaPlayer?.stop()
        coordinator.timer?.invalidate()
    }
}

class VLCPlayerCoordinator: NSObject {
    let onTimeChange: (TimeInterval) -> Void
    let onDuration: (TimeInterval) -> Void
    var mediaPlayer: VLCMediaPlayer?
    var timer: Timer?
    var loadedSubtitleURL: URL?

    init(onTimeChange: @escaping (TimeInterval) -> Void,
         onDuration: @escaping (TimeInterval) -> Void) {
        self.onTimeChange = onTimeChange
        self.onDuration = onDuration
    }

    func startUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.mediaPlayer else { return }
            self.onTimeChange(TimeInterval(player.time.value.intValue / 1000))
            self.onDuration(TimeInterval(player.media.length.value.intValue / 1000))
        }
    }
}
