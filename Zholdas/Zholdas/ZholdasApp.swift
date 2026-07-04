import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("AppDelegate: Registered for push notifications with token: \(token)")
        
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        
        NotificationCenter.default.post(name: Notification.Name("RegisterDeviceTokenNotification"), object: token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

@main
struct ZholdasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var langManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .onAppear {
                            authViewModel.requestNotificationPermission()
                        }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(langManager)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                authViewModel.handlePasswordResetURL(url)
            }
            .sheet(isPresented: $authViewModel.isShowingPasswordReset) {
                ResetPasswordView()
                    .environmentObject(authViewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RegisterDeviceTokenNotification"))) { notification in
                if let token = notification.object as? String {
                    Task {
                        await authViewModel.registerDeviceToken(token)
                    }
                }
            }
        }
    }
}
