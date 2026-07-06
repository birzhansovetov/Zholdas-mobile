import SwiftUI
import CoreLocation

struct EventsListView: View {
    @ObservedObject var eventsViewModel: EventsViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var selectedCategory = "cat_all"
    @State private var showAdvancedFilters = false
    @State private var filterGender = "all"
    @State private var filterAge = 18
    @State private var maxDistanceKm = 10.0
    @State private var onlyToday = false
    @State private var nearMeOnly = false
    
    let categories = ["cat_all", "cat_mountains", "cat_walks", "cat_sports", "cat_theater", "cat_restaurant", "cat_games", "cat_networking", "cat_other"]
    
    var filteredEvents: [Event] {
        eventsViewModel.events.filter { event in
            let matchesCategory = matchesCategory(eventCategory: event.category, filterCategory: selectedCategory)
            let matchesAudience = event.matchesAudienceFilters(
                gender: filterGender,
                age: filterAge,
                maxDistanceKm: maxDistanceKm,
                distanceMetersOverride: localDistanceMeters(to: event)
            )
            return matchesCategory && matchesAudience && matchesDateFilter(event) && matchesNearMeFilter(event)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("tab_events".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        
                        Text(String(format: "list_events_nearby".localized, filteredEvents.count))
                            .font(.subheadline)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            showAdvancedFilters.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            Text(filtersSummary)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: showAdvancedFilters ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ZholdasTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(ZholdasTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                    if showAdvancedFilters {
                        advancedFiltersPanel
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Horizontal Categories Filter
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
                                        .foregroundColor(selectedCategory == cat ? .white : ZholdasTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategory == cat ? ZholdasTheme.accentSoft : ZholdasTheme.panel)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedCategory == cat ? ZholdasTheme.accent.opacity(0.55) : ZholdasTheme.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 16)
                    
                    // Events List ScrollView
                    if filteredEvents.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "figure.run.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(ZholdasTheme.textSecondary)
                            Text("list_no_events_found".localized)
                                .font(.headline)
                                .foregroundColor(ZholdasTheme.textPrimary)
                            Text("list_no_events_hint".localized)
                                .font(.subheadline)
                                .foregroundColor(ZholdasTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredEvents) { event in
                                    NavigationLink(destination: EventDetailView(event: event, eventsViewModel: eventsViewModel)) {
                                        EventRowCard(event: event, isRecommended: eventsViewModel.recommendedEventIDs.contains(event.id))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(24)
                        }
                    }
                }
            }
        }
        .task {
            if let profileAge = authViewModel.currentUserProfile?.age, profileAge > 0 {
                filterAge = profileAge
            }
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { location in
            guard let location else { return }
            Task {
                await eventsViewModel.fetchNearbyEvents(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radiusMeters: Int(maxDistanceKm * 1000)
                )
            }
        }
        .onChange(of: maxDistanceKm) { _ in
            guard let location = locationManager.location else { return }
            Task {
                await eventsViewModel.fetchNearbyEvents(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radiusMeters: Int(maxDistanceKm * 1000)
                )
            }
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

    private func localDistanceMeters(to event: Event) -> Double? {
        guard let location = locationManager.location else {
            return nil
        }
        let eventLocation = CLLocation(latitude: event.latitude, longitude: event.longitude)
        return eventLocation.distance(from: location)
    }

    private var filtersSummary: String {
        var parts = ["\(Int(maxDistanceKm)) км", "\(filterAge) лет"]
        if onlyToday {
            parts.append("сегодня")
        }
        if nearMeOnly {
            parts.append("рядом")
        }
        return "Фильтры: " + parts.joined(separator: " · ")
    }

    private func matchesDateFilter(_ event: Event) -> Bool {
        !onlyToday || Calendar.current.isDateInToday(event.startTime)
    }

    private func matchesNearMeFilter(_ event: Event) -> Bool {
        guard nearMeOnly else { return true }
        guard let distance = localDistanceMeters(to: event) else { return false }
        return distance <= min(maxDistanceKm, 3) * 1000
    }
    
    private func getEventsWord(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "активностей"
        }
        if mod10 == 1 {
            return "активность"
        }
        if mod10 >= 2 && mod10 <= 4 {
            return "активности"
        }
        return "активностей"
    }

    @ViewBuilder
    private var advancedFiltersPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Дистанция", systemImage: "location.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(ZholdasTheme.textPrimary)
                Spacer()
                Text("\(Int(maxDistanceKm)) км")
                    .font(.caption.weight(.bold))
                    .foregroundColor(ZholdasTheme.accent)
            }

            Slider(value: $maxDistanceKm, in: 1...50, step: 1)
                .tint(ZholdasTheme.accent)

            HStack(spacing: 8) {
                filterChip(title: "Все", value: "all")
                filterChip(title: "Мужчины", value: "men")
                filterChip(title: "Женщины", value: "women")
            }

            Stepper(value: $filterAge, in: 12...80) {
                HStack {
                    Text("Возраст")
                        .foregroundColor(ZholdasTheme.textPrimary)
                    Spacer()
                    Text("\(filterAge)")
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.accent)
                }
            }
            .tint(ZholdasTheme.accent)

            Toggle(isOn: $onlyToday) {
                Label("Только сегодня", systemImage: "calendar")
                    .foregroundColor(ZholdasTheme.textPrimary)
            }
            .tint(ZholdasTheme.accent)

            Toggle(isOn: $nearMeOnly) {
                Label("Рядом со мной", systemImage: "location.fill")
                    .foregroundColor(ZholdasTheme.textPrimary)
            }
            .tint(ZholdasTheme.accent)
        }
        .padding(14)
        .background(ZholdasTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }

    private func filterChip(title: String, value: String) -> some View {
        Button {
            filterGender = value
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(filterGender == value ? .white : ZholdasTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(filterGender == value ? ZholdasTheme.accent : ZholdasTheme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct EventRowCard: View {
    let event: Event
    let isRecommended: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Категория
                Text(categoryTitle(for: event.category).uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ZholdasTheme.accent.opacity(isRecommended ? 0.28 : 0.18))
                    .foregroundColor(ZholdasTheme.accent)
                    .cornerRadius(6)
                
                Spacer()
                
                // Статус
                Text(event.status == "active" ? "ev_active".localized : event.status.localized)
                    .font(.caption2)
                .foregroundColor(ZholdasTheme.success)
            }
            
            // Название
            Text(event.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textPrimary)
                .multilineTextAlignment(.leading)
            
            // Описание (первые 2 строки)
            Text(event.description)
                .font(.subheadline)
                .foregroundColor(ZholdasTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Divider().background(ZholdasTheme.border)
            
            // Время и Локация
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(ZholdasTheme.accent)
                    Text(formatDate(event.startTime))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(ZholdasTheme.accent)
                    Text(event.locationName)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundColor(ZholdasTheme.textSecondary)
        }
        .modernCard(strokeColor: isRecommended ? ZholdasTheme.accent.opacity(0.44) : ZholdasTheme.border)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let currentLang = LocalizationManager.shared.currentLanguage
        formatter.locale = Locale(identifier: currentLang == "kk" ? "kk_KZ" : (currentLang == "en" ? "en_US" : "ru_RU"))
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter.string(from: date)
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
