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
        let currentDate = ScheduleView.getCurrentTime()  // Use the override-aware time
        let scheduleItems = ScheduleView.createSchedule()
        
        for (index, item) in scheduleItems.enumerated() {
            let itemTime = calendar.dateComponents([.hour, .minute], from: item.time)
            let currentTime = calendar.dateComponents([.hour, .minute], from: currentDate)
            
            if index < scheduleItems.count - 1 {
                let nextItem = scheduleItems[index + 1]
                let nextTime = calendar.dateComponents([.hour, .minute], from: nextItem.time)
                
                if isTime(currentTime, betweenOrEqual: itemTime, and: nextTime) {
                    switch item.type {
                    case .meditation:
                        return .meditation
                    case .walking:
                        return .walking
                    case .meal:
                        return .meal
                    case .other:
                        return .meditation
                    }
                }
            }
        }
        return .meditation
    }
    
    private func isTime(_ time: DateComponents, betweenOrEqual start: DateComponents, and end: DateComponents) -> Bool {
        let timeMinutes = time.hour! * 60 + time.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        
        return timeMinutes >= startMinutes && timeMinutes < endMinutes
    }
    
    func loadAndPlayMedia() async {
        isLoading = true
        statusMessage = "Loading media..."
        
        // Setup audio session first
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            statusMessage = "Audio setup failed"
        }
        
        await stopPlayback()
        currentActivityType = getCurrentActivity()
        print("Current activity type: \(currentActivityType)")
        
        // Load new media
        await appwriteManager.loadMediaForActivity(currentActivityType)
        
        // Setup video first
        if let videoId = appwriteManager.currentVideoId,
           let videoUrl = appwriteManager.getMuxStreamUrl(for: videoId) {
            print("Setting up video with ID: \(videoId)")
            
            let playerItem = AVPlayerItem(url: videoUrl)
            videoPlayer = AVPlayer(playerItem: playerItem)
            
            // For meditation videos, we want their original audio
            videoPlayer?.isMuted = (currentActivityType != .meditation)
            
            // Add time observer for video looping
            let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = videoPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                if let duration = self.videoPlayer?.currentItem?.duration,
                   let currentTime = self.videoPlayer?.currentTime(),
                   duration.seconds > 0,
                   currentTime.seconds >= duration.seconds - 0.5 {
                    self.videoPlayer?.seek(to: .zero)
                    self.videoPlayer?.play()
                }
            }
            
            // Start video playback
            videoPlayer?.play()
            
            // For walking and meal times, add our custom audio
            if currentActivityType != .meditation {
                await setupCustomAudio()
            }
        }
        
        isLoading = false
        statusMessage = "Playing \(currentActivityType)"
    }
    
    private func setupCustomAudio() async {
        guard let audioUrl = appwriteManager.currentAudioUrl else {
            print("No audio URL available")
            return
        }
        
        print("Attempting to play audio from: \(audioUrl)")
        
        do {
            // Create a URL request to include any necessary headers
            var request = URLRequest(url: audioUrl)
            // Add any session cookies that might be present
            if let cookies = HTTPCookieStorage.shared.cookies {
                let headers = HTTPCookie.requestHeaderFields(with: cookies)
                for (header, value) in headers {
                    request.addValue(value, forHTTPHeaderField: header)
                }
            }
            
            // Try to access the audio using the request
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "AudioError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 401 {
                print("Authentication required for audio")
                statusMessage = "Authentication required for audio"
                return
            }
            
            print("Successfully loaded audio data: \(data.count) bytes")
            
            let audioItem = AVPlayerItem(url: audioUrl)
            audioPlayer = AVPlayer(playerItem: audioItem)
            
            // Setup audio looping
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: audioItem,
                queue: .main
            ) { [weak self] _ in
                self?.audioPlayer?.seek(to: .zero)
                self?.audioPlayer?.play()
            }
            
            // Start audio playback
            audioPlayer?.play()
            print("Started audio playback")
            
        } catch {
            print("Failed to setup audio: \(error)")
            statusMessage = "Audio setup failed: \(error.localizedDescription)"
        }
    }
    
    // Changed to internal access and kept async for actor isolation
    func stopPlayback() async {
        if let timeObserver = timeObserver {
            videoPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        videoPlayer?.pause()
        videoPlayer = nil
        audioPlayer?.pause()
        audioPlayer = nil
    }
    
    deinit {
        // Since we can't use async/await in deinit, we'll use Task
        Task { @MainActor in
            await stopPlayback()
        }
    }
}

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

struct ActivityView: View {
    @Binding var isActive: Bool
    @StateObject private var viewModel = ActivityViewModel()
    
    var body: some View {
        ZStack {
            if let player = viewModel.videoPlayer {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
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
            
            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
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