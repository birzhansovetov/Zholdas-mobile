import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @StateObject private var eventsViewModel = EventsViewModel()
    @State private var selectedTab = 0
    @State private var openedDeepLinkEvent: Event?
    @State private var showNotFoundAlert = false

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
        TabView(selection: $selectedTab) {
            // Вкладка 1: Карта событий
            EventsMapView(eventsViewModel: eventsViewModel)
                .tabItem {
                    Label("tab_map".localized, systemImage: "map.fill")
                }
                .tag(0)
            
            // Вкладка 2: Ивенты (Список событий)
            EventsListView(eventsViewModel: eventsViewModel)
                .tabItem {
                    Label("tab_events".localized, systemImage: "list.bullet")
                }
                .tag(1)
            
            // Вкладка 3: Чаты
            ChatsListView()
                .tabItem {
                    Label("tab_chats".localized, systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(2)
            
            // Вкладка 4: Активность
            ActivityView()
                .tabItem {
                    Label("tab_activity".localized, systemImage: "bell.fill")
                }
                .badge(authViewModel.unreadNotificationsCount)
                .tag(3)
            
            // Вкладка 5: Профиль пользователя
            ProfileTabView()
                .tabItem {
                    Label("tab_profile".localized, systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(ZholdasTheme.accent)
        .sheet(item: $openedDeepLinkEvent) { event in
            NavigationStack {
                EventDetailView(event: event, eventsViewModel: eventsViewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("btn_close".localized) {
                                openedDeepLinkEvent = nil
                            }
                        }
                    }
            }
            .environmentObject(authViewModel)
            .environmentObject(langManager)
        }
        .alert("ev_open_not_found".localized, isPresented: $showNotFoundAlert) {
            Button("btn_ok".localized, role: .cancel) {}
        }
        .onAppear {
            handlePendingEvent(authViewModel.pendingEventID)
        }
        .onChange(of: authViewModel.pendingEventID) { newID in
            handlePendingEvent(newID)
        }
    }

    private func handlePendingEvent(_ id: Int?) {
        guard authViewModel.isAuthenticated, let eventID = id else { return }
        selectedTab = 1
        authViewModel.pendingEventID = nil
        Task {
            if let event = await eventsViewModel.loadEventDetails(id: eventID) {
                openedDeepLinkEvent = event
            } else {
                showNotFoundAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
