import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

@MainActor
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var queue: [Track] = []
    @Published var repeatMode: PlayerRepeatMode = .off
    @Published var isShuffled = false

    private var audioPlayer: AVAudioPlayer?
    private var timer: AnyCancellable?
    private var originalQueue: [Track] = []
    private var remoteCommandsConfigured = false
    private var currentFileResolver: (Track) -> URL = { _ in URL(fileURLWithPath: "/") }

    override init() {
        super.init()
        configureRemoteCommands()
    }

    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.audioPlayer?.play()
                self.isPlaying = self.audioPlayer?.isPlaying ?? false
                self.updateNowPlaying()
            }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    func setFileResolver(_ resolver: @escaping (Track) -> URL) {
        currentFileResolver = resolver
    }

    func play(_ track: Track, from tracks: [Track], fileURL: @escaping (Track) -> URL) {
        currentFileResolver = fileURL
        originalQueue = tracks
        queue = tracks
        guard let index = queue.firstIndex(of: track) else { return }
        playAt(index)
    }

    private func playAt(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        let track = queue[index]
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: currentFileResolver(track))
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { throw NSError(domain: "Una.AudioPlayer", code: 1) }
            audioPlayer = player
            currentTrack = track
            duration = player.duration
            currentTime = 0
            isPlaying = true
            startTimer()
            updateNowPlaying()
        } catch {
            isPlaying = false
        }
    }

    func togglePlayback() {
        guard let audioPlayer else { return }
        if audioPlayer.isPlaying { audioPlayer.pause(); isPlaying = false }
        else { isPlaying = audioPlayer.play() }
        updateNowPlaying()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func seek(to value: TimeInterval) {
        let boundedValue = min(max(value, 0), max(duration, 0))
        audioPlayer?.currentTime = boundedValue
        currentTime = boundedValue
        updateNowPlaying()
    }

    func next() {
        guard let currentTrack, let index = queue.firstIndex(of: currentTrack), !queue.isEmpty else { return }
        let nextIndex = index + 1
        if nextIndex < queue.count {
            playAt(nextIndex)
        } else if repeatMode == .all {
            playAt(0)
        } else {
            pause()
        }
    }

    func previous() {
        guard let currentTrack, let index = queue.firstIndex(of: currentTrack) else { return }
        if currentTime > 3 { seek(to: 0) }
        else { playAt(max(0, index - 1)) }
    }

    func toggleShuffle() {
        isShuffled.toggle()
        guard let currentTrack else { return }
        if isShuffled {
            queue = [currentTrack] + queue.filter { $0.id != currentTrack.id }.shuffled()
        } else {
            queue = originalQueue
        }
    }

    func cycleRepeat() { repeatMode = repeatMode.next }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.duration = player.duration
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.repeatMode == .one, let track = self.currentTrack {
                self.playAt(self.queue.firstIndex(of: track) ?? 0)
            } else {
                self.next()
            }
        }
    }
}
