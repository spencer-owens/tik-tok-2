import Foundation
import Appwrite
import AppwriteModels
import JSONCodable

// Helper extension for Date ISO8601 formatting
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

struct MediaAsset: Codable {
    let id: String
    let type: AssetType
    let category: ActivityCategory
    let url: String
    let duration: Double
    
    enum AssetType: String, Codable {
        case audio
        case video
    }
    
    enum ActivityCategory: String, Codable {
        case walking
        case meditation
        case meal
    }
}

// Add ReactionDocument type
struct ReactionDocument: Codable {
    let emoji: String
    let createdAt: String
}

class Appwrite {
    // MARK: - Constants
    struct MediaIDs {
        static let audio = Constants.Media.audio
        static let muxVideos = Constants.Media.muxVideos
    }
    
    // MARK: - Database Constants
    struct Database {
        static let id = Constants.Appwrite.databaseId
        
        struct Collections {
            static let reactions = Constants.Appwrite.Collections.reactions
        }
    }
    
    var client: Client
    var account: Account
    var databases: Databases
    var storage: Storage
    var realtime: Realtime
    
    let bucketId = Constants.Appwrite.Buckets.main
    
    public init() {
        self.client = Client()
            .setEndpoint(Constants.Appwrite.endpoint)
            .setProject(Secrets.Appwrite.projectId)
        
        self.account = Account(client)
        self.databases = Databases(client)
        self.storage = Storage(client)
        self.realtime = Realtime(client)
    }
    
    public func checkSession() async -> Bool {
        do {
            let sessions = try await account.listSessions()
            return !sessions.sessions.isEmpty
        } catch {
            print("Session check error: \(error)")
            return false
        }
    }
    
    public func onRegister(
        _ email: String,
        _ password: String
    ) async throws -> User<[String: AnyCodable]> {
        do {
            let user = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password
            )
            _ = try await onLogin(email, password)
            return user
        } catch {
            print("Registration error: \(error)")
            throw error
        }
    }
    
    public func onLogin(
        _ email: String,
        _ password: String
    ) async throws -> Session {
        do {
            let session = try await account.createEmailPasswordSession(
                email: email,
                password: password
            )
            return session
        } catch {
            print("Login error: \(error)")
            throw error
        }
    }
    
    public func onLogout() async throws {
        do {
            _ = try await account.deleteSessions()
        } catch {
            print("Logout error: \(error)")
            throw error
        }
    }
    
    // Storage methods
    public func uploadAudioFile(fileData: Data, fileName: String) async throws -> String {
        do {
            let file = try await storage.createFile(
                bucketId: bucketId,
                fileId: ID.unique(),
                file: InputFile.fromData(fileData, filename: fileName, mimeType: "audio/mpeg")
            )
            return file.id
        } catch {
            print("Audio upload error: \(error)")
            throw error
        }
    }
    
    public func getFileView(fileId: String) async throws -> URL {
        do {
            guard await checkSession() else {
                throw NSError(domain: "AppwriteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active session"])
            }
            
            _ = try await storage.getFile(bucketId: bucketId, fileId: fileId)
            
            let urlString = "\(client.endPoint)/storage/buckets/\(bucketId)/files/\(fileId)/download?project=67a13c9400166a970385"
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "AppwriteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            return url
        } catch {
            print("Failed to get file view: \(error)")
            throw error
        }
    }
    
    // Helper method to ensure we're logged in
    private func ensureAuthenticated() async throws {
        if !(await checkSession()) {
            // You might want to modify this to use stored credentials or handle differently
            throw NSError(domain: "AppwriteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
        }
    }
    
    // MARK: - Media Methods
    public func getMuxStreamUrl(playbackId: String) -> URL? {
        return URL(string: "https://stream.mux.com/\(playbackId).m3u8")
    }
    
    public func getRandomAudioFileId(for activity: MediaAsset.ActivityCategory) -> String {
        return [MediaIDs.audio["sound1"]!,
                MediaIDs.audio["sound2"]!,
                MediaIDs.audio["sound3"]!].randomElement()!
    }
    
    public func getRandomVideoId(for activity: MediaAsset.ActivityCategory) -> String {
        print("🎥 Getting video for activity: \(activity)")
        let videoId: String
        switch activity {
        case .walking:
            videoId = MediaIDs.muxVideos["walking"]!.randomElement()!
            print("🚶‍♂️ Selected walking video: \(videoId)")
        case .meal:
            videoId = MediaIDs.muxVideos["cooking"]!.randomElement()!
            print("🍽️ Selected meal video: \(videoId)")
        case .meditation:
            videoId = MediaIDs.muxVideos["meditation"]!.first! // Always use the first (and only) meditation video
            print("🧘‍♂️ Selected meditation video: \(videoId)")
        }
        return videoId
    }
    
    // MARK: - Reactions Methods
    public func createReaction(emoji: String) async throws -> Document<[String: AnyCodable]> {
        let data: [String: String] = [
            "emoji": emoji,
            "createdAt": Date().iso8601String
        ]
        return try await databases.createDocument(
            databaseId: Database.id,
            collectionId: Database.Collections.reactions,
            documentId: ID.unique(),
            data: data as [String : Any]
        )
    }
    
    public func subscribeToReactions() async throws -> RealtimeSubscription {
        print("🔄 Setting up realtime subscription for reactions")
        let channel = "databases.\(Database.id).collections.\(Database.Collections.reactions).documents"
        print("📡 Channel: \(channel)")
        
        return try await realtime.subscribe(channels: [channel]) { response in
            print("📥 Received realtime event")
            print("Events: \(String(describing: response.events))")
            
            guard let events = response.events,
                  let payload = response.payload else {
                print("⚠️ No events or payload in response")
                return
            }
            
            // Only process create events to prevent duplicates
            let isCreateEvent = events.contains("databases.\(Database.id).collections.\(Database.Collections.reactions).documents.*.create")
            
            guard isCreateEvent else {
                print("⚠️ Skipping non-create event")
                return
            }
            
            print("📦 Valid create event received, broadcasting...")
            print("📦 Payload: \(payload)")
            
            // Post notification with payload on main thread
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: NSNotification.Name("RealtimeEvent"),
                    object: nil,
                    userInfo: ["payload": payload]
                )
            }
        }
    }
}
