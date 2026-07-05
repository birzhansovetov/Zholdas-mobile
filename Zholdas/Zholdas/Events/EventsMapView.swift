import SwiftUI
import MapKit

struct EventsMapView: View {
    @ObservedObject var eventsViewModel: EventsViewModel
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var langManager: LocalizationManager
    
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.2389, longitude: 76.8897),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    ))
    @State private var searchQuery = ""
    @State private var showCreateEventSheet = false
    @State private var selectedEvent: Event?
    @State private var showAIRecommendationsSheet = false
    @State private var isAISearchExpanded = false
    @State private var selectedCategory = "cat_all"
    
    let categories = ["cat_all", "cat_mountains", "cat_walks", "cat_sports", "cat_theater", "cat_restaurant", "cat_games", "cat_networking", "cat_other"]
    
    private var userCoordinate: CLLocationCoordinate2D? {
        guard let loc = locationManager.location else { return nil }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        if abs(lat - 37.33) < 0.5 && abs(lon - (-122.03)) < 0.5 {
            return nil
        }
        return loc.coordinate
    }

    private var defaultAlmatyCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 43.2389, longitude: 76.8897)
    }

    private var effectiveCoordinate: CLLocationCoordinate2D {
        userCoordinate ?? defaultAlmatyCoordinate
    }
    
    var filteredEvents: [Event] {
        eventsViewModel.events.filter { event in
            let matchesCat = matchesCategory(eventCategory: event.category, filterCategory: selectedCategory)
            let matchesText = searchQuery.isEmpty ||
                              event.title.localizedCaseInsensitiveContains(searchQuery) ||
                              event.description.localizedCaseInsensitiveContains(searchQuery) ||
                              event.locationName.localizedCaseInsensitiveContains(searchQuery)
            return matchesCat && matchesText
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                mapView
                
                VStack(alignment: .leading, spacing: 0) {
                    // Floating search and city info
                    cityInfoAndFiltersView
                    
                    Spacer()
                    
                    controlButtons
                }
            }
            .navigationTitle("Карта")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true) // Скрываем навигационный бар для соответствия макету
            .task {
                locationManager.requestLocation()
                loadEvents()
            }
            .onChange(of: locationManager.location) { newLocation in
                if let loc = newLocation {
                    let lat = loc.coordinate.latitude
                    let lon = loc.coordinate.longitude
                    
                    // Если локация указывает на симулятор (Apple HQ), игнорируем перенос в США
                    if abs(lat - 37.33) < 0.5 && abs(lon - (-122.03)) < 0.5 {
                        position = .region(MKCoordinateRegion(
                            center: defaultAlmatyCoordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    } else {
                        // Центрируем карту при получении реальной локации
                        position = .region(MKCoordinateRegion(
                            center: loc.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                    loadEvents()
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, eventsViewModel: eventsViewModel)
                    .presentationDetents([.fraction(0.4), .medium])
            }
            .sheet(isPresented: $showCreateEventSheet) {
                CreateEventView {
                    loadEvents()
                }
            }
            .sheet(isPresented: $showAIRecommendationsSheet) {
                AIRecommendationView(viewModel: eventsViewModel)
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func loadEvents() {
        let coordinate = effectiveCoordinate
        
        Task {
            await eventsViewModel.fetchNearbyEvents(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }
    
    private func searchWithAI() {
        guard !searchQuery.isEmpty else { return }
        let coordinate = effectiveCoordinate
        
        Task {
            await eventsViewModel.fetchAIRecommendations(
                query: searchQuery,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            showAIRecommendationsSheet = true
        }
    }
    
    // MARK: - Helper matches category
    
    private func matchesCategory(eventCategory: String, filterCategory: String) -> Bool {
        if filterCategory == "cat_all" {
            return true
        }
        
        let ec = eventCategory.lowercased()
        
        switch filterCategory {
        case "cat_mountains":
            return ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор")
        case "cat_walks":
            return ec.contains("walk") || ec.contains("прогул") || ec.contains("серуен")
        case "cat_theater":
            return ec.contains("theater") || ec.contains("theatre") || ec.contains("театр")
        case "cat_restaurant":
            return ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") || ec.contains("кафе")
        case "cat_sports":
            return ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") || ec.contains("футбол")
        case "cat_games":
            return ec.contains("board_games") || ec.contains("game") || ec.contains("игр") || ec.contains("ойын")
        case "cat_networking":
            return ec.contains("networking") || ec.contains("network") || ec.contains("нетворк")
        case "cat_other":
            let matchesSpecific = ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор") ||
                                 ec.contains("walk") || ec.contains("прогул") || ec.contains("серуен") ||
                                 ec.contains("theater") || ec.contains("theatre") || ec.contains("театр") ||
                                 ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") || ec.contains("кафе") ||
                                 ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") || ec.contains("футбол") ||
                                 ec.contains("board_games") || ec.contains("game") || ec.contains("игр") || ec.contains("ойын") ||
                                 ec.contains("networking") || ec.contains("network") || ec.contains("нетворк")
            return !matchesSpecific
        default:
            return false
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        let ec = category.lowercased()
        if ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор") {
            return "mountain.2.fill"
        } else if ec.contains("walk") || ec.contains("прогул") || ec.contains("серуен") {
            return "tree.fill"
        } else if ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") || ec.contains("футбол") {
            return "figure.run.circle.fill"
        } else if ec.contains("theater") || ec.contains("театр") {
            return "theatermasks.fill"
        } else if ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") || ec.contains("кафе") {
            return "fork.knife"
        } else if ec.contains("board_games") || ec.contains("game") || ec.contains("игр") {
            return "dice.fill"
        } else if ec.contains("networking") || ec.contains("network") || ec.contains("нетворк") {
            return "cup.and.saucer.fill"
        } else {
            return "sparkles"
        }
    }
    
    private func categoryColor(for category: String) -> Color {
        let ec = category.lowercased()
        if ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор") {
            return .green
        } else if ec.contains("walk") || ec.contains("прогул") || ec.contains("серуен") {
            return Color(red: 0.32, green: 0.78, blue: 0.54)
        } else if ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") || ec.contains("футбол") {
            return ZholdasTheme.accent
        } else if ec.contains("theater") || ec.contains("театр") {
            return .purple
        } else if ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") || ec.contains("кафе") {
            return .red
        } else if ec.contains("board_games") || ec.contains("game") || ec.contains("игр") {
            return .blue
        } else if ec.contains("networking") || ec.contains("network") || ec.contains("нетворк") {
            return Color(red: 0.58, green: 0.42, blue: 1.0)
        } else {
            return Color(red: 0.6, green: 0.5, blue: 0.9)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var mapView: some View {
        Map(position: $position) {
            UserAnnotation()
            if let coordinate = userCoordinate {
                Annotation("", coordinate: coordinate) {
                    userLocationMarker
                }
            }
            
            ForEach(filteredEvents) { event in
                Annotation(event.title, coordinate: event.coordinate) {
                    Button {
                        selectedEvent = event
                    } label: {
                        let iconName = categoryIcon(for: event.category)
                        let color = categoryColor(for: event.category)
                        
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4)
                            
                            Image(systemName: iconName)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .bottom)
    }
    
    @ViewBuilder
    private var userLocationMarker: some View {
        ZStack {
            Circle()
                .fill(ZholdasTheme.accent.opacity(0.22))
                .frame(width: 54, height: 54)
            Circle()
                .fill(ZholdasTheme.accent)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: ZholdasTheme.accent.opacity(0.5), radius: 10)
            Image(systemName: "location.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private var cityInfoAndFiltersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errMsg = eventsViewModel.errorMessage, errMsg.contains("офлайн-режим") {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    Text("map_offline_mode".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ZholdasTheme.accent.opacity(0.9))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 24)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Жолдас")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        let count = filteredEvents.count
                        Text(String(format: "map_events_in_city".localized, count))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isAISearchExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isAISearchExpanded ? "xmark" : "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isAISearchExpanded ? ZholdasTheme.accent : ZholdasTheme.accent.opacity(0.22))
                            )
                            .overlay(
                                Circle()
                                    .stroke(ZholdasTheme.accent.opacity(0.55), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if isAISearchExpanded {
                    aiSearchField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassBackground(cornerRadius: 8)
            .padding(.horizontal)
            .padding(.top, 24)

            // 2. Horizontal Categories Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = cat
                            }
                        } label: {
                            Text(cat.localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedCategory == cat ? .white : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == cat ? ZholdasTheme.accent.opacity(0.8) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedCategory == cat ? ZholdasTheme.accent : Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: selectedCategory == cat ? ZholdasTheme.accent.opacity(0.3) : Color.clear, radius: 8)
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var aiSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(ZholdasTheme.accent)

            TextField("map_search_placeholder".localized, text: $searchQuery)
                .font(.subheadline)
                .foregroundColor(.white)
                .submitLabel(.search)
                .onSubmit {
                    searchWithAI()
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    eventsViewModel.recommendedEventIDs = []
                    eventsViewModel.recommendationAnswer = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(ZholdasTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ZholdasTheme.accent.opacity(0.26), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var controlButtons: some View {
        HStack {
            Spacer()
            
            Button {
                locationManager.requestLocation()
                if let coordinate = userCoordinate {
                    withAnimation {
                        position = .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                    loadEvents()
                }
            } label: {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ZholdasTheme.accent)
                    .background(Color.white.clipShape(Circle()))
                    .shadow(color: .black.opacity(0.2), radius: 4)
            }
            
            Button {
                showCreateEventSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(Circle())
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    // MARK: - Helpers
    
    private func getEventsWord(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "ивентов"
        }
        if mod10 == 1 {
            return "ивент"
        }
        if mod10 >= 2 && mod10 <= 4 {
            return "ивента"
        }
        return "ивентов"
    }
}

// MARK: - Вспомогательное превью для вывода ИИ рекомендаций

struct AIRecommendationView: View {
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            ZholdasTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(ZholdasTheme.accent)
                    Text("map_ai_recs_title".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider().background(Color.white.opacity(0.1))
                
                if viewModel.isLoading {
                    ProgressView().tint(ZholdasTheme.accent).padding()
                } else if let answer = viewModel.recommendationAnswer {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(answer)
                                .font(.body)
                                .foregroundColor(.white)
                                .lineSpacing(4)
                            
                            if !viewModel.recommendedEventIDs.isEmpty {
                                Text("map_ai_markers_hint".localized)
                                    .font(.caption)
                                    .foregroundColor(ZholdasTheme.accent)
                                    .fontWeight(.semibold)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
        }
    }
}
