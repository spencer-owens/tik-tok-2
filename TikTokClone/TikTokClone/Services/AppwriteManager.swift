import Foundation
import Appwrite
import SwiftUI

class AppwriteManager: ObservableObject {
    static let shared = AppwriteManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var error: String?
    
    private let appwrite: Appwrite
    
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
} 