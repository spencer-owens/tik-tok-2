import SwiftUI
import AVKit
import AVFoundation

struct FloatingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGFloat
    var offset: CGFloat
}

// Player observer class to handle KVO
class PlayerObserver: NSObject {
    private var playerItemContext = 0
    private let onReadyToPlay: () -> Void
    private let onError: (Error?) -> Void
    
    init(onReadyToPlay: @escaping () -> Void, onError: @escaping (Error?) -> Void) {
        self.onReadyToPlay = onReadyToPlay
        self.onError = onError
        super.init()
    }
    
    func observe(_ playerItem: AVPlayerItem) {
        playerItem.addObserver(
            self,
            forKeyPath: #keyPath(AVPlayerItem.status),
            options: [.old, .new],
            context: &playerItemContext
        )
    }
    
    func stopObserving(_ playerItem: AVPlayerItem) {
        playerItem.removeObserver(
            self,
            forKeyPath: #keyPath(AVPlayerItem.status),
            context: &playerItemContext
        )
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue) ?? .unknown
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                print("✅ Video ready to play")
                onReadyToPlay()
            case .failed:
                print("❌ Video failed to load")
                if let playerItem = object as? AVPlayerItem {
                    onError(playerItem.error)
                }
            case .unknown:
                print("⚠️ Video status unknown")
            @unknown default:
                print("⚠️ Video status unknown (new case)")
            }
        }
    }
}

// Add this before the PeacefulView struct
class DualPlayerManager: ObservableObject {
    @Published var isReady = false
    private var playerA: AVPlayer
    private var playerB: AVPlayer
    private var currentPlayer: AVPlayer
    private var nextPlayer: AVPlayer
    private var timeObserverToken: Any?
    private var asset: AVURLAsset?
    private var isObserving = false
    private var switchPoint: Double = 0.3
    private var hasStartedPlaying = false
    private var isCurrentlySwitching = false
    private var playerObserverA: PlayerObserver?
    private var playerObserverB: PlayerObserver?
    
    init(url: URL) {
        print("🎬 Initializing DualPlayerManager with URL:", url)
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured")
        } catch {
            print("❌ Failed to configure audio session:", error)
        }
        
        // Initialize both players with the same asset
        self.playerA = AVPlayer()
        self.playerB = AVPlayer()
        self.currentPlayer = playerA
        self.nextPlayer = playerB
        
        // Configure initial state
        setupPlayers(with: url)
    }
    
    private func setupPlayers(with url: URL) {
        print("🎬 Setting up players")
        
        // Create asset with specific options for better loading
        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let asset = AVURLAsset(url: url, options: options)
        self.asset = asset
        
        // Configure playerA
        let itemA = AVPlayerItem(asset: asset)
        itemA.preferredForwardBufferDuration = 5.0
        itemA.audioTimePitchAlgorithm = .spectral  // Better audio quality during rate changes
        playerA.replaceCurrentItem(with: itemA)
        
        // Configure playerB
        let itemB = AVPlayerItem(asset: asset)
        itemB.preferredForwardBufferDuration = 5.0
        itemB.audioTimePitchAlgorithm = .spectral
        playerB.replaceCurrentItem(with: itemB)
        
        // Configure player settings
        [playerA, playerB].forEach { player in
            player.automaticallyWaitsToMinimizeStalling = false
            player.preventsDisplaySleepDuringVideoPlayback = true
            player.allowsExternalPlayback = false
            player.volume = 1.0
            
            // Add audio mix to ensure audio works
            if let playerItem = player.currentItem {
                let audioMix = AVMutableAudioMix()
                let audioParams = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first!)
                audioParams.setVolume(1.0, at: .zero)
                audioMix.inputParameters = [audioParams]
                playerItem.audioMix = audioMix
            }
        }
        
        // Setup observers for both players
        setupPlayerObservers()
        
        // Start observing for smooth transitions
        startObserving()
    }
    
    private func setupPlayerObservers() {
        playerObserverA = PlayerObserver(
            onReadyToPlay: { [weak self] in
                print("✅ Player A ready to play")
                self?.checkIfBothPlayersReady()
            },
            onError: { error in
                if let error = error {
                    print("❌ Player A error:", error)
                }
            }
        )
        
        playerObserverB = PlayerObserver(
            onReadyToPlay: { [weak self] in
                print("✅ Player B ready to play")
                self?.checkIfBothPlayersReady()
            },
            onError: { error in
                if let error = error {
                    print("❌ Player B error:", error)
                }
            }
        )
        
        playerObserverA?.observe(playerA.currentItem!)
        playerObserverB?.observe(playerB.currentItem!)
    }
    
    private func checkIfBothPlayersReady() {
        guard let itemA = playerA.currentItem,
              let itemB = playerB.currentItem,
              itemA.status == .readyToPlay,
              itemB.status == .readyToPlay else {
            return
        }
        
        Task { @MainActor in
            self.isReady = true
        }
    }
    
    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        // Add time observer to handle player switching
        let interval = CMTime(seconds: 0.03, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = currentPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.currentPlayer.currentItem?.duration,
                  !duration.seconds.isNaN,
                  duration.seconds > 0 else { return }
            
            let currentTime = time.seconds
            let totalDuration = duration.seconds
            
            // Print playback progress for debugging
            if Int(currentTime * 100) % 100 == 0 {
                print("🎬 Playback progress: \(String(format: "%.2f", currentTime))/\(String(format: "%.2f", totalDuration)) seconds")
            }
            
            let timeRemaining = duration.seconds - currentTime
            if timeRemaining <= self.switchPoint && !self.isCurrentlySwitching {
                print("⚡️ Time to switch! Current time: \(currentTime), Duration: \(totalDuration)")
                self.preparePlayerSwitch()
            }
        }
    }
    
    private func preparePlayerSwitch() {
        guard !isCurrentlySwitching else { return }
        isCurrentlySwitching = true
        
        print("🔄 Preparing player switch")
        
        // Reset and prepare next player
        nextPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished else { return }
            
            print("🎯 Next player seeked to start")
            self.nextPlayer.volume = 0
            self.nextPlayer.play()
            
            // Fade audio between players
            self.crossFadeToNextPlayer()
        }
    }
    
    private func crossFadeToNextPlayer() {
        print("🎚️ Starting audio crossfade")
        
        let fadeSteps = 10
        let fadeInterval = switchPoint / Double(fadeSteps)
        
        for step in 0...fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(step) * fadeInterval)) { [weak self] in
                guard let self = self else { return }
                let progress = Double(step) / Double(fadeSteps)
                self.currentPlayer.volume = Float(1 - progress)
                self.nextPlayer.volume = Float(progress)
            }
        }
        
        // Complete the switch after the fade
        DispatchQueue.main.asyncAfter(deadline: .now() + switchPoint) { [weak self] in
            guard let self = self else { return }
            
            // Swap players
            let temp = self.currentPlayer
            self.currentPlayer = self.nextPlayer
            self.nextPlayer = temp
            
            // Reset the previous player
            temp.pause()
            temp.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            temp.volume = 0
            
            self.isCurrentlySwitching = false
            print("✅ Player switch complete")
        }
    }
    
    func play() {
        print("▶️ DualPlayerManager play() called")
        guard !hasStartedPlaying else {
            print("⚠️ Already playing, ignoring play() call")
            return
        }
        
        hasStartedPlaying = true
        
        // Configure audio session again just in case
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to activate audio session:", error)
        }
        
        currentPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished else { return }
            print("🎯 Initial seek completed, starting playback")
            self.currentPlayer.volume = 1.0
            self.currentPlayer.play()
        }
    }
    
    func pause() {
        print("⏸️ DualPlayerManager pause() called")
        hasStartedPlaying = false
        playerA.pause()
        playerB.pause()
    }
    
    func cleanup() {
        pause()
        if let token = timeObserverToken {
            currentPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Clean up observers
        if let itemA = playerA.currentItem {
            playerObserverA?.stopObserving(itemA)
        }
        if let itemB = playerB.currentItem {
            playerObserverB?.stopObserving(itemB)
        }
        
        playerObserverA = nil
        playerObserverB = nil
        isObserving = false
        isCurrentlySwitching = false
    }
    
    var currentAVPlayer: AVPlayer {
        currentPlayer
    }
}

struct PeacefulView: View {
    @StateObject private var appwriteManager = AppwriteManager.shared
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var floatingEmojis: [FloatingEmoji] = []
    @State private var isVideoReady = false
    @StateObject private var playerManager: DualPlayerManager
    @State private var isLive = true
    
    private let availableEmojis = ["❤️", "😊", "✨", "🙏", "🌟", "🕊️"]
    
    // Use our uploaded asset's playback URL
    private let muxPlaybackUrl = "https://stream.mux.com/C9hZ64MVnbYvOPwdvcsUzTEoL2V016e4T452syub4r18.m3u8"
    
    init() {
        let url = URL(string: "https://stream.mux.com/C9hZ64MVnbYvOPwdvcsUzTEoL2V016e4T452syub4r18.m3u8")!
        _playerManager = StateObject(wrappedValue: DualPlayerManager(url: url))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color while video loads
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Mux Video Player
                CustomVideoPlayer(player: playerManager.currentAVPlayer)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(playerManager.isReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: playerManager.isReady)
                    .onAppear {
                        print("📺 Video player appeared")
                        if playerManager.isReady {
                            print("▶️ Starting playback because player is ready")
                            playerManager.play()
                        }
                    }
                    .onChange(of: playerManager.isReady) { _, isReady in
                        if isReady {
                            print("▶️ Starting playback because player became ready")
                            playerManager.play()
                        }
                    }
                    .onDisappear {
                        print("👋 Video player disappeared")
                        playerManager.cleanup()
                    }
                
                // Live Indicator
                VStack {
                    HStack {
                        if isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(16)
                            .padding(.top, 50)
                            .padding(.leading)
                        }
                        
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
            Task {
                await appwriteManager.startListeningToReactions()
            }
        }
        .onDisappear {
            print("👋 PeacefulView disappeared")
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

// Custom video player view to disable controls
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
}

// Preview provider remains the same
#Preview {
    PeacefulView()
} 