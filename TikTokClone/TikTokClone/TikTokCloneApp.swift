import SwiftUI

@main
struct TikTokCloneApp: App {
    @StateObject private var appwriteManager = AppwriteManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            if appwriteManager.isAuthenticated {
                ContentView()
                    .environmentObject(appwriteManager)
                    .environmentObject(healthKitManager)
                    .onAppear {
                        healthKitManager.requestAuthorization()
                    }
            } else {
                AuthView()
                    .environmentObject(appwriteManager)
            }
        }
    }
}