import Foundation

struct Track: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var artist: String
    var album: String = ""
    var fileName: String
    var duration: TimeInterval = 0
    var addedAt: Date = Date()

    var displayArtist: String { artist.isEmpty ? "未知艺术家" : artist }
}

enum PlayerRepeatMode: String, CaseIterable {
    case off, all, one

    var symbol: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var next: PlayerRepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}
