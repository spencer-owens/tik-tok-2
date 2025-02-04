import SwiftUI
import AVKit
import MuxPlayerSwift

struct FeedView: View {
    @EnvironmentObject private var appwriteManager: AppwriteManager
    
    // Sample playback IDs - replace with real ones from your Mux dashboard
    private let samplePlaybackIDs = [
        "qxb01i6T202018GFS02vp9RIe01icTcDCjVzQpmaB00CUisJ4",
        "DS00Spx02xq02C02G9cmgxnM8WtE4C4Z4X1FmyqqOH6cpE", 
        "E4JqGtkmkZa1K02pnj00CxXHH02C02xLt5PqyYvJWH02nY"
    ]
    
    @State private var currentIndex = 0
    @State private var players: [String: AVPlayer] = [:]
    @State private var playerViewControllers: [String: AVPlayerViewController] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(Array(samplePlaybackIDs.enumerated()), id: \.element) { index, playbackID in
                    ZStack {
                        if let player = players[playbackID] {
                            AVPlayerControllerRepresented(
                                player: player,
                                playerViewController: playerViewControllers[playbackID] ?? AVPlayerViewController()
                            )
                            .ignoresSafeArea()
                            .onAppear {
                                player.seek(to: .zero)
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                        }
                        
                        // Overlay buttons on the right
                        VStack {
                            Spacer()
                            VStack(spacing: 20) {
                                Button(action: {}) {
                                    VStack {
                                        Image(systemName: "heart")
                                            .font(.system(size: 28))
                                        Text("150K")
                                            .font(.caption)
                                    }
                                }
                                
                                Button(action: {}) {
                                    VStack {
                                        Image(systemName: "message")
                                            .font(.system(size: 28))
                                        Text("1.2K")
                                            .font(.caption)
                                    }
                                }
                                
                                Button(action: {}) {
                                    VStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 28))
                                        Text("Share")
                                            .font(.caption)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.trailing, 20)
                            .padding(.bottom, 50)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onAppear {
                setupPlayers()
            }
            
            // Logout button overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await appwriteManager.logout()
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
    }
    
    private func setupPlayers() {
        for playbackID in samplePlaybackIDs {
            let playerViewController = AVPlayerViewController(playbackID: playbackID)
            playerViewControllers[playbackID] = playerViewController
            players[playbackID] = playerViewController.player
        }
    }
}

// SwiftUI wrapper for AVPlayerViewController
struct AVPlayerControllerRepresented: UIViewControllerRepresentable {
    let player: AVPlayer
    let playerViewController: AVPlayerViewController
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

#Preview {
    FeedView()
        .environmentObject(AppwriteManager.shared)
} 