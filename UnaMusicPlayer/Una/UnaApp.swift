import SwiftUI

@main
struct UnaApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
    }
}
