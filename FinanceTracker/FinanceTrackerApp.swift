import SwiftUI

@main
struct FinanceTrackerApp: App {
    @StateObject private var authManager = AuthManager()

    init() {
        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .white
        navAppearance.shadowColor = UIColor(hex: "#eaeaea")
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor(hex: "#171717"),
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(hex: "#171717")

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .white
        tabAppearance.shadowColor = UIColor(hex: "#eaeaea")
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Segmented control
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(hex: "#171717")
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(hex: "#666666")], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            if authManager.isChecking {
                // Branded splash while validating cached session
                VStack {
                    Spacer()
                    CanopyMarkView(size: 64, variant: .color)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .ignoresSafeArea()
            } else if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
