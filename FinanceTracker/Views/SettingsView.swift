import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var accounts: [Account] = []
    @State private var plaidItems: [PlaidItem] = []
    @State private var disconnecting: String?
    @State private var toastError: String? = nil
    @State private var toastSuccess: String? = nil

    var activeItems: [PlaidItem] {
        plaidItems.filter { $0.status != "revoked" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if activeItems.isEmpty {
                        Text("No banks connected")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    } else {
                        ForEach(activeItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.institution_name)
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(Theme.Colors.text)
                                    Text(item.status == "needs_reauth"
                                         ? "Needs re-authentication"
                                         : item.last_synced != nil ? "Synced" : "Not yet synced")
                                        .font(Theme.Fonts.small)
                                        .foregroundColor(item.status == "needs_reauth" ? Theme.Colors.warning : Theme.Colors.textMuted)
                                }
                                Spacer()
                                Button(disconnecting == item.item_id ? "..." : "Disconnect") {
                                    disconnect(item.item_id)
                                }
                                .font(Theme.Fonts.small)
                                .foregroundColor(Theme.Colors.error)
                            }
                        }
                    }
                } header: {
                    Text("Connected Banks")
                        .sectionHeaderStyle()
                }

                Section {
                    ForEach(accounts) { acc in
                        HStack {
                            Text(acc.name)
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.text)
                            Spacer()
                            Text(acc.account_type)
                                .font(Theme.Fonts.small)
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                    }
                } header: {
                    Text("Accounts")
                        .sectionHeaderStyle()
                }

                Section {
                    NavigationLink("Change Password") {
                        ChangePasswordView()
                    }
                    .font(Theme.Fonts.body)
                } header: {
                    Text("Account")
                        .sectionHeaderStyle()
                }

                Section {
                    Button("Sign Out") {
                        authManager.logout()
                    }
                    .foregroundColor(Theme.Colors.error)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toastError($toastError)
            .toastSuccess($toastSuccess)
        }
        .onAppear { loadData() }
    }

    func loadData() {
        Task {
            do {
                accounts = try await APIClient.shared.request("/api/accounts")
                plaidItems = try await APIClient.shared.request("/api/plaid/items")
            } catch {
                toastError = "Failed to load settings"
            }
        }
    }

    func disconnect(_ itemId: String) {
        disconnecting = itemId
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/plaid/disconnect",
                    method: "POST",
                    body: ["item_id": itemId]
                )
                loadData()
                toastSuccess = "Bank disconnected"
            } catch {
                toastError = "Failed to disconnect bank"
            }
            disconnecting = nil
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var error = ""
    @State private var success = false
    @State private var loading = false

    var body: some View {
        Form {
            Section {
                SecureField("Current Password", text: $currentPassword)
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
            }

            if !error.isEmpty {
                Section {
                    Text(error)
                        .font(Theme.Fonts.small)
                        .foregroundColor(Theme.Colors.error)
                }
            }

            if success {
                Section {
                    Text("Password changed successfully.")
                        .font(Theme.Fonts.small)
                        .foregroundColor(Theme.Colors.success)
                }
            }

            Section {
                Button(action: changePassword) {
                    HStack {
                        Spacer()
                        Text(loading ? "Updating..." : "Update Password")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                }
                .disabled(loading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                .foregroundColor(.white)
                .listRowBackground(Theme.Colors.teal)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    func changePassword() {
        error = ""
        success = false

        guard newPassword == confirmPassword else {
            error = "Passwords don't match"
            return
        }
        guard newPassword.count >= 6 else {
            error = "Password must be at least 6 characters"
            return
        }

        loading = true
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/user/password",
                    method: "POST",
                    body: [
                        "currentPassword": currentPassword,
                        "newPassword": newPassword,
                    ]
                )
                success = true
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
            } catch {
                self.error = "Failed to change password"
            }
            loading = false
        }
    }
}
