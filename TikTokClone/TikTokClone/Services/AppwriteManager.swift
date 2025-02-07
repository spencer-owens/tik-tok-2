import Foundation
import Appwrite
import AppwriteModels
import SwiftUI

struct EmojiReaction: Codable, Identifiable, Equatable {
    let id: String
    let emoji: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case emoji
        case timestamp = "createdAt"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        emoji = try container.decode(String.self, forKey: .emoji)
        
        // Handle ISO8601 date string
        let dateString = try container.decode(String.self, forKey: .timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            timestamp = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .timestamp,
                  in: container,
                  debugDescription: "Date string does not match expected format")
        }
    }
    
    static func == (lhs: EmojiReaction, rhs: EmojiReaction) -> Bool {
        return lhs.id == rhs.id &&
               lhs.emoji == rhs.emoji &&
               lhs.timestamp == rhs.timestamp
    }
}

class AppwriteManager: ObservableObject {
    static let shared = AppwriteManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var recentReactions: [EmojiReaction] = []
    
    // Media-related state
    @Published var currentAudioUrl: URL?
    @Published var currentVideoId: String?
    @Published var isLoadingMedia: Bool = false
    
    private let appwrite: Appwrite
    private var realtimeSubscription: RealtimeSubscription?
    
    // Constants for Appwrite
    private let databaseId = "67a580230029e01e56af"
    private let reactionsCollectionId = "67a5806500128aef9d88"
    
    private init() {
        self.appwrite = Appwrite()
        Task {
            await checkAuthStatus()
        }
    }
    
    @MainActor
    func checkAuthStatus() async {
        isLoading = true
        isAuthenticated = await appwrite.checkSession()
        isLoading = false
    }
    
    @MainActor
    func register(email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await appwrite.onRegister(email, password)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
            // If registration fails, ensure we're marked as not authenticated
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    @MainActor
    func login(email: String, password: String) async {
        guard !isAuthenticated else {
            error = "Already logged in"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            _ = try await appwrite.onLogin(email, password)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
            // If login fails, ensure we're marked as not authenticated
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    @MainActor
    func logout() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await appwrite.onLogout()
            isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Media Management
    
    @MainActor
    func loadMediaForActivity(_ activityType: MediaAsset.ActivityCategory) async {
        isLoadingMedia = true
        error = nil
        
        do {
            // Get random audio file ID and video ID
            let audioFileId = appwrite.getRandomAudioFileId(for: activityType)
            currentVideoId = appwrite.getRandomVideoId(for: activityType)
            
            // Get the audio URL from Appwrite
            currentAudioUrl = try await appwrite.getFileView(fileId: audioFileId)
            
        } catch {
            self.error = "Failed to load media: \(error.localizedDescription)"
            print("Media loading error: \(error)")
        }
        
        isLoadingMedia = false
    }
    
    func getMuxStreamUrl(for videoId: String) -> URL? {
        return appwrite.getMuxStreamUrl(playbackId: videoId)
    }
    
    @MainActor
    func startListeningToReactions() async {
        print("🔔 Starting to listen for reactions...")
        
        // Clean up any existing subscription first
        await stopListeningToReactions()
        
        do {
            // Create new subscription
            self.realtimeSubscription = try await appwrite.subscribeToReactions()
            print("✅ Successfully subscribed to reactions channel")
            
            // Remove any existing observers to prevent duplicates
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RealtimeEvent"), object: nil)
            
            // Add new observer
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RealtimeEvent"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                print("📨 Received realtime notification event")
                
                guard let payload = notification.userInfo?["payload"] as? [String: Any] else {
                    print("❌ Failed to get payload from notification")
                    return
                }
                
                // Create JSON data from the payload
                guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
                    print("❌ Failed to serialize reaction data")
                    return
                }
                
                // Decode the JSON data into our EmojiReaction
                do {
                    let reaction = try JSONDecoder().decode(EmojiReaction.self, from: jsonData)
                    print("✅ Successfully decoded reaction: \(reaction)")
                    
                    // Only add the reaction if it's not already in the array
                    if !self.recentReactions.contains(where: { $0.id == reaction.id }) {
                        // Add to recent reactions
                        self.recentReactions.append(reaction)
                        print("📊 Current reactions count: \(self.recentReactions.count)")
                        
                        // Schedule cleanup after 2 seconds for this specific reaction
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            self.recentReactions.removeAll { $0.id == reaction.id }
                            print("🗑️ Removed old reaction: \(reaction.id)")
                        }
                    } else {
                        print("⚠️ Skipping duplicate reaction: \(reaction.id)")
                    }
                } catch {
                    print("❌ Failed to decode reaction: \(error)")
                    print("🔍 Raw JSON data: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
                }
            }
            
            // Set up auto-reconnect timer
            startReconnectTimer()
            
        } catch {
            print("❌ Failed to subscribe to reactions: \(error)")
        }
    }
    
    private func startReconnectTimer() {
        // Check connection every 30 seconds
        Task { @MainActor in
            while true {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                
                // Only attempt reconnect if we still have a subscription
                if realtimeSubscription != nil {
                    do {
                        // Test the connection by trying to get a session
                        if !(await appwrite.checkSession()) {
                            print("🔄 Connection lost, attempting to reconnect...")
                            await startListeningToReactions()
                            break
                        }
                    } catch {
                        print("🔄 Connection check failed, attempting to reconnect...")
                        await startListeningToReactions()
                        break
                    }
                } else {
                    break
                }
            }
        }
    }
    
    @MainActor
    func sendReaction(emoji: String) async {
        print("📤 Sending reaction: \(emoji)")
        do {
            let document = try await appwrite.createReaction(emoji: emoji)
            print("✅ Reaction sent successfully - ID: \(document.id)")
            // Don't add the reaction here - it will come through the subscription
        } catch {
            print("❌ Failed to send reaction: \(error)")
            self.error = "Failed to send reaction: \(error.localizedDescription)"
        }
    }
    
    func stopListeningToReactions() async {
        print("🛑 Stopping reaction subscription")
        
        // Remove observer on the main thread
        await MainActor.run {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RealtimeEvent"), object: nil)
        }
        
        // Close subscription if it exists
        if let subscription = realtimeSubscription {
            do {
                try await subscription.close()
                realtimeSubscription = nil
                print("✅ Successfully stopped reaction subscription")
            } catch {
                print("❌ Failed to stop reaction subscription: \(error)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task {
            await stopListeningToReactions()
        }
    }
} 
