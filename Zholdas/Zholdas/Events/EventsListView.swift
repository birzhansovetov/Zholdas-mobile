import SwiftUI

struct EventsListView: View {
    @ObservedObject var eventsViewModel: EventsViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @State private var selectedCategory = "cat_all"
    
    let categories = ["cat_all", "cat_mountains", "cat_walks", "cat_sports", "cat_theater", "cat_restaurant", "cat_games", "cat_networking", "cat_other"]
    
    var filteredEvents: [Event] {
        eventsViewModel.events.filter { event in
            matchesCategory(eventCategory: event.category, filterCategory: selectedCategory)
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
                            .foregroundColor(.white)
                        
                        Text(String(format: "list_events_nearby".localized, filteredEvents.count))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
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
                                .foregroundColor(.gray)
                            Text("list_no_events_found".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("list_no_events_hint".localized)
                                .font(.subheadline)
                                .foregroundColor(.gray)
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
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            // Описание (первые 2 строки)
            Text(event.description)
                .font(.subheadline)
                .foregroundColor(ZholdasTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Divider().background(Color.white.opacity(0.1))
            
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
