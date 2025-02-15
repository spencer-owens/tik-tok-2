import SwiftUI
import AVKit

struct FloatingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGFloat
    var offset: CGFloat
}

class VideoPlayerViewModel: NSObject, ObservableObject {
    @Published var isVideoReady = false
    @Published var player: AVPlayer?
    @Published var isGeneratingNewVideo = false
    @Published var currentPlaybackId = ""
    
    private let fallbackPlaybackIds = [
        "o4qB9oZ01zEe4013lWEwupTVLedZs7xHVdKCheSSuf8Vc",
        "Tsb5gt8sNKFbIfGLcSaugeKnJab801G1Ny7RxHR6BakE"
    ]
    private var fallbackTimer: Timer?
    private var currentFallbackIndex = 0
    
    override init() {
        super.init()
    }
    
    func startFallbackVideoRotation() {
        currentPlaybackId = fallbackPlaybackIds[currentFallbackIndex]
        setupVideo(playbackId: currentPlaybackId)
        
        // Rotate between fallback videos every 30 seconds
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentFallbackIndex = (self.currentFallbackIndex + 1) % self.fallbackPlaybackIds.count
            self.currentPlaybackId = self.fallbackPlaybackIds[self.currentFallbackIndex]
            self.setupVideo(playbackId: self.currentPlaybackId)
        }
    }
    
    func stopFallbackVideoRotation() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    func setupVideo(playbackId: String) {
        print("🎬 Setting up video player with playback ID: \(playbackId)")
        cleanup() // Clean up existing player
        
        // Configure audio session for background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set audio session category: \(error)")
        }
        
        // Create URL for Mux stream
        let urlString = "https://stream.mux.com/\(playbackId).m3u8"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return
        }
        
        // Create player and item
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // Configure looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            player.seek(to: .zero)
            player.play()
        }
        
        // Observe when the item is ready to play
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        
        self.player = player
        player.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status",
           let playerItem = object as? AVPlayerItem {
            DispatchQueue.main.async {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ Video ready to play")
                    self.isVideoReady = true
                case .failed:
                    print("❌ Video failed to load: \(String(describing: playerItem.error))")
                case .unknown:
                    print("⚠️ Video status unknown")
                @unknown default:
                    break
                }
            }
        }
    }
    
    func cleanup() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        cleanup()
        stopFallbackVideoRotation()
    }
}

struct PeacefulView: View {
    @StateObject private var appwriteManager = AppwriteManager.shared
    @StateObject private var viewModel = VideoPlayerViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var floatingEmojis: [FloatingEmoji] = []
    @State private var vibeInput = ""
    @State private var isShowingInput = true
    
    private let availableEmojis = ["❤️", "😊", "✨", "🙏", "🌟", "🕊️"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color while video loads
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Video Player
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                        .opacity(viewModel.isVideoReady ? 1 : 0)
                        .animation(.easeIn(duration: 0.3), value: viewModel.isVideoReady)
                }
                
                // Vibe Input Overlay
                if isShowingInput {
                    VStack(spacing: 20) {
                        Text("What kind of vibe are you looking for?")
                            .font(.title2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        TextField("Describe your desired vibe...", text: $vibeInput)
                            .textFieldStyle(RoundedBorderTextStyle())
                            .padding(.horizontal, 40)
                        
                        Button(action: generateContent) {
                            Text("Generate")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(vibeInput.isEmpty || viewModel.isGeneratingNewVideo)
                        
                        if viewModel.isGeneratingNewVideo {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
                
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
            print("🎭 PeacefulView appeared")
            viewModel.startFallbackVideoRotation()
            Task {
                await appwriteManager.startListeningToReactions()
            }
        }
        .onDisappear {
            print("👋 PeacefulView disappeared")
            viewModel.cleanup()
            viewModel.stopFallbackVideoRotation()
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
    
    private func generateContent() {
        guard !vibeInput.isEmpty else { return }
        
        viewModel.isGeneratingNewVideo = true
        
        // Start showing fallback videos while generating
        viewModel.startFallbackVideoRotation()
        
        // Prepare request parameters
        let heartRate = healthKitManager.currentBPM
        let intensity = calculateIntensity(heartRate: heartRate)
        
        Task {
            do {
                // Make API call to generate content
                let url = URL(string: "http://localhost:8000/api/v1/generate-peaceful-content")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let parameters: [String: Any] = [
                    "vibe": vibeInput,
                    "heart_rate": heartRate,
                    "intensity": intensity
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(GenerationResponse.self, from: data)
                
                if response.success, let playbackId = response.mux_playback_id {
                    // Stop fallback rotation and show new video
                    viewModel.stopFallbackVideoRotation()
                    viewModel.setupVideo(playbackId: playbackId)
                    isShowingInput = false
                }
                
                viewModel.isGeneratingNewVideo = false
            } catch {
                print("❌ Error generating content:", error)
                viewModel.isGeneratingNewVideo = false
            }
        }
    }
    
    private func calculateIntensity(heartRate: Int) -> Double {
        // Map heart rate to intensity (0.0 to 1.0)
        // Assuming normal range is 60-100 BPM
        let minRate: Double = 60
        let maxRate: Double = 100
        let rate = Double(heartRate)
        
        if rate <= minRate {
            return 0.0 // Most calm
        } else if rate >= maxRate {
            return 1.0 // Most intense
        }
        
        return (rate - minRate) / (maxRate - minRate)
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

struct GenerationResponse: Codable {
    let success: Bool
    let mux_playback_id: String?
    let mux_playback_url: String?
    let status: String
    let execution_time_seconds: Double
    let error: String?
} 