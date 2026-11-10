import Foundation
import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer
import AVFoundation

@MainActor
final class MusicLibrary: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var favoriteIDs: Set<UUID> = []
    @Published var searchText = ""
    @Published var showingImporter = false
    @Published var importError: String?

    private let folderName = "UnaMusic"
    private let metadataName = "library.json"
    private let favoritesName = "favorites.json"

    init() {
        createFolderIfNeeded()
        load()
    }

    var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText) ||
            $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var musicFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private var metadataURL: URL { musicFolder.appendingPathComponent(metadataName) }
    private var favoritesURL: URL { musicFolder.appendingPathComponent(favoritesName) }

    func fileURL(for track: Track) -> URL {
        musicFolder.appendingPathComponent(track.fileName)
    }

    private func createFolderIfNeeded() {
        try? FileManager.default.createDirectory(at: musicFolder, withIntermediateDirectories: true)
    }

    func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([Track].self, from: data) else { return }
        tracks = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
        if let data = try? Data(contentsOf: favoritesURL),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            favoriteIDs = Set(ids)
        }
    }

    func isFavorite(_ track: Track) -> Bool { favoriteIDs.contains(track.id) }

    func toggleFavorite(_ track: Track) {
        if favoriteIDs.contains(track.id) { favoriteIDs.remove(track.id) }
        else { favoriteIDs.insert(track.id) }
        if let data = try? JSONEncoder().encode(Array(favoriteIDs)) {
            try? data.write(to: favoritesURL, options: .atomic)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    func importFiles(_ urls: [URL]) {
        for source in urls {
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }

            do {
                let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension
                let destinationName = UUID().uuidString + "." + ext
                let destination = musicFolder.appendingPathComponent(destinationName)
                try FileManager.default.copyItem(at: source, to: destination)

                let title = source.deletingPathExtension().lastPathComponent
                let track = Track(title: title, artist: "本地文件", fileName: destinationName)
                tracks.insert(track, at: 0)
            } catch {
                importError = "导入失败：\(source.lastPathComponent)（\(error.localizedDescription)）"
            }
        }
        save()
    }

    func remove(_ track: Track) {
        try? FileManager.default.removeItem(at: fileURL(for: track))
        tracks.removeAll { $0.id == track.id }
        favoriteIDs.remove(track.id)
        if let data = try? JSONEncoder().encode(Array(favoriteIDs)) {
            try? data.write(to: favoritesURL, options: .atomic)
        }
        save()
    }

    func requestAppleMusicLibrary() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard status == .authorized else {
                    self?.importError = "未获得媒体资料库权限。你仍可通过“导入文件”添加音乐。"
                    return
                }
                let query = MPMediaQuery.songs()
                let items = query.items ?? []
                for item in items {
                    guard let url = item.assetURL else { continue }
                    let filename = UUID().uuidString + "." + url.pathExtension
                    guard let self else { continue }
                    let destination = self.musicFolder.appendingPathComponent(filename)
                    do {
                        try FileManager.default.copyItem(at: url, to: destination)
                        let track = Track(
                            title: item.title ?? url.deletingPathExtension().lastPathComponent,
                            artist: item.artist ?? "未知艺术家",
                            album: item.albumTitle ?? "",
                            fileName: filename,
                            duration: item.playbackDuration
                        )
                        if !self.tracks.contains(where: { $0.title == track.title && $0.artist == track.artist }) {
                            self.tracks.append(track)
                        }
                    } catch { continue }
                }
                self?.save()
            }
        }
    }
}
