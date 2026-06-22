import Foundation

struct SubtitleSearchResult: Identifiable, Codable {
    let id: Int
    let title: String
    let language: String
    let languageCode: String
    let downloadCount: Int
    let rating: Int
    let url: String
    let format: String
    let releaseName: String?

    var formattedInfo: String {
        "\(language) \(rating > 0 ? "★\(rating)" : "") · \(downloadCount) downloads"
    }
}

struct OpenSubtitlesCredentials {
    var apiKey: String
    var username: String?
    var password: String?

    static let apiKeyKey = "opensubtitles_api_key"
    static let usernameKey = "opensubtitles_username"
    static let passwordKey = "opensubtitles_password"

    static func load() -> OpenSubtitlesCredentials? {
        let defaults = UserDefaults.standard
        guard let apiKey = defaults.string(forKey: apiKeyKey), !apiKey.isEmpty else {
            return nil
        }
        return OpenSubtitlesCredentials(
            apiKey: apiKey,
            username: defaults.string(forKey: usernameKey),
            password: defaults.string(forKey: passwordKey)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(apiKey, forKey: Self.apiKeyKey)
        defaults.set(username, forKey: Self.usernameKey)
        defaults.set(password, forKey: Self.passwordKey)
    }
}

enum SubtitleFormat: String {
    case srt = "srt"
    case vtt = "vtt"
    case ass = "ass"
    case sub = "sub"
}
