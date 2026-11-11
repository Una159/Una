import SwiftUI
import AVFoundation
import Security
import CoreFoundation
import UIKit
import MediaPlayer

private enum UnaCredentialVault {
    private static let service = "com.una.music.credentials"

    static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8), !value.isEmpty else {
            throw UnaGatewayError.apiError("不能保存空的安全凭证")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw UnaGatewayError.apiError("无法更新钥匙串凭证（\(deleteStatus)）")
        }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw UnaGatewayError.apiError("安全凭证保存失败（\(status)）")
        }
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ account: String) throws {
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw UnaGatewayError.apiError("无法清除钥匙串凭证（\(status)）")
        }
    }
}


/// Owns the single online playback session so audio continues while SwiftUI tabs change.
@MainActor
private final class UnaRemoteAudioController: ObservableObject {
    static let shared = UnaRemoteAudioController()

    @Published private(set) var currentTrackID: String?
    @Published private(set) var isPlaying = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private var playbackObservation: NSKeyValueObservation?
    private var resumeAfterInterruption = false

    private init() {
        configureRemoteCommands()
        observeAudioSession()
    }

    func play(url: URL, track: UnaGatewayTrack) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw UnaGatewayError.apiError("播放地址必须使用 HTTPS")
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [])
        try audioSession.setActive(true)

        clearObservers()
        player?.pause()

        let item = AVPlayerItem(url: url)
        let nextPlayer = AVPlayer(playerItem: item)
        nextPlayer.allowsExternalPlayback = true
        player = nextPlayer
        currentTrackID = track.id

        playbackObservation = nextPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = observedPlayer.timeControlStatus == .playing
                self.updatePlaybackRate()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }

        timeObserver = nextPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.updateElapsedTime(time.seconds) }
        }

        updateNowPlaying(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
        nextPlayer.play()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updatePlaybackRate()
    }

    func resume() {
        guard player != nil else { return }
        player?.play()
        updatePlaybackRate()
    }

    func togglePlayback() {
        isPlaying ? pause() : resume()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        clearObservers()
        player = nil
        currentTrackID = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func clearObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        playbackObservation = nil
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let position = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.player?.seek(to: CMTime(seconds: position.positionTime, preferredTimescale: 600))
            }
            return .success
        }
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
    }

    private func observeAudioSession() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .began {
                    self.resumeAfterInterruption = self.isPlaying
                    self.pause()
                } else if type == .ended {
                    let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                    if self.resumeAfterInterruption && options.contains(.shouldResume) {
                        self.resume()
                    }
                    self.resumeAfterInterruption = false
                }
            }
        }

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pause() }
        }
    }

    private func updateNowPlaying(title: String, artist: String, album: String?, duration: Double?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPNowPlayingInfoPropertyPlaybackRate: 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0
        ]
        if let album, !album.isEmpty { info[MPMediaItemPropertyAlbumTitle] = album }
        if let duration, duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateElapsedTime(_ elapsed: Double) {
        guard elapsed.isFinite,
              var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, elapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updatePlaybackRate() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

struct GatewayMusicView: View {
    @AppStorage("una.gateway.baseURL") private var gatewayBaseURL = ""
    @State private var gatewayKeyDraft = ""
    @State private var provider: UnaMusicProvider = .netease
    @State private var searchText = ""
    @State private var tracks: [UnaGatewayTrack] = []
    @State private var playlists: [UnaGatewayPlaylist] = []
    @State private var selectedLyrics: String?
    @StateObject private var audioController = UnaRemoteAudioController.shared
    @State private var qrSession: UnaGatewayQRSession?
    @State private var qrPollingTask: Task<Void, Never>?
    @State private var qrStatus = "尚未登录"
    @State private var cookie: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let ink = Color(red: 0.91, green: 0.96, blue: 0.94)
    private let mint = Color(red: 0.64, green: 0.94, blue: 0.80)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                gatewaySettings
                providerPicker
                accountCard
                searchCard
                playlistCard
                if let selectedLyrics {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("歌词").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink)
                        Text(selectedLyrics).font(.system(size: 13)).foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.system(size: 12)).foregroundStyle(.orange)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .task {
            gatewayKeyDraft = UnaCredentialVault.read("gateway-api-key") ?? ""
            cookie = UnaCredentialVault.read("cookie-\(provider.rawValue)")
        }
        .onChange(of: provider) { _, value in
            cancelQRLogin()
            cookie = UnaCredentialVault.read("cookie-\(value.rawValue)")
            qrSession = nil
            qrStatus = cookie == nil ? "尚未登录" : "已保存登录凭证"
            tracks = []
            playlists = []
            selectedLyrics = nil
        }
    }

    private var gatewaySettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Una 音乐网关", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
            TextField("https://your-worker.workers.dev", text: $gatewayBaseURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.URL).font(.system(size: 13))
                .padding(13).background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
            SecureField("Gateway API Key", text: $gatewayKeyDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(.system(size: 13)).padding(13)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
            Button {
                do {
                    try UnaCredentialVault.save(gatewayKeyDraft, account: "gateway-api-key")
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Label("安全保存网关配置", systemImage: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(mint, in: Capsule())
            }
        }
        .padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("音乐平台").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
            Picker("音乐平台", selection: $provider) {
                Text("网易云").tag(UnaMusicProvider.netease)
                Text("酷狗").tag(UnaMusicProvider.kugou)
                Text("汽水").tag(UnaMusicProvider.qishui)
                Text("QQ 音乐").tag(UnaMusicProvider.qqmusic)
            }
            .pickerStyle(.segmented)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("平台账号").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    Text(qrStatus).font(.system(size: 12)).foregroundStyle(cookie == nil ? .white.opacity(0.45) : mint)
                }
                Spacer()
                Button {
                    Task { await startQRLogin() }
                } label: {
                    Label("扫码登录", systemImage: "qrcode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black).padding(.horizontal, 13).padding(.vertical, 10)
                        .background(mint, in: Capsule())
                }
                .disabled(isLoading)
            }
            if let qrSession {
                QRCodePreview(session: qrSession)
                Text("请使用对应平台官方 App 扫描二维码。").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                Button("取消二维码") { cancelQRLogin() }
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            if cookie != nil {
                Button(role: .destructive) {
                    do {
                        try UnaCredentialVault.remove("cookie-\(provider.rawValue)")
                        cookie = nil
                        qrStatus = "已退出"
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Label("退出此平台账号", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
        }
        .padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("搜索音乐").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
            HStack(spacing: 8) {
                TextField("歌曲、歌手或专辑", text: $searchText)
                    .font(.system(size: 13)).submitLabel(.search)
                    .onSubmit { Task { await search() } }
                Button { Task { await search() } } label: {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.black)
                        .frame(width: 38, height: 38).background(mint, in: Circle())
                }.disabled(isLoading || searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8).background(.black.opacity(0.22), in: Capsule())
            if isLoading { ProgressView().tint(mint).frame(maxWidth: .infinity) }
            ForEach(tracks) { track in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).font(.system(size: 13, weight: .medium)).foregroundStyle(ink).lineLimit(1)
                        Text([track.artist, track.album].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Button { Task { await showLyrics(track) } } label: {
                        Image(systemName: "text.quote").foregroundStyle(.white.opacity(0.7))
                    }.accessibilityLabel("查看歌词")
                    Button { Task { await play(track) } } label: {
                        Image(systemName: audioController.currentTrackID == track.id && audioController.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(mint).frame(width: 34, height: 34)
                    }.accessibilityLabel(audioController.currentTrackID == track.id && audioController.isPlaying ? "暂停" : "播放")
                }
                .padding(.vertical, 7)
                Divider().overlay(.white.opacity(0.06))
            }
            if !tracks.isEmpty {
                Text("仅显示平台当前授权可用的歌曲；无法播放的曲目不会绕过会员或 DRM 限制。")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var playlistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("我的歌单").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                Spacer()
                Button("刷新") { Task { await loadPlaylists() } }
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(mint)
            }
            if playlists.isEmpty {
                Text("登录后加载平台账号的歌单。").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(playlists) { playlist in
                    Button { Task { await loadPlaylist(playlist) } } label: {
                        HStack {
                            Image(systemName: "music.note.list").foregroundStyle(mint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(playlist.name).font(.system(size: 13, weight: .medium)).foregroundStyle(ink)
                                Text("\(playlist.trackCount ?? 0) 首歌曲").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        }.padding(.vertical, 7)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func makeClient() throws -> UnaGatewayAPIClient {
        let key = UnaCredentialVault.read("gateway-api-key") ?? gatewayKeyDraft
        guard !key.isEmpty else { throw UnaGatewayError.apiError("请先填写并保存 Gateway API Key") }
        return try UnaGatewayAPIClient(baseURL: gatewayBaseURL, apiKey: key)
    }

    @MainActor
    private func search() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { tracks = try await makeClient().search(provider: provider, keywords: searchText, cookie: cookie) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func loadPlaylists() async {
        guard cookie != nil else { errorMessage = "请先登录当前平台账号"; return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { playlists = try await makeClient().playlists(provider: provider, cookie: cookie) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func loadPlaylist(_ playlist: UnaGatewayPlaylist) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { tracks = try await makeClient().playlistTracks(provider: provider, playlistID: playlist.id, cookie: cookie) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func showLyrics(_ track: UnaGatewayTrack) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let lyrics = try await makeClient().lyrics(provider: provider, id: track.id, cookie: cookie)
            selectedLyrics = [lyrics.lyric, lyrics.translated].compactMap { $0 }.joined(separator: "\n\n")
            if selectedLyrics?.isEmpty == true { selectedLyrics = "平台暂未提供歌词。" }
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func play(_ track: UnaGatewayTrack) async {
        if audioController.currentTrackID == track.id {
            audioController.isPlaying ? audioController.pause() : audioController.resume()
            return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let url = try await makeClient().songURL(provider: provider, id: track.id, cookie: cookie)
            try audioController.play(url: url, track: track)
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func cancelQRLogin() {
        qrPollingTask?.cancel()
        qrPollingTask = nil
        qrSession = nil
        if cookie == nil { qrStatus = "已取消扫码" }
    }

    @MainActor
    private func startQRLogin() async {
        cancelQRLogin()
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await makeClient().createQRLogin(provider: provider)
            qrSession = session
            qrStatus = "等待扫码"
            let providerAtStart = provider
            qrPollingTask = Task { @MainActor in
                for _ in 0..<90 {
                    do {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    } catch {
                        return
                    }
                    guard !Task.isCancelled,
                          provider == providerAtStart,
                          qrSession?.session == session.session else { return }
                    do {
                        let state = try await makeClient().checkQRLogin(provider: providerAtStart, sessionID: session.session)
                        qrStatus = state.status
                        if let credential = state.credential, !credential.isEmpty {
                            do {
                                try UnaCredentialVault.save(credential, account: "cookie-\(providerAtStart.rawValue)")
                            } catch {
                                errorMessage = error.localizedDescription
                                qrStatus = "登录成功，但凭证保存失败"
                                return
                            }
                            cookie = credential
                            qrStatus = "登录成功，凭证已安全保存"
                            qrSession = nil
                            qrPollingTask = nil
                            return
                        }
                        if ["expired", "failed", "refused"].contains(state.status.lowercased()) {
                            qrStatus = state.message ?? "二维码已失效"
                            qrPollingTask = nil
                            return
                        }
                    } catch {
                        if !Task.isCancelled { errorMessage = error.localizedDescription }
                        qrPollingTask = nil
                        return
                    }
                }
                if qrSession?.session == session.session { qrStatus = "二维码轮询超时，请重新生成" }
                qrPollingTask = nil
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct QRCodePreview: View {
    let session: UnaGatewayQRSession

    var body: some View {
        VStack(spacing: 8) {
            if let raw = session.qrImage {
                let encoded = raw.components(separatedBy: ",").last ?? raw
                if let data = Data(base64Encoded: encoded), let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                        .frame(width: 190, height: 190).padding(8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                } else if let url = session.qrURL {
                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: {
                        ProgressView()
                    }.frame(width: 190, height: 190)
                }
            } else if let url = session.qrURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: {
                    ProgressView()
                }.frame(width: 190, height: 190)
            } else {
                Text("当前适配器未返回二维码图片").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }
}
