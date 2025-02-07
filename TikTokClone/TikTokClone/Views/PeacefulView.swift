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
    
    private let availableEmojis = ["❤️", "😊", "✨", "🙏", "🌟", "🕊️"]
    private let youtubeVideoId = "wKg71lcs5Nw"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // YouTube Player
                YouTubePlayerView(videoID: youtubeVideoId)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
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
        .onChange(of: appwriteManager.recentReactions) { reactions in
            // Add new reactions as floating emojis
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
        
        // Animate the emoji floating up
        withAnimation(.easeOut(duration: 1.0)) {
            if let index = floatingEmojis.firstIndex(where: { $0.id == newEmoji.id }) {
                floatingEmojis[index].offset = 400
            }
        }
        
        // Remove the emoji after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            floatingEmojis.removeAll { $0.id == newEmoji.id }
        }
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.load(withVideoId: videoID, playerVars: [
            "playsinline": 1,
            "controls": 0,
            "showinfo": 0,
            "rel": 0,
            "modestbranding": 1
        ])
        return playerView
    }
    
    func updateUIView(_ uiView: YTPlayerView, context: Context) {}
} 