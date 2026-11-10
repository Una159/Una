import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: AudioPlayer
    @State private var selectedTab = 0
    @State private var showPlayer = false
    @State private var showImporter = false

    private let ink = Color(red: 0.91, green: 0.96, blue: 0.94)
    private let mint = Color(red: 0.64, green: 0.94, blue: 0.80)

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                Group {
                    switch selectedTab {
                    case 0: libraryView
                    case 1: playlistsView
                    default: settingsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if player.currentTrack != nil { miniPlayer }
                tabBar
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): library.importFiles(urls)
            case .failure(let error): library.importError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showPlayer) { NowPlayingView().environmentObject(player).environmentObject(library) }
        .alert("提示", isPresented: Binding(get: { library.importError != nil }, set: { if !$0 { library.importError = nil } })) {
            Button("好", role: .cancel) { library.importError = nil }
        } message: { Text(library.importError ?? "") }
        .onAppear { player.setFileResolver { library.fileURL(for: $0) } }
    }

    private var background: some View {
        ZStack {
            Color(red: 0.035, green: 0.055, blue: 0.065)
            Circle().fill(Color.teal.opacity(0.20)).frame(width: 280).blur(radius: 100).offset(x: 150, y: -260)
            Circle().fill(Color.blue.opacity(0.12)).frame(width: 240).blur(radius: 110).offset(x: -150, y: 160)
        }.ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("UNA").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(5).foregroundStyle(mint)
                Text(selectedTab == 0 ? "你的音乐" : selectedTab == 1 ? "播放空间" : "设置")
                    .font(.system(size: 31, weight: .semibold, design: .rounded)).foregroundStyle(ink)
            }
            Spacer()
            Button { showImporter = true } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ink).frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .accessibilityLabel("导入音乐")
        }
        .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 18)
    }

    private var libraryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
                    TextField("搜索歌曲、艺术家或专辑", text: $library.searchText)
                        .foregroundStyle(.white)
                }
                .padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.09), lineWidth: 1))

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR SOUND").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(mint)
                        Text("\(library.tracks.count) 首音乐").font(.system(size: 22, weight: .semibold)).foregroundStyle(ink)
                    }
                    Spacer()
                    Button { showImporter = true } label: {
                        Label("导入音乐", systemImage: "arrow.down.doc").font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(mint.opacity(0.13), in: Capsule()).foregroundStyle(mint)
                    }
                }

                if library.filteredTracks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 5) {
                        ForEach(library.filteredTracks) { track in
                            TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id,
                                     isFavorite: library.isFavorite(track),
                                     favoriteAction: { library.toggleFavorite(track) }) {
                                player.play(track, from: library.filteredTracks) { library.fileURL(for: $0) }
                                showPlayer = true
                            }
                            .contextMenu {
                                Button(role: .destructive) { library.remove(track) } label: {
                                    Label("从 Una 移除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 22)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 108, height: 108)
                Image(systemName: "waveform").font(.system(size: 38, weight: .light)).foregroundStyle(mint)
            }
            Text("让音乐住进 Una").font(.system(size: 20, weight: .semibold)).foregroundStyle(ink)
            Text("导入设备中的音频文件，建立你的私人音乐空间。")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.48)).multilineTextAlignment(.center)
            Button { showImporter = true } label: {
                Text("选择本地音乐").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black).padding(.horizontal, 22).padding(.vertical, 13)
                    .background(mint, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 54)
    }

    private var playlistsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("已收藏").font(.system(size: 20, weight: .semibold)).foregroundStyle(ink)
                    Spacer()
                    Text("\(library.tracks.filter { library.isFavorite($0) }.count) 首")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                }
                let favorites = library.tracks.filter { library.isFavorite($0) }
                if favorites.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(mint)
                        Text("把喜欢的音乐收藏在这里").foregroundStyle(.white.opacity(0.55)).font(.system(size: 13))
                    }.frame(maxWidth: .infinity).padding(.vertical, 60)
                } else {
                    ForEach(favorites) { track in
                        TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id,
                                 isFavorite: true, favoriteAction: { library.toggleFavorite(track) }) {
                            player.play(track, from: favorites) { library.fileURL(for: $0) }
                            showPlayer = true
                        }
                    }
                }
            }.padding(.horizontal, 22).padding(.top, 8)
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsRow("音频文件", detail: "支持 MP3、M4A、WAV、AIFF", icon: "music.note")
            settingsRow("播放方式", detail: "后台播放与锁屏控制", icon: "airplayaudio")
            settingsRow("隐私", detail: "音乐文件保存在本机，不上传服务器", icon: "lock.shield")
            settingsRow("关于 Una", detail: "Una Music · 原生音乐播放器", icon: "waveform")
            Spacer()
        }.padding(22)
    }

    private func settingsRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(mint).frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(ink).font(.system(size: 15, weight: .medium))
                Text(detail).foregroundStyle(.white.opacity(0.45)).font(.system(size: 12))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
        }.padding(14).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var miniPlayer: some View {
        Button { showPlayer = true } label: {
            HStack(spacing: 12) {
                ArtworkView(seed: player.currentTrack?.title ?? "Una", size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.currentTrack?.title ?? "").font(.system(size: 14, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                    Text(player.currentTrack?.displayArtist ?? "").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer()
                Button { player.previous() } label: { Image(systemName: "backward.end.fill").foregroundStyle(ink) }
                Button { player.togglePlayback() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 18)).foregroundStyle(ink).frame(width: 38)
                }
                Button { player.next() } label: { Image(systemName: "forward.end.fill").foregroundStyle(ink) }
            }
            .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack {
            tab("music.note.list", title: "音乐", index: 0)
            tab("square.stack", title: "歌单", index: 1)
            tab("slider.horizontal.3", title: "设置", index: 2)
        }
        .padding(.top, 12).padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5) }
    }

    private func tab(_ icon: String, title: String, index: Int) -> some View {
        Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { selectedTab = index } } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == index ? mint : .white.opacity(0.38))
            .frame(maxWidth: .infinity)
        }
    }
}

struct TrackRow: View {
    let track: Track
    let isCurrent: Bool
    var isFavorite: Bool = false
    var favoriteAction: () -> Void = {}
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ArtworkView(seed: track.title, size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.94)).lineLimit(1)
                    Text(track.displayArtist).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
                Spacer()
                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color.mint : .white.opacity(0.35))
                }
                .buttonStyle(.plain)
                if isCurrent {
                    Image(systemName: "waveform").foregroundStyle(Color.mint)
                }
            }.padding(.vertical, 7)
        }.buttonStyle(.plain)
    }
}

struct ArtworkView: View {
    let seed: String
    let size: CGFloat
    var body: some View {
        let hue = Double(abs(seed.hashValue % 255)) / 255.0
        ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.75), Color(hue: (hue + 0.22).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.22)).frame(width: size * 0.52).blur(radius: 8).offset(x: size * 0.18, y: -size * 0.15)
            Image(systemName: "waveform").font(.system(size: size * 0.30, weight: .light)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

struct NowPlayingView: View {
    @EnvironmentObject private var player: AudioPlayer
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.055, blue: 0.065).ignoresSafeArea()
            Circle().fill(Color.teal.opacity(0.25)).frame(width: 340).blur(radius: 110).offset(y: -220)
            VStack(spacing: 28) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").foregroundStyle(.white.opacity(0.7)).font(.title3) }
                    Spacer()
                    Text("NOW PLAYING").font(.system(size: 10, weight: .bold)).tracking(3).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 5)
                ArtworkView(seed: player.currentTrack?.title ?? "Una", size: 300)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.45), radius: 35, y: 20)
                VStack(spacing: 7) {
                    Text(player.currentTrack?.title ?? "未选择歌曲").font(.system(size: 25, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    HStack(spacing: 12) {
                        Text(player.currentTrack?.displayArtist ?? "Una").font(.system(size: 14)).foregroundStyle(.white.opacity(0.48))
                        if let track = player.currentTrack {
                            Button { library.toggleFavorite(track) } label: {
                                Image(systemName: library.isFavorite(track) ? "heart.fill" : "heart")
                                    .foregroundStyle(library.isFavorite(track) ? .mint : .white.opacity(0.5))
                            }
                        }
                    }
                }
                VStack(spacing: 8) {
                    Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }), in: 0...max(player.duration, 1))
                        .tint(Color.mint)
                    HStack {
                        Text(timeString(player.currentTime))
                        Spacer()
                        Text(timeString(player.duration))
                    }.font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.42))
                }
                HStack(spacing: 30) {
                    Button { player.toggleShuffle() } label: { Image(systemName: "shuffle").font(.title3).foregroundStyle(player.isShuffled ? .mint : .white.opacity(0.55)) }
                    Button { player.previous() } label: { Image(systemName: "backward.end.fill").font(.title2).foregroundStyle(.white) }
                    Button { player.togglePlayback() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold)).foregroundStyle(Color.black)
                            .frame(width: 70, height: 70).background(Color.mint, in: Circle())
                    }
                    Button { player.next() } label: { Image(systemName: "forward.end.fill").font(.title2).foregroundStyle(.white) }
                    Button { player.cycleRepeat() } label: { Image(systemName: player.repeatMode.symbol).font(.title3).foregroundStyle(player.repeatMode == .off ? .white.opacity(0.55) : .mint) }
                }
                Spacer(minLength: 12)
            }.padding(.horizontal, 26).padding(.top, 18).padding(.bottom, 20)
        }
        .onAppear { player.setFileResolver { library.fileURL(for: $0) } }
    }

    private func timeString(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(time) / 60, Int(time) % 60)
    }
}
