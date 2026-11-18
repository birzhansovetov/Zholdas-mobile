import SwiftUI

struct MyEventsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var eventsViewModel = EventsViewModel()
    @State private var selectedFilter = 0 // 0: Созданные, 1: Участие
    
    var body: some View {
        ZStack {
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack {
                Picker("events_filter".localized, selection: $selectedFilter) {
                    Text("my_events_created".localized).tag(0)
                    Text("my_events_participation".localized).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if eventsViewModel.isLoading {
                    Spacer()
                    ProgressView().tint(ZholdasTheme.accent)
                    Spacer()
                } else {
                    let filtered = eventsViewModel.events.filter { event in
                        let currentUserId = authViewModel.currentUserProfile?.id ?? ""
                        if selectedFilter == 0 {
                            return event.creatorID == currentUserId
                        } else {
                            return (event.isJoined ?? false) && event.creatorID != currentUserId
                        }
                    }
                    
                    if filtered.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(ZholdasTheme.textSecondary)
                            Text("my_events_empty".localized)
                                .foregroundColor(ZholdasTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        List(filtered) { event in
                            NavigationLink {
                                EventDetailView(event: event, eventsViewModel: eventsViewModel)
                                    .environmentObject(authViewModel)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(event.title)
                                            .font(.headline)
                                            .foregroundColor(ZholdasTheme.textPrimary)
                                        Spacer()
                                        Text(categoryTitle(for: event.category))
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(ZholdasTheme.accent.opacity(0.15))
                                            .foregroundColor(ZholdasTheme.accent)
                                            .cornerRadius(6)
                                    }
                                    
                                    Text(event.locationName)
                                        .font(.subheadline)
                                        .foregroundColor(ZholdasTheme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(ZholdasTheme.panel)
                        }
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await eventsViewModel.fetchNearbyEvents(latitude: 43.2389, longitude: 76.8897)
                        }
                    }
                }
            }
        }
        .navigationTitle("prof_my_events".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Use Almaty coordinates to fetch user events list
            await eventsViewModel.fetchNearbyEvents(latitude: 43.2389, longitude: 76.8897)
        }
        .refreshable {
            await eventsViewModel.fetchNearbyEvents(latitude: 43.2389, longitude: 76.8897)
        }
    }

    private func categoryTitle(for category: String) -> String {
        switch category.lowercased() {
        case "hiking": return "cat_mountains".localized
        case "walk": return "cat_walks".localized
        case "sports": return "cat_sports".localized
        case "theater": return "cat_theater".localized
        case "restaurant": return "cat_restaurant".localized
        case "board_games": return "cat_games".localized
        case "networking": return "cat_networking".localized
        default: return category.hasPrefix("cat_") ? category.localized : "cat_other".localized
        }
    }
}
