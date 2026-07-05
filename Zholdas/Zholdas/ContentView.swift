import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @StateObject private var eventsViewModel = EventsViewModel()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.027, green: 0.020, blue: 0.070, alpha: 0.98)
                : UIColor(red: 0.975, green: 0.960, blue: 1.000, alpha: 0.98)
        }
        appearance.shadowColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.06)
                : UIColor(red: 0.255, green: 0.165, blue: 0.530, alpha: 0.14)
        }
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.58, green: 0.42, blue: 1.0, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.58, green: 0.42, blue: 1.0, alpha: 1),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.46)
                : UIColor(red: 0.345, green: 0.295, blue: 0.455, alpha: 0.72)
        }
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.46)
                    : UIColor(red: 0.345, green: 0.295, blue: 0.455, alpha: 0.72)
            },
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            // Вкладка 1: Карта событий
            EventsMapView(eventsViewModel: eventsViewModel)
                .tabItem {
                    Label("tab_map".localized, systemImage: "map.fill")
                }
            
            // Вкладка 2: Ивенты (Список событий)
            EventsListView(eventsViewModel: eventsViewModel)
                .tabItem {
                    Label("tab_events".localized, systemImage: "list.bullet")
                }
            
            // Вкладка 3: Чаты
            ChatsListView()
                .tabItem {
                    Label("tab_chats".localized, systemImage: "bubble.left.and.bubble.right.fill")
                }
            
            // Вкладка 4: Активность
            ActivityView()
                .tabItem {
                    Label("tab_activity".localized, systemImage: "bell.fill")
                }
                .badge(authViewModel.unreadNotificationsCount)
            
            // Вкладка 5: Профиль пользователя
            ProfileTabView()
                .tabItem {
                    Label("tab_profile".localized, systemImage: "person.fill")
                }
        }
        .tint(ZholdasTheme.accent)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
