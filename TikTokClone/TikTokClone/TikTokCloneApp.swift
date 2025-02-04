import SwiftUI

@main
struct TikTokCloneApp: App {
    @StateObject private var appwriteManager = AppwriteManager.shared
    
    var body: some Scene {
        WindowGroup {
            if appwriteManager.isAuthenticated {
                ContentView()
                    .environmentObject(appwriteManager)
            } else {
                AuthView()
                    .environmentObject(appwriteManager)
            }
        }
    }
}