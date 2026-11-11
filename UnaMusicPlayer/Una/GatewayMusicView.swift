import SwiftUI
import AVFoundation
import Security
import CoreFoundation
import UIKit

private enum UnaCredentialVault {
    private static let service = "com.una.music.credentials"

    static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
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

    static func remove(_ account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
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
    @State private var remotePlayer: AVPlayer?
    @State private var playingTrackID: String?
    @State private var qrSession: UnaGatewayQRSession?
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
                UnaCredentialVault.save(gatewayKeyDraft, account: "gateway-api-key")
                errorMessage = nil
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
                Button("取消二维码") { self.qrSession = nil }
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            if cookie != nil {
                Button(role: .destructive) {
                    UnaCredentialVault.remove("cookie-\(provider.rawValue)")
                    cookie = nil
                    qrStatus = "已退出"
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
                        Image(systemName: playingTrackID == track.id ? "pause.fill" : "play.fill")
                            .foregroundStyle(mint).frame(width: 34, height: 34)
                    }.accessibilityLabel("播放")
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
        if playingTrackID == track.id {
            remotePlayer?.pause()
            playingTrackID = nil
            return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let url = try await makeClient().songURL(provider: provider, id: track.id, cookie: cookie)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            let nextPlayer = AVPlayer(url: url)
            remotePlayer?.pause()
            remotePlayer = nextPlayer
            playingTrackID = track.id
            nextPlayer.play()
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func startQRLogin() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await makeClient().createQRLogin(provider: provider)
            qrSession = session
            qrStatus = "等待扫码"
            let providerAtStart = provider
            Task { @MainActor in
                for _ in 0..<90 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard provider == providerAtStart, qrSession?.session == session.session else { return }
                    do {
                        let state = try await makeClient().checkQRLogin(provider: providerAtStart, sessionID: session.session)
                        qrStatus = state.status
                        if let credential = state.credential, !credential.isEmpty {
                            UnaCredentialVault.save(credential, account: "cookie-\(providerAtStart.rawValue)")
                            cookie = credential
                            qrStatus = "登录成功，凭证已安全保存"
                            qrSession = nil
                            return
                        }
                        if ["expired", "failed", "refused"].contains(state.status.lowercased()) {
                            qrStatus = state.message ?? "二维码已失效"
                            return
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        return
                    }
                }
                if qrSession?.session == session.session { qrStatus = "二维码轮询超时，请重新生成" }
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
