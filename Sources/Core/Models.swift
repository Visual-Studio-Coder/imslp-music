import Foundation
import SwiftData

struct Composer: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var sourceURL: URL { IMSLPClient.pageURL(id) }
}
struct Work: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var composer: String
    var sourceURL: URL { IMSLPClient.pageURL(id) }
    static func from(_ page: String) -> Work {
        let title = page.replacingOccurrences(of: "_", with: " ")
        if let range = title.range(of: " (", options: .backwards), title.hasSuffix(")") {
            return Work(id: page, title: String(title[..<range.lowerBound]), composer: String(title[range.upperBound...].dropLast()))
        }
        return Work(id: page, title: title, composer: "")
    }
}
struct Track: Identifiable, Codable, Hashable, Sendable {
    var id: String { fileName }
    var fileName: String
    var title: String
    var work: Work
    var performer: String
    var license: String
    var recordingID: String
    var isSynthesized: Bool
    var audioURL: URL?
    var artworkURL: URL?
    var filePageURL: URL?
    var accessRegion: String?
    var needsSourceAccess: Bool { audioURL == nil && filePageURL != nil }
    var sourceURL: URL { filePageURL ?? work.sourceURL }
}
struct Recording: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var performer: String
    var license: String
    var isSynthesized: Bool
    var tracks: [Track]
    var artworkURL: URL?
    var artworkFileName: String?
}
struct WorkDetail: Codable, Sendable {
    var work: Work
    var recordings: [Recording]
}
struct SearchResults: Sendable {
    var works: [Work] = []
    var composers: [Composer] = []
    var nextOffset: Int?
}
struct QueueEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var track: Track
}
struct MusicPlaylist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var entries: [QueueEntry] = []
}
struct LibrarySnapshot: Codable {
    var tracks: [Track] = []
    var favorites: Set<String> = []
    var playlists: [MusicPlaylist] = []
    var recent: [Track] = []
    var queue: [QueueEntry] = []
    var queueIndex: Int = 0
    var downloads: [String: String] = [:]
    var downloadedTracks: [Track]? = []
    var queueOrder: [UUID]? = []
    var repeatMode: Int = 0
    var shuffle: Bool = false
}
@Model final class LibraryRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String = "library-v1", payload: Data) { self.key = key; self.payload = payload }
}

enum SourceError: LocalizedError {
    case offline, unavailable, malformed, unsupported, status(Int), sourceAccess(String?)
    var errorDescription: String? {
        switch self {
        case .offline: return "No Internet Connection"
        case .unavailable: return "This recording needs attention on IMSLP. Open its source page to check access."
        case .sourceAccess(let region): return "IMSLP does not provide a public player URL for this recording." + (region.map { " Its source is marked \($0)." } ?? "") + " Open its file page to check available access. The website may require human verification."
        case .malformed: return "IMSLP returned an unreadable response. Try again or open the source page."
        case .unsupported: return "This audio format cannot play on this device."
        case .status(let code): return "IMSLP returned status \(code). Try again later."
        }
    }
}
