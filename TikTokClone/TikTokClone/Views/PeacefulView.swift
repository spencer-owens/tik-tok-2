import SwiftUI
import YouTubeiOSPlayerHelper

struct FloatingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGFloat
    var offset: CGFloat
}

struct PeacefulView: View {
    @StateObject private var appwriteManager = AppwriteManager.shared
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var floatingEmojis: [FloatingEmoji] = []
    @State private var isVideoReady = false
    
    private let availableEmojis = ["❤️", "😊", "✨", "🙏", "🌟", "🕊️"]
    private let youtubeVideoId = "wKg71lcs5Nw"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color while video loads
                Color.black.edgesIgnoringSafeArea(.all)
                
                // YouTube Player with clean interface
                YouTubePlayerView(videoID: youtubeVideoId, isReady: $isVideoReady)
                    .opacity(isVideoReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: isVideoReady)
                
                // Heart Rate Display in top-right corner
                VStack {
                    HStack {
                        Spacer()
                        HeartRateView()
                            .padding(.top, 50)
                            .padding(.trailing)
                    }
                    Spacer()
                }
                
                // Floating Emojis
                ForEach(floatingEmojis) { emoji in
                    Text(emoji.emoji)
                        .font(.system(size: 30))
                        .position(x: emoji.position, y: geometry.size.height - emoji.offset)
                }
                
                // Bottom Emoji Bar
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        ForEach(availableEmojis, id: \.self) { emoji in
                            Button(action: {
                                sendReaction(emoji)
                                addFloatingEmoji(emoji, width: geometry.size.width)
                            }) {
                                Text(emoji)
                                    .font(.system(size: 30))
                                    .padding(10)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .onAppear {
            print("🎬 PeacefulView appeared")
            Task {
                await appwriteManager.startListeningToReactions()
            }
        }
        .onDisappear {
            print("🔚 PeacefulView disappeared")
            Task {
                await appwriteManager.stopListeningToReactions()
            }
        }
        .onChange(of: appwriteManager.recentReactions) { oldValue, reactions in
            if let latestReaction = reactions.last {
                addFloatingEmoji(latestReaction.emoji, width: UIScreen.main.bounds.width)
            }
        }
    }
    
    private func sendReaction(_ emoji: String) {
        Task {
            await appwriteManager.sendReaction(emoji: emoji)
        }
    }
    
    private func addFloatingEmoji(_ emoji: String, width: CGFloat) {
        let position = CGFloat.random(in: 50...(width - 50))
        let newEmoji = FloatingEmoji(emoji: emoji, position: position, offset: 0)
        
        withAnimation {
            floatingEmojis.append(newEmoji)
        }
        
        withAnimation(.easeOut(duration: 1.0)) {
            if let index = floatingEmojis.firstIndex(where: { $0.id == newEmoji.id }) {
                floatingEmojis[index].offset = 400
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            floatingEmojis.removeAll { $0.id == newEmoji.id }
        }
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var isReady: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.delegate = context.coordinator
        
        // Load with autoplay and minimal interface
        playerView.load(withVideoId: videoID, playerVars: [
            "playsinline": 1,
            "controls": 0,
            "showinfo": 0,
            "modestbranding": 0,
            "rel": 0,
            "autoplay": 1,
            "iv_load_policy": 3,
            "fs": 0,
            "autohide": 1,
            "origin": "https://www.yourapp.com",
            "enablejsapi": 1,
            "disablekb": 1,
            "cc_load_policy": 0,
            "loop": 1,
            "color": "white",
            "branding": 0,
            "title": 0,
            "byline": 0,
            "portrait": 0
        ])
        
        // Additional styling to hide UI elements
        playerView.webView?.isOpaque = false
        playerView.webView?.backgroundColor = .clear
        playerView.backgroundColor = .clear
        
        return playerView
    }
    
    func updateUIView(_ uiView: YTPlayerView, context: Context) {}
    
    class Coordinator: NSObject, YTPlayerViewDelegate {
        var parent: YouTubePlayerView
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }
        
        func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
            // Start playing as soon as the player is ready
            playerView.playVideo()
            DispatchQueue.main.async {
                self.parent.isReady = true
            }
        }
        
        func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
            if state == .ended {
                // Replay when video ends
                playerView.seek(toSeconds: 0, allowSeekAhead: true)
                playerView.playVideo()
            }
        }
    }
} 