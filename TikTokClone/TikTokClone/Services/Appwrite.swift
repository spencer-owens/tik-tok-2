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
        static let audio = [
            "sound1": "67a5112d0010c1dac2f0",
            "sound2": "67a5113b0018308eabee",
            "sound3": "67a511450021836345be"
        ]
        
        static let muxVideos = [
            "cooking": [
                "feFaCHnNI3vl3rN01G01ExZrXsSxHhKxuYT1p01Yw21FKc",
                "dmbxsATxsA0100168N99vkIaP3KEq2NIv1TPcoSrSV4xI",
                "Ok1lWjHbf00tr2HKZlI2wkiJ822MaYG9x91AjWPS6y400"
            ],
            "walking": [
                "eVr202tnkQGDB1ygarME100JgaucpqJDZMFCyukB00q3L8",
                "CHV01yItQU4sjxavbg4G4Ql5spm302tgoQvM8wAy01e5D00",
                "4lMr2Mzg68eS3GLd8aC5iJ5nlMr01jkn1dPsq4CDmrTg"
            ],
            "meditation": ["QHVtYewW3ozRJvKhCcDfZvdiMd6GG7meZm001lkakOSg"]
        ]
    }
    
    // MARK: - Database Constants
    struct Database {
        static let id = "67a580230029e01e56af"
        
        struct Collections {
            static let reactions = "67a5806500128aef9d88"
        }
    }
    
    var client: Client
    var account: Account
    var databases: Databases
    var storage: Storage
    var realtime: Realtime
    
    let bucketId = "67a5108e001f86591b24"
    
    public init() {
        self.client = Client()
            .setEndpoint("https://cloud.appwrite.io/v1")
            .setProject("67a13c9400166a970385")
        
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
        switch activity {
        case .walking:
            return MediaIDs.muxVideos["walking"]!.randomElement()!
        case .meal:
            return MediaIDs.muxVideos["cooking"]!.randomElement()!
        case .meditation:
            return MediaIDs.muxVideos["meditation"]!.first!
        }
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
