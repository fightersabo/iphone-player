import Foundation
import Combine

enum OpenSubtitlesError: LocalizedError {
    case noAPIKey
    case loginFailed(String)
    case searchFailed(String)
    case downloadFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "OpenSubtitles API key not configured. Set it in Settings."
        case .loginFailed(let msg): return "Login failed: \(msg)"
        case .searchFailed(let msg): return "Search failed: \(msg)"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .invalidResponse: return "Invalid server response"
        }
    }
}

class OpenSubtitlesService: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isSearching = false
    @Published var results: [SubtitleSearchResult] = []

    private let baseURL = "https://api.opensubtitles.com/api/v1"
    private var bearerToken: String?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func login(apiKey: String, username: String? = nil, password: String? = nil) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/login")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")

        var body: [String: String] = [:]
        if let user = username, let pass = password {
            body["username"] = user
            body["password"] = pass
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenSubtitlesError.loginFailed("No response")
        }

        struct LoginResponse: Codable {
            let token: String?
            let status: Int?
            let message: String?
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

        if httpResponse.statusCode == 200, let token = loginResponse.token {
            bearerToken = token
            await MainActor.run { isLoggedIn = true }
        } else {
            throw OpenSubtitlesError.loginFailed(loginResponse.message ?? "Unknown error")
        }
    }

    func searchSubtitles(query: String, language: String = "ar") async throws {
        guard let token = bearerToken else {
            throw OpenSubtitlesError.loginFailed("Not logged in")
        }

        await MainActor.run {
            isSearching = true
            results = []
        }

        var components = URLComponents(string: "\(baseURL)/subtitles")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "languages", value: language),
            URLQueryItem(name: "order_by", value: "download_count"),
            URLQueryItem(name: "order_direction", value: "desc"),
            URLQueryItem(name: "limit", value: "30")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            await MainActor.run { isSearching = false }
            throw OpenSubtitlesError.searchFailed("No response")
        }

        struct SearchResponse: Codable {
            let totalCount: Int?
            let data: [SubtitleEntry]?

            enum CodingKeys: String, CodingKey {
                case totalCount = "total_count"
                case data
            }
        }

        struct SubtitleEntry: Codable {
            let id: String?
            let attributes: SubtitleAttributes?
        }

        struct SubtitleAttributes: Codable {
            let title: String?
            let language: String?
            let languageCode: String?
            let downloadCount: Int?
            let rating: Int?
            let url: String?
            let format: String?
            let releaseName: String?
            let files: [SubtitleFile]?

            enum CodingKeys: String, CodingKey {
                case title, language, url, format, rating, files
                case languageCode = "language_code"
                case downloadCount = "download_count"
                case releaseName = "release_name"
            }
        }

        struct SubtitleFile: Codable {
            let fileId: Int?

            enum CodingKeys: String, CodingKey {
                case fileId = "file_id"
            }
        }

        if httpResponse.statusCode == 200 {
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            let entries = searchResponse.data ?? []

            await MainActor.run {
                results = entries.compactMap { entry in
                    guard let attrs = entry.attributes,
                          let idStr = entry.id,
                          let id = Int(idStr) else { return nil }
                    return SubtitleSearchResult(
                        id: id,
                        title: attrs.title ?? "Unknown",
                        language: attrs.language ?? "Unknown",
                        languageCode: attrs.languageCode ?? "en",
                        downloadCount: attrs.downloadCount ?? 0,
                        rating: attrs.rating ?? 0,
                        url: attrs.url ?? "",
                        format: attrs.format ?? "srt",
                        releaseName: attrs.releaseName
                    )
                }
                isSearching = false
            }
        } else {
            await MainActor.run { isSearching = false }
            throw OpenSubtitlesError.searchFailed("HTTP \(httpResponse.statusCode)")
        }
    }

    func downloadSubtitle(_ subtitle: SubtitleSearchResult) async throws -> URL {
        guard let token = bearerToken else {
            throw OpenSubtitlesError.loginFailed("Not logged in")
        }

        let body: [String: Any] = [
            "file_id": subtitle.id
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/download")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenSubtitlesError.downloadFailed("No response")
        }

        struct DownloadResponse: Codable {
            let link: String?
            let fileName: String?

            enum CodingKeys: String, CodingKey {
                case link
                case fileName = "file_name"
            }
        }

        if httpResponse.statusCode == 200 {
            let downloadResponse = try JSONDecoder().decode(DownloadResponse.self, from: data)
            guard let downloadLink = downloadResponse.link,
                  let downloadURL = URL(string: downloadLink) else {
                throw OpenSubtitlesError.downloadFailed("No download link")
            }

            let subData = try await session.data(from: downloadURL)
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = downloadResponse.fileName ?? "subtitle.\(subtitle.format)"
            let destination = tempDir.appendingPathComponent(fileName)

            try subData.0.write(to: destination)
            return destination
        } else {
            throw OpenSubtitlesError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }
    }

    func logout() {
        bearerToken = nil
        isLoggedIn = false
        results = []
    }
}
