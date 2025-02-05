import SwiftUI
import AVKit
import AVFoundation

class ActivityViewModel: ObservableObject {
    @Published var currentActivityType: ScheduleItem.ActivityType = .meditation
    private var timer: Timer?
    private let schedule: [ScheduleItem]
    
    init() {
        // Initialize with the same schedule data as ScheduleView
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
        
        self.schedule = scheduleData.compactMap { data in
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
        
        updateCurrentActivity()
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateCurrentActivity()
        }
    }
    
    private func updateCurrentActivity() {
        let calendar = Calendar.current
        let currentDate = Date()
        
        for (index, item) in schedule.enumerated() {
            let itemTime = calendar.dateComponents([.hour, .minute], from: item.time)
            let currentTime = calendar.dateComponents([.hour, .minute], from: currentDate)
            
            if index < schedule.count - 1 {
                let nextItem = schedule[index + 1]
                let nextTime = calendar.dateComponents([.hour, .minute], from: nextItem.time)
                
                if isTime(currentTime, betweenOrEqual: itemTime, and: nextTime) {
                    currentActivityType = item.type
                    return
                }
            } else if isTime(currentTime, afterOrEqual: itemTime) {
                currentActivityType = item.type
                return
            }
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
    
    deinit {
        timer?.invalidate()
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
    // Indicates from parent when the Activity view is actively visible.
    @Binding var isActive: Bool
    @State private var player: AVPlayer?
    // Create the observer once. We later attach it to the specific player.
    @StateObject private var playerObserver = PlayerStatusObserver()
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player.seek(to: .zero)
                        if isActive {
                            print("ActivityView onAppear: Starting playback")
                            player.play()
                        }
                    }
                    .onDisappear {
                        print("ActivityView onDisappear: Pausing playback")
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                    }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }
            
            // Debug overlay showing the current status.
            VStack {
                Spacer()
                Text(playerObserver.statusMessage)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .onAppear {
            if player == nil {
                let playbackID = "QHVtYewW3ozRJvKhCcDfZvdiMd6GG7meZm001lkakOSg"
                guard let url = URL(string: "https://stream.mux.com/\(playbackID).m3u8") else {
                    print("Bad URL")
                    return
                }
                let playerItem = AVPlayerItem(url: url)
                let avPlayer = AVPlayer(playerItem: playerItem)
                avPlayer.automaticallyWaitsToMinimizeStalling = true
                self.player = avPlayer
                
                // Instead of resetting the StateObject, attach the observer to the new player.
                playerObserver.attach(player: avPlayer, playerItem: playerItem)
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Failed to set up audio session: \(error)")
                }
            }
        }
        // Use the external binding to control playback.
        .onChange(of: isActive) { newValue in
            if newValue {
                player?.play()
                print("ActivityView: isActive true, starting playback")
            } else {
                player?.pause()
                print("ActivityView: isActive false, pausing playback")
            }
        }
    }
}

#Preview {
    ActivityView(isActive: .constant(false))
} 