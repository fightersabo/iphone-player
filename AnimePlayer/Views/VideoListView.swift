import SwiftUI
import UniformTypeIdentifiers

struct VideoListView: View {
    @StateObject var viewModel: VideoLibraryViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.videos.isEmpty {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "video.slash",
                        description: Text("Import videos from Files to get started")
                    )
                } else {
                    ForEach(viewModel.videos) { video in
                        NavigationLink {
                            PlayerView(video: video)
                        } label: {
                            VideoRow(video: video)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.deleteVideo(video)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                viewModel.selectedVideo = video
                                viewModel.showSubtitleSearch = true
                            } label: {
                                Label("Search Subtitles", systemImage: "captions.bubble")
                            }
                        }
                    }
                }
            }
            .navigationTitle("AnimePlayer")
            .searchable(text: $viewModel.searchText, prompt: "Search videos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            viewModel.showDocumentPicker = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            viewModel.openSettings()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                DocumentPicker(
                    types: [.mkv, .mpeg4Movie, .quickTimeMovie, .avi],
                    onPick: { url in
                        viewModel.importVideo(url: url)
                        viewModel.showDocumentPicker = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $viewModel.showSubtitleSearch) {
                if let video = viewModel.selectedVideo {
                    PrePlaySubtitleSearchView(
                        video: video,
                        fileService: viewModel.fileService
                    )
                }
            }
        }
    }
}

struct PrePlaySubtitleSearchView: View {
    let video: VideoItem
    let fileService: FileService
    @StateObject private var subtitleService = OpenSubtitlesService()
    @State private var results: [SubtitleSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView("Searching Arabic subtitles...")
                    Spacer()
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "No Subtitles",
                        systemImage: "captions.bubble",
                        description: Text("Search for Arabic subtitles for \"\(video.title)\"")
                    )
                } else {
                    List(results) { sub in
                        Button {
                            download(sub)
                        } label: {
                            SubtitleRow(subtitle: sub)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Subtitles - \(video.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Search") {
                        search()
                    }
                }
            }
        }
        .onAppear {
            loginAndSearch()
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loginAndSearch() {
        guard let creds = OpenSubtitlesCredentials.load() else {
            errorMessage = "Configure OpenSubtitles API key in Settings first"
            return
        }
        isLoading = true
        Task {
            do {
                try await subtitleService.login(apiKey: creds.apiKey, username: creds.username, password: creds.password)
                try await subtitleService.searchSubtitles(query: video.title, language: "ar")
                results = subtitleService.results
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func search() {
        isLoading = true
        Task {
            do {
                try await subtitleService.searchSubtitles(query: video.title, language: "ar")
                results = subtitleService.results
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func download(_ subtitle: SubtitleSearchResult) {
        isLoading = true
        Task {
            do {
                let url = try await subtitleService.downloadSubtitle(subtitle)
                fileService.saveSubtitle(for: video, subtitleURL: url)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct VideoRow: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)

                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(video.fileExtension.uppercased(), systemImage: "doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(video.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if video.lastPlayedTime > 0 {
                        Text("· \(video.formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if video.subtitleURL != nil {
                    Label("Subtitles available", systemImage: "captions.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }

            Spacer()

            if video.lastPlayedTime > 0 {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

extension UTType {
    static let mkv = UTType(filenameExtension: "mkv")!
    static let avi = UTType(filenameExtension: "avi")!
}

struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct SettingsView: View {
    @State private var apiKey = UserDefaults.standard.string(forKey: OpenSubtitlesCredentials.apiKeyKey) ?? ""
    @State private var username = UserDefaults.standard.string(forKey: OpenSubtitlesCredentials.usernameKey) ?? ""
    @State private var password = UserDefaults.standard.string(forKey: OpenSubtitlesCredentials.passwordKey) ?? ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenSubtitles API") {
                    TextField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Username (optional)", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password (optional)", text: $password)
                }

                Section {
                    Button("Save") {
                        let defaults = UserDefaults.standard
                        defaults.set(apiKey, forKey: OpenSubtitlesCredentials.apiKeyKey)
                        defaults.set(username, forKey: OpenSubtitlesCredentials.usernameKey)
                        defaults.set(password, forKey: OpenSubtitlesCredentials.passwordKey)
                        showAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }

                Section {
                    Link("Get API Key at opensubtitles.com",
                         destination: URL(string: "https://opensubtitles.com")!)
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .alert("Saved", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text("Settings saved successfully")
            }
        }
    }
}
