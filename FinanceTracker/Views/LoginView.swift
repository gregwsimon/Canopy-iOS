import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo
            CanopyMarkView(size: 56, variant: .color)
                .padding(.bottom, 24)

            CanopyWordmarkView(size: 22)

            Text("A place to grow.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.top, 4)
                .padding(.bottom, 32)
            
            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .font(.system(size: 14))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .font(.system(size: 14))
                
                if let error = authManager.error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.error)
                }
                
                Button(action: {
                    Task {
                        await authManager.login(username: username, password: password)
                    }
                }) {
                    Text(authManager.isLoading ? "Signing in..." : "Continue")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Theme.Colors.teal)
                        .cornerRadius(8)
                }
                .disabled(authManager.isLoading || username.isEmpty || password.isEmpty)
                .opacity((username.isEmpty || password.isEmpty) ? 0.5 : 1)
            }
            .frame(maxWidth: 320)
            
            Spacer()
        }
        .padding()
        .background(Theme.Colors.background)
    }
}
