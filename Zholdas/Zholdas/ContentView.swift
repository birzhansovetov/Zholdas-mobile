import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @StateObject private var eventsViewModel = EventsViewModel()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.027, green: 0.020, blue: 0.070, alpha: 0.98)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.58, green: 0.42, blue: 1.0, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.46)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.46),
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
