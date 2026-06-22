import SwiftUI

struct SubtitlePickerView: View {
    let results: [SubtitleSearchResult]
    let isLoading: Bool
    let onSelect: (SubtitleSearchResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredResults: [SubtitleSearchResult] {
        if searchText.isEmpty { return results }
        return results.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.language.localizedCaseInsensitiveContains(searchText) ||
            ($0.releaseName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "No Subtitles Found",
                        systemImage: "captions.bubble",
                        description: Text("Try a different search term")
                    )
                } else {
                    List(filteredResults) { subtitle in
                        Button {
                            onSelect(subtitle)
                            dismiss()
                        } label: {
                            SubtitleRow(subtitle: subtitle)
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "Filter results")
                }
            }
            .navigationTitle("Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct SubtitleRow: View {
    let subtitle: SubtitleSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(subtitle.language)
                    .font(.headline)

                Spacer()

                Text(subtitle.format.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }

            Text(subtitle.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                if subtitle.rating > 0 {
                    Label("\(subtitle.rating)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                Label("\(subtitle.downloadCount)", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let release = subtitle.releaseName {
                    Text(release)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SubtitlePickerView(
        results: [
            SubtitleSearchResult(
                id: 1,
                title: "Movie Title",
                language: "English",
                languageCode: "en",
                downloadCount: 1234,
                rating: 5,
                url: "https://example.com",
                format: "srt",
                releaseName: "Movie.2024.1080p.WEB-DL"
            )
        ],
        isLoading: false,
        onSelect: { _ in }
    )
}
