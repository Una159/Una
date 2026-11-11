import Foundation

enum UnaMusicProvider: String, Codable, CaseIterable, Sendable {
    case netease
    case kugou
    case qishui
    case qqmusic
}

struct UnaGatewayTrack: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var artist: String
    var album: String?
    var duration: Double?
    var artworkURL: String?
    var pageURL: String?
    var streamURL: String?
    var provider: UnaMusicProvider

    /// Provider-scoped identity prevents identical upstream IDs colliding across services.
    var playbackKey: String { "\(provider.rawValue):\(id)" }
}

struct UnaGatewayPlaylist: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var creator: String?
    var coverURL: String?
    var trackCount: Int?
}

struct UnaGatewayLyrics: Codable, Sendable {
    var lyric: String?
    var translated: String?
}

struct UnaGatewayQRSession: Codable, Sendable {
    var session: String
    var qrURL: URL?
    var qrImage: String?
    var status: String
}

struct UnaGatewayQRStatus: Codable, Sendable {
    var status: String
    var credential: String?
    var message: String?
}

enum UnaGatewayError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int, String)
    case apiError(String)
    case missingPlaybackURL

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL: return "Una 网关地址无效"
        case .invalidResponse: return "音乐网关返回了无法识别的数据"
        case .httpStatus(let code, let message): return "网关请求失败（\(code)）：\(message)"
        case .apiError(let message): return message
        case .missingPlaybackURL: return "该歌曲当前没有可用的授权播放地址"
        }
    }
}

/// Client for Una's Cloudflare gateway. Provider credentials are sent only in request headers.
final class UnaGatewayAPIClient: @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    init(baseURL: String, apiKey: String, session: URLSession? = nil) throws {
        guard let url = URL(string: baseURL),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw UnaGatewayError.invalidBaseURL
        }
        self.baseURL = url
        self.apiKey = apiKey
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 45
            configuration.httpMaximumConnectionsPerHost = 6
            self.session = URLSession(configuration: configuration)
        }
    }

    func search(provider: UnaMusicProvider, keywords: String, limit: Int = 20, cookie: String? = nil) async throws -> [UnaGatewayTrack] {
        let query = [URLQueryItem(name: "keywords", value: keywords), URLQueryItem(name: "limit", value: String(limit))]
        let object = try await get(providerPath(provider, "search"), query: query, cookie: cookie)
        return try decodeData([UnaGatewayTrack].self, from: object)
    }

    func songURL(provider: UnaMusicProvider, id: String, cookie: String? = nil) async throws -> URL {
        let object = try await get(providerPath(provider, "song/url"), query: [URLQueryItem(name: "id", value: id)], cookie: cookie)
        let envelope = try JSONSerialization.jsonObject(with: object) as? [String: Any]
        let data = envelope?["data"] as? [String: Any]
        guard let raw = data?["url"] as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil, url.password == nil else {
            throw UnaGatewayError.missingPlaybackURL
        }
        return url
    }

    func lyrics(provider: UnaMusicProvider, id: String, cookie: String? = nil) async throws -> UnaGatewayLyrics {
        let object = try await get(providerPath(provider, "lyric"), query: [URLQueryItem(name: "id", value: id)], cookie: cookie)
        return try decodeNestedData(UnaGatewayLyrics.self, from: object)
    }

    func playlists(provider: UnaMusicProvider, uid: String? = nil, uin: String? = nil, cookie: String? = nil) async throws -> [UnaGatewayPlaylist] {
        var query = [URLQueryItem(name: "limit", value: "30")]
        if let uid { query.append(URLQueryItem(name: "uid", value: uid)) }
        if let uin { query.append(URLQueryItem(name: "uin", value: uin)) }
        return try decodeData([UnaGatewayPlaylist].self, from: await get(providerPath(provider, "playlist"), query: query, cookie: cookie))
    }

    func playlistTracks(provider: UnaMusicProvider, playlistID: String, limit: Int = 100, cookie: String? = nil) async throws -> [UnaGatewayTrack] {
        let query = [URLQueryItem(name: "id", value: playlistID), URLQueryItem(name: "limit", value: String(limit))]
        return try decodeData([UnaGatewayTrack].self, from: await get(providerPath(provider, "playlist/tracks"), query: query, cookie: cookie))
    }

    func createQRLogin(provider: UnaMusicProvider) async throws -> UnaGatewayQRSession {
        let object = try await get("/una/auth/\(provider.rawValue)/qr/create")
        let value = try JSONSerialization.jsonObject(with: object) as? [String: Any] ?? [:]
        let data = value["data"] as? [String: Any] ?? value
        let sessionID = (data["session"] as? String) ?? (data["key"] as? String) ?? (data["unikey"] as? String) ?? ""
        guard !sessionID.isEmpty else { throw UnaGatewayError.invalidResponse }
        let qrString = (data["qrUrl"] as? String) ?? (data["qrurl"] as? String) ?? (data["url"] as? String)
        return UnaGatewayQRSession(session: sessionID, qrURL: qrString.flatMap(URL.init(string:)), qrImage: data["qrImage"] as? String ?? data["qrimg"] as? String, status: data["status"] as? String ?? "waiting")
    }

    func checkQRLogin(provider: UnaMusicProvider, sessionID: String) async throws -> UnaGatewayQRStatus {
        let query = [URLQueryItem(name: "session", value: sessionID)]
        let object = try await get("/una/auth/\(provider.rawValue)/qr/check", query: query)
        let value = try JSONSerialization.jsonObject(with: object) as? [String: Any] ?? [:]
        let data = value["data"] as? [String: Any] ?? value
        return UnaGatewayQRStatus(status: data["status"] as? String ?? "waiting", credential: data["credential"] as? String ?? data["cookie"] as? String, message: data["message"] as? String)
    }

    private func providerPath(_ provider: UnaMusicProvider, _ suffix: String) -> String {
        "/una/v1/\(provider.rawValue)/\(suffix)"
    }

    private func get(_ path: String, query: [URLQueryItem] = [], cookie: String? = nil) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw UnaGatewayError.invalidBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Una-Gateway-Key")
        if let cookie, !cookie.isEmpty { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UnaGatewayError.invalidResponse }
        guard data.count <= 15 * 1024 * 1024 else { throw UnaGatewayError.apiError("网关响应过大，已停止解析") }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "未知错误"
            throw UnaGatewayError.httpStatus(http.statusCode, message)
        }
        return data
    }

    private func decodeData<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let code = root["code"] as? Int, code != 0 {
            throw UnaGatewayError.apiError(root["message"] as? String ?? "平台接口返回错误")
        }
        guard let payload = root["data"] else { throw UnaGatewayError.invalidResponse }
        let nested = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(type, from: nested)
    }

    private func decodeNestedData<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let payload = root["data"] else { throw UnaGatewayError.invalidResponse }
        return try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: payload))
    }
}
