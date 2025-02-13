import SwiftUI
import AVKit
import AVFoundation

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var currentActivityType: MediaAsset.ActivityCategory = .meditation
    @Published var statusMessage: String = "Loading..."
    @Published var isLoading: Bool = false
    
    var videoPlayer: AVPlayer?
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private let appwriteManager = AppwriteManager.shared
    
    func getCurrentActivity() -> MediaAsset.ActivityCategory {
        let calendar = Calendar.current
        let currentDate = ScheduleView.getCurrentTime()
        let scheduleItems = ScheduleView.createSchedule()
        
        print("🕒 Current time: \(timeFormatter.string(from: currentDate))")
        
        for (index, item) in scheduleItems.enumerated() {
            let itemTime = calendar.dateComponents([.hour, .minute], from: item.time)
            let currentTime = calendar.dateComponents([.hour, .minute], from: currentDate)
            
            print("📅 Checking slot: \(timeFormatter.string(from: item.time)) - \(item.activity)")
            
            if index < scheduleItems.count - 1 {
                let nextItem = scheduleItems[index + 1]
                let nextTime = calendar.dateComponents([.hour, .minute], from: nextItem.time)
                
                if isTime(currentTime, betweenOrEqual: itemTime, and: nextTime) {
                    print("✅ Found matching time slot: \(item.activity)")
                    return activityTypeFor(scheduleItem: item)
                }
            } else if isTime(currentTime, afterOrEqual: itemTime) {
                print("✅ In final time slot of the day: \(item.activity)")
                return activityTypeFor(scheduleItem: item)
            }
        }
        
        print("⚠️ No matching time slot found, defaulting to meditation")
        return .meditation
    }
    
    private func activityTypeFor(scheduleItem: ScheduleItem) -> MediaAsset.ActivityCategory {
        switch scheduleItem.type {
        case .meditation:
            print("🧘‍♂️ Activity: Guided Meditation")
            return .meditation
        case .walking:
            print("🚶‍♂️ Activity: Walking Meditation")
            return .walking
        case .meal:
            print("🍽️ Activity: Mindful Meal")
            return .meal
        case .other:
            print("⭐️ Other activity, defaulting to meditation")
            return .meditation
        }
    }
    
    private func isTime(_ time: DateComponents, betweenOrEqual start: DateComponents, and end: DateComponents) -> Bool {
        let timeMinutes = time.hour! * 60 + time.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        return timeMinutes >= startMinutes && timeMinutes < endMinutes
    }
    
    private func isTime(_ time: DateComponents, afterOrEqual start: DateComponents) -> Bool {
        let timeMinutes = time.hour! * 60 + time.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        return timeMinutes >= startMinutes
    }
    
    func loadAndPlayMedia() async {
        isLoading = true
        statusMessage = "Loading media..."
        
        // Stop any existing playback
        await stopPlayback()
        
        // Configure audio session first
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set up audio session: \(error)")
            statusMessage = "Audio setup failed"
        }
        
        // Get current activity type
        currentActivityType = getCurrentActivity()
        print("🎯 Starting playback for: \(currentActivityType)")
        
        // Load media from Appwrite
        await appwriteManager.loadMediaForActivity(currentActivityType)
        
        // Setup and play video
        if let videoId = appwriteManager.currentVideoId,
           let videoUrl = appwriteManager.getMuxStreamUrl(for: videoId) {
            print("🎥 Playing video: \(videoId)")
            
            let playerItem = AVPlayerItem(url: videoUrl)
            videoPlayer = AVPlayer(playerItem: playerItem)
            
            // Configure audio based on activity type
            if currentActivityType == .meditation {
                print("🔊 Enabling video sound for meditation")
                videoPlayer?.isMuted = false
                // Set volume to full for meditation
                videoPlayer?.volume = 1.0
            } else {
                print("🔇 Muting video for non-meditation activity")
                videoPlayer?.isMuted = true
            }
            
            videoPlayer?.play()
            setupVideoLooping()
        }
        
        // Setup and play audio for non-meditation activities
        if currentActivityType != .meditation,
           let audioUrl = appwriteManager.currentAudioUrl {
            print("🔊 Setting up background audio")
            
            let playerItem = AVPlayerItem(url: audioUrl)
            audioPlayer = AVPlayer(playerItem: playerItem)
            
            // Set background audio volume
            audioPlayer?.volume = 1.0
            print("▶️ Starting background audio playback")
            audioPlayer?.play()
            
            // Setup audio looping
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                print("🔄 Looping background audio")
                Task { @MainActor in
                    await self?.audioPlayer?.seek(to: .zero)
                    self?.audioPlayer?.play()
                }
            }
        }
        
        isLoading = false
        statusMessage = "Playing \(currentActivityType)"
    }
    
    private func setupVideoLooping() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = videoPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if let duration = self.videoPlayer?.currentItem?.duration,
               let currentTime = self.videoPlayer?.currentTime(),
               duration.seconds > 0,
               currentTime.seconds >= duration.seconds - 0.5 {
                Task { @MainActor in
                    await self.videoPlayer?.seek(to: .zero)
                    self.videoPlayer?.play()
                }
            }
        }
    }
    
    func stopPlayback() async {
        // Stop and clean up video
        if let timeObserver = timeObserver {
            videoPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        videoPlayer?.pause()
        videoPlayer = nil
        
        // Stop and clean up audio
        audioPlayer?.pause()
        audioPlayer = nil
        
        // Remove all notifications
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        Task { @MainActor in
            await stopPlayback()
        }
    }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

/// An observer for the AVPlayer that updates a status message.
final class PlayerStatusObserver: ObservableObject {
    @Published var statusMessage: String = "Waiting..."
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var errorObserver: NSKeyValueObservation?
    private weak var observedPlayer: AVPlayer?
    
    /// Attaches the observer to the given player and item.
    func attach(player: AVPlayer, playerItem: AVPlayerItem) {
        // Store the player reference for cleaning up later.
        observedPlayer = player
        
        // Remove any old observers.
        statusObserver?.invalidate()
        errorObserver?.invalidate()
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Observe the player item's status.
        statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .unknown:
                    self.statusMessage = "Status: Unknown"
                case .readyToPlay:
                    self.statusMessage = "Status: Ready to Play"
                case .failed:
                    let errorMessage = item.error?.localizedDescription ?? "unknown error"
                    self.statusMessage = "Error: \(errorMessage)"
                    print("Playback failed with error: \(errorMessage)")
                @unknown default:
                    self.statusMessage = "Status: Unhandled case"
                }
                print(self.statusMessage)
            }
        }
        
        // Observe player errors.
        errorObserver = player.observe(\.error, options: [.new]) { player, _ in
            if let error = player.error {
                DispatchQueue.main.async {
                    print("Player error: \(error.localizedDescription)")
                    self.statusMessage = "Player error: \(error.localizedDescription)"
                }
            }
        }
        
        // Add periodic time observer for playback time.
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            print("Playback time: \(seconds)")
            if seconds > 0 { self?.statusMessage = "Playing: \(Int(seconds))s" }
        }
    }
    
    deinit {
        if let timeObserver = timeObserver, let player = observedPlayer {
            player.removeTimeObserver(timeObserver)
        }
        statusObserver?.invalidate()
        errorObserver?.invalidate()
    }
}

/// A simple ObservableObject wrapper (if needed for additional status messages).
final class ObservableObjectWrapper: ObservableObject {
    @Published var statusMessage: String
    init(statusMessage: String) { self.statusMessage = statusMessage }
}

// Add LoadingView before ActivityView
struct LoadingView: View {
    let activity: String
    @State private var dotCount = 0
    
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Now entering")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            
            Text(activity)
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text(String(repeating: ".", count: dotCount + 1))
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .onReceive(timer) { _ in
                    dotCount = (dotCount + 1) % 3
                }
        }
        .padding(24)
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
    }
}

struct ActivityView: View {
    @Binding var isActive: Bool
    @StateObject private var viewModel = ActivityViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        ZStack {
            if let player = viewModel.videoPlayer {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
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
            
            // Status overlay
            VStack {
                Spacer()
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding()
            }
            
            // Loading overlay with activity name
            if viewModel.isLoading {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                LoadingView(activity: viewModel.currentActivityType.displayName)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.isLoading)
        .task {
            if isActive {
                await viewModel.loadAndPlayMedia()
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                Task {
                    await viewModel.loadAndPlayMedia()
                }
            } else {
                Task {
                    await viewModel.stopPlayback()
                }
            }
        }
    }
}

// Add extension for activity display names
extension MediaAsset.ActivityCategory {
    var displayName: String {
        switch self {
        case .meditation:
            return "Guided Meditation"
        case .walking:
            return "Walking Meditation"
        case .meal:
            return "Mindful Meal"
        }
    }
}

extension ScheduleView {
    static func createSchedule() -> [ScheduleItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let scheduleData: [(time: String, activity: String, type: ScheduleItem.ActivityType)] = [
            ("06:00", "Wake up", .other),
            ("06:30", "Guided meditation", .meditation),
            ("07:15", "Breakfast", .meal),
            ("08:00", "Walking meditation", .walking),
            ("08:30", "Guided meditation", .meditation),
            ("09:30", "Walking meditation", .walking),
            ("10:00", "Guided meditation", .meditation),
            ("11:00", "Walking meditation", .walking),
            ("11:30", "Lunch", .meal),
            ("13:00", "Guided meditation", .meditation),
            ("14:00", "Walking meditation", .walking),
            ("14:30", "Guided meditation", .meditation),
            ("15:30", "Walking meditation", .walking),
            ("16:00", "Guided meditation", .meditation),
            ("17:00", "Light dinner", .meal),
            ("18:00", "Final meditation", .meditation),
            ("19:00", "Rest", .other)
        ]
        
        return scheduleData.compactMap { data in
            if let date = formatter.date(from: data.time) {
                let fullDate = calendar.date(
                    bySettingHour: calendar.component(.hour, from: date),
                    minute: calendar.component(.minute, from: date),
                    second: 0,
                    of: today
                )
                return fullDate.map { ScheduleItem(time: $0, activity: data.activity, type: data.type) }
            }
            return nil
        }
    }
}

#Preview {
    ActivityView(isActive: .constant(false))
} 