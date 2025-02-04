import SwiftUI

struct AuthView: View {
    @StateObject private var appwriteManager = AppwriteManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoginMode = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo/Title
                Text("ReelTok")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Form Fields
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Error Message
                if let error = appwriteManager.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Login/Register Button
                Button(action: {
                    Task {
                        if isLoginMode {
                            await appwriteManager.login(email: email, password: password)
                        } else {
                            await appwriteManager.register(email: email, password: password)
                        }
                    }
                }) {
                    if appwriteManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isLoginMode ? "Log In" : "Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Toggle Login/Register
                Button(action: {
                    isLoginMode.toggle()
                }) {
                    Text(isLoginMode ? "Need an account? Sign Up" : "Already have an account? Log In")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    AuthView()
} 