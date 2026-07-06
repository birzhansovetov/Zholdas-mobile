import SwiftUI
import MapKit
import Combine

private struct SelectedUserForDetail: Identifiable {
    let id: String
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct EventWeatherSummary: Equatable {
    let temperature: Double
    let apparentTemperature: Double?
    let precipitation: Double?
    let windSpeed: Double?
    let code: Int?

    var conditionText: String {
        guard let code else { return "Прогноз" }
        switch code {
        case 0: return "Ясно"
        case 1...3: return "Переменная облачность"
        case 45, 48: return "Туман"
        case 51...67, 80...82: return "Дождь"
        case 71...77, 85...86: return "Снег"
        case 95...99: return "Гроза"
        default: return "Прогноз"
        }
    }

    var icon: String {
        guard let code else { return "cloud.sun.fill" }
        switch code {
        case 0: return "sun.max.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85...86: return "snowflake"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    var checklistText: String {
        var parts = ["\(conditionText), \(Int(round(temperature)))°C"]
        if let apparentTemperature {
            parts.append("ощущается \(Int(round(apparentTemperature)))°C")
        }
        if let precipitation, precipitation > 0 {
            parts.append("осадки \(String(format: "%.1f", precipitation)) мм")
        }
        if let windSpeed {
            parts.append("ветер \(Int(round(windSpeed))) км/ч")
        }
        return parts.joined(separator: ", ")
    }
}

private struct OpenMeteoResponse: Codable {
    let current: Current

    struct Current: Codable {
        let temperature2m: Double
        let apparentTemperature: Double?
        let precipitation: Double?
        let weatherCode: Int?
        let windSpeed10m: Double?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitation
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
        }
    }
}

struct EventDetailView: View {
    let event: Event
    @ObservedObject var eventsViewModel: EventsViewModel
    @StateObject private var liveLocationManager = LocationManager()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isJoined: Bool = false
    @State private var participantsCount: Int = 0
    @State private var participants: [Participant] = []
    @State private var isLoadingParticipants = false
    @State private var isActionLoading = false
    @State private var isArrivalLoading = false
    @State private var isArrived = false
    @State private var arrivalError: String?
    @State private var selectedUserForDetail: SelectedUserForDetail? = nil
    @State private var isShowingRateSheet = false
    @State private var isShowingReportSheet = false
    @State private var localSession: ChatSession? = nil
    @State private var organizerProfile: User? = nil
    @State private var isShowingPreparationSheet = false
    @State private var isLoadingPreparation = false
    @State private var preparationChecklist = ""
    @State private var isSharingLiveLocation = false
    @State private var liveLocations: [EventLiveLocation] = []
    @State private var liveLocationError: String?
    @State private var liveMapPosition: MapCameraPosition = .automatic
    @State private var weatherSummary: EventWeatherSummary?
    @State private var isLoadingWeather = false
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isShowingEditSheet = false

    private let liveLocationTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private var sessionBinding: Binding<ChatSession> {
        Binding(
            get: {
                localSession ?? ChatSession(
                    id: event.id,
                    title: event.title,
                    timeLabel: "Активен",
                    lastMessage: "",
                    lastMessageSender: "",
                    lastMessageTime: event.startTime,
                    isCompleted: event.status != "active",
                    categoryIcon: "sparkles",
                    categoryColorHex: "#7C5CFF",
                    messages: []
                )
            },
            set: { localSession = $0 }
        )
    }
    
    var isCreator: Bool {
        guard let currentUserId = authViewModel.currentUserProfile?.id else { return false }
        return event.creatorID == currentUserId
    }
    
    var organizerName: String {
        organizerProfile?.fullName
            ?? participants.first(where: { $0.id == event.creatorID })?.fullName
            ?? "ev_organizer_loading".localized
    }

    var organizerUsername: String? {
        organizerProfile?.username
            ?? participants.first(where: { $0.id == event.creatorID })?.username
    }
    
    var daysLeftText: String {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: event.startTime)
        if let day = diff.day {
            if day > 0 {
                return String(format: "ev_starts_in_days_format".localized, day)
            } else if day == 0 {
                return "ev_starts_today".localized
            }
        }
        return "ev_already_started".localized
    }

    private var isLiveLocationAvailable: Bool {
        (isJoined || isCreator)
            && event.status == "active"
            && Date() >= event.startTime.addingTimeInterval(-3600)
            && Date() <= event.endTime.addingTimeInterval(900)
    }

    private var shouldShowWeather: Bool {
        let category = event.category.lowercased()
        return category == "walk"
            || category == "cat_walks"
            || category == "hiking"
            || category == "cat_mountains"
    }

    private var currentDistanceMeters: Double? {
        if let location = liveLocationManager.location {
            let eventLocation = CLLocation(latitude: event.latitude, longitude: event.longitude)
            return eventLocation.distance(from: location)
        }
        return event.distanceMeters
    }
    
    var body: some View {
        ZStack {
            // Sleek Dark Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // 1. Cover Image
                    if let imageURL = event.imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } placeholder: {
                            ProgressView()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                        }
                    } else {
                        // Default beautiful mountain/activity placeholder gradient
                        ZStack {
                            LinearGradient(
                                colors: [Color(red: 0.25, green: 0.15, blue: 0.45), Color(red: 0.15, green: 0.08, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundColor(ZholdasTheme.accent)
                                Text("ev_default_cover_title".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    
                    // 2. Info Container Card
                    VStack(alignment: .leading, spacing: 20) {
                        // Category and Status badges
                        HStack {
                            categoryBadge
                            
                            Spacer()
                            
                            statusBadge
                        }
                        
                        // Title and days countdown
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(ZholdasTheme.textPrimary)
                            
                            Text(daysLeftText)
                                .font(.subheadline)
                                .foregroundColor(ZholdasTheme.textSecondary)
                        }
                        
                        // Stats Grid (3 cards in a row)
                        HStack(spacing: 12) {
                            statCard(title: "\(max(0, Int(event.maxParticipants) - participantsCount))", label: "ev_remaining_seats".localized)
                            statCard(title: "\(participantsCount)/\(event.maxParticipants)", label: "ev_participants".localized)
                            statCard(title: event.status == "active" ? "ev_active".localized : "ev_finished".localized, label: "ev_status".localized, isStatus: true)
                        }
                    }
                    .padding(20)
                    .glassBackground(cornerRadius: 24)
                    
                    // 3. Detail Items (Organizer, Date, Location)
                    VStack(spacing: 12) {
                        organizerCard
                        
                        // Date & Time Card
                        HStack(spacing: 16) {
                            Image(systemName: "calendar")
                                .font(.title3)
                                .foregroundColor(ZholdasTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ev_date_time".localized.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                                    .tracking(1.0)
                                
                                Text(formatDate(event.startTime))
                                    .foregroundColor(ZholdasTheme.textPrimary)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .padding()
                        .glassBackground(cornerRadius: 16)
                        
                        // Location Card
                        HStack(spacing: 16) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3)
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ev_location".localized.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                                    .tracking(1.0)
                                
                                Text(event.locationName)
                                    .foregroundColor(ZholdasTheme.textPrimary)
                                    .fontWeight(.bold)
                                
                                if let dist = currentDistanceMeters {
                                    Text("\("ev_distance".localized): \(String(format: "%.1f км", dist / 1000.0))")
                                        .font(.caption)
                                        .foregroundColor(ZholdasTheme.textSecondary)
                                } else {
                                    Text("ev_distance_calculating".localized)
                                        .font(.caption)
                                        .foregroundColor(ZholdasTheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .glassBackground(cornerRadius: 16)
                    }

                    if shouldShowWeather {
                        weatherCard
                    }

                    if isLiveLocationAvailable {
                        liveLocationCard
                    }
                    
                    // 4. Restrictions Banner
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("ev_restrictions".localized)
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                    
                    // 5. Description Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("create_ev_desc".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        
                        Text(event.description)
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassBackground(cornerRadius: 16)
                    
                    // 6. Participants Ratio & Progress Bar
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ev_participants".localized)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(ZholdasTheme.textPrimary)
                            Spacer()
                            Text("\(participantsCount)/\(event.maxParticipants)")
                                .font(.subheadline)
                                .foregroundColor(ZholdasTheme.textSecondary)
                        }
                        
                        // Custom Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                
                                let progress = CGFloat(participantsCount) / CGFloat(event.maxParticipants)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ZholdasTheme.accent)
                                    .frame(width: geo.size.width * min(max(progress, 0.0), 1.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("ev_remaining_seats".localized + ": \(max(0, Int(event.maxParticipants) - participantsCount))")
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.textSecondary)
                        
                        // Navigation Link to List
                        NavigationLink {
                            ParticipantsListView(participants: participants)
                                .environmentObject(authViewModel)
                        } label: {
                            Text("ev_view_all_participants".localized)
                                .fontWeight(.bold)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ZholdasTheme.surface.opacity(0.72))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                    .padding()
                    .glassBackground(cornerRadius: 16)
                    
                    // 7. How it works Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ev_how_it_runs".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                ruleIcon("clock.fill")
                                Text("ev_how_it_runs_rule1".localized)
                                    .font(.subheadline)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                ruleIcon("bubble.left.and.bubble.right.fill")
                                Text("ev_how_it_runs_rule2".localized)
                                    .font(.subheadline)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                ruleIcon("star.fill")
                                Text("ev_how_it_runs_rule3".localized)
                                    .font(.subheadline)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassBackground(cornerRadius: 16)
                    
                    // 8. Join / Leave Purple Button
                    joinActionButton
                        .padding(.top, 8)

                    preparationButton
                    
                    // 9. Bottom Action Buttons (Share & Route)
                    HStack(spacing: 12) {
                        Button {
                            shareEvent()
                        } label: {
                            Text("ev_share_btn".localized)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ZholdasTheme.surface.opacity(0.72))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(SpringButtonStyle())
                        
                        Button {
                            openRouteToEvent()
                        } label: {
                            Text("ev_route_btn".localized)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ZholdasTheme.surface.opacity(0.72))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isJoined = event.isJoined ?? false
            participantsCount = Int(event.participantsCount ?? 0)
            liveLocationManager.requestLocation()
            await loadParticipants()
            await loadOrganizer()
            
            // Initialize localSession for direct ChatRoomView navigation
            let (icon, color) = mapCategoryToIconAndColor(event.category)
            localSession = ChatSession(
                id: event.id,
                title: event.title,
                timeLabel: "Активен",
                lastMessage: "",
                lastMessageSender: "",
                lastMessageTime: event.startTime,
                isCompleted: event.status != "active",
                categoryIcon: icon,
                categoryColorHex: color,
                messages: []
            )

            if isLiveLocationAvailable {
                await loadLiveLocations()
            }
            if shouldShowWeather {
                await loadWeather()
            }
        }
        .onReceive(liveLocationTimer) { _ in
            guard isSharingLiveLocation, isLiveLocationAvailable else { return }
            liveLocationManager.requestLocation()
            Task {
                await sendLiveLocationIfPossible()
                await loadLiveLocations()
            }
        }
        .onChange(of: liveLocationManager.location) { _ in
            guard isSharingLiveLocation, isLiveLocationAvailable else { return }
            Task {
                await sendLiveLocationIfPossible()
                await loadLiveLocations()
            }
        }
        .onDisappear {
            if isSharingLiveLocation {
                Task {
                    await eventsViewModel.stopLiveLocation(eventID: event.id)
                }
            }
        }
        .sheet(item: $selectedUserForDetail) { selectedUser in
            UserDetailView(userID: selectedUser.id)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $isShowingRateSheet) {
            RateParticipantsView(eventID: event.id, participants: participants)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportView(reportedUserID: nil, eventID: event.id, messageID: nil)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $isShowingPreparationSheet) {
            PreparationChecklistView(
                eventTitle: event.title,
                checklist: preparationChecklist,
                isLoading: isLoadingPreparation
            )
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .sheet(isPresented: $isShowingEditSheet) {
            EditEventView(event: event, eventsViewModel: eventsViewModel) {
                Task {
                    if let location = liveLocationManager.location {
                        await eventsViewModel.fetchNearbyEvents(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            radiusMeters: 50000
                        )
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingReportSheet = true
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
    }

    private var publicEventURL: URL {
        AppConfig.publicBackendBaseURL.appendingPathComponent("events/\(event.id)")
    }

    private func shareEvent() {
        let shareText = """
        \("ev_share_prefix".localized): \(event.title)
        \("ev_share_at".localized) \(event.locationName)
        \(publicEventURL.absoluteString)
        """
        shareItems = [shareText, publicEventURL]
        isShowingShareSheet = true
    }

    private func openRouteToEvent() {
        let latitude = event.latitude
        let longitude = event.longitude
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        let dgisAppURL = URL(string: "dgis://2gis.ru/routeSearch/rsType/car/to/\(longitude),\(latitude)")
        let dgisWebURL = URL(string: "https://2gis.kz/almaty/routeSearch/rsType/car/to/\(longitude),\(latitude)")

        if let dgisAppURL {
            UIApplication.shared.open(dgisAppURL) { success in
                if success {
                    return
                }

                if let dgisWebURL {
                    UIApplication.shared.open(dgisWebURL) { webSuccess in
                        if !webSuccess {
                            openAppleMapsRoute(to: coordinate, name: event.locationName)
                        }
                    }
                } else {
                    openAppleMapsRoute(to: coordinate, name: event.locationName)
                }
            }
            return
        }

        if let dgisWebURL {
            UIApplication.shared.open(dgisWebURL) { success in
                if !success {
                    openAppleMapsRoute(to: coordinate, name: event.locationName)
                }
            }
            return
        }

        openAppleMapsRoute(to: coordinate, name: event.locationName)
    }

    private func openAppleMapsRoute(to coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    // MARK: - Subviews
    
    private var categoryBadge: some View {
        let info = categoryInfo(for: event.category)
        return HStack(spacing: 4) {
            Image(systemName: info.icon)
                .font(.caption2.weight(.bold))
            Text(info.title.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ZholdasTheme.accent.opacity(0.15))
        .foregroundColor(ZholdasTheme.accent)
        .cornerRadius(8)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(event.status == "active" ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(event.status == "active" ? "ev_status_active".localized : "ev_status_finished".localized)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(event.status == "active" ? .green : .gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(event.status == "active" ? Color.green.opacity(0.15) : ZholdasTheme.surface.opacity(0.7))
        .cornerRadius(8)
    }

    private var organizerCard: some View {
        Button {
            selectedUserForDetail = SelectedUserForDetail(id: event.creatorID)
        } label: {
            HStack(spacing: 16) {
                ZholdasAvatarView(
                    avatarURL: organizerProfile?.avatarURL,
                    initials: getInitials(from: organizerName),
                    size: 46
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("ev_organizer".localized.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .tracking(1.0)

                    Text(organizerName)
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .fontWeight(.bold)

                    if let username = organizerUsername, !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.accent)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
            .padding()
            .glassBackground(cornerRadius: 16)
        }
        .buttonStyle(SpringButtonStyle())
    }

    private var weatherCard: some View {
        HStack(spacing: 16) {
            Image(systemName: weatherSummary?.icon ?? "cloud.sun.fill")
                .font(.title2)
                .foregroundColor(ZholdasTheme.accent)
                .frame(width: 48, height: 48)
                .background(Circle().fill(ZholdasTheme.accent.opacity(0.14)))

            VStack(alignment: .leading, spacing: 5) {
                Text("Погода для встречи".uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .tracking(1.0)

                if let weatherSummary {
                    Text("\(weatherSummary.conditionText), \(Int(round(weatherSummary.temperature)))°C")
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .fontWeight(.bold)

                    Text(weatherSummary.checklistText)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .lineLimit(2)
                } else if isLoadingWeather {
                    Text("Загружаем прогноз...")
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .font(.subheadline)
                } else {
                    Text("Прогноз пока недоступен")
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .font(.subheadline)
                }
            }

            Spacer()

            Button {
                Task { await loadWeather() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(ZholdasTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(SpringButtonStyle())
            .disabled(isLoadingWeather)
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private var liveLocationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.title3)
                    .foregroundColor(ZholdasTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ZholdasTheme.accent.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("ev_live_location_title".localized)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.textPrimary)

                    Text("ev_live_location_hint".localized)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isSharingLiveLocation },
                    set: { newValue in
                        setLiveLocationSharing(newValue)
                    }
                ))
                .labelsHidden()
                .tint(ZholdasTheme.accent)
            }

            Map(position: $liveMapPosition) {
                Marker(event.locationName, systemImage: "mappin.and.ellipse", coordinate: event.coordinate)
                    .tint(.red)

                ForEach(liveLocations) { location in
                    Annotation(location.fullName, coordinate: location.coordinate) {
                        VStack(spacing: 4) {
                            ZholdasAvatarView(
                                avatarURL: location.avatarURL,
                                initials: getInitials(from: location.fullName),
                                size: 34
                            )
                            .overlay(Circle().stroke(ZholdasTheme.accent, lineWidth: 2))
                            .shadow(color: ZholdasTheme.accent.opacity(0.35), radius: 8)

                            Text(location.userID == authViewModel.currentUserProfile?.id ? "ev_live_location_you".localized : location.fullName)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

            if let error = liveLocationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
            } else if liveLocations.isEmpty {
                Text("ev_live_location_empty".localized)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
            } else {
                Text(String(format: "ev_live_location_count".localized, liveLocations.count))
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func ruleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(ZholdasTheme.accent)
            .frame(width: 26, height: 26)
            .background(Circle().fill(ZholdasTheme.accent.opacity(0.14)))
    }
    
    @ViewBuilder
    private func statCard(title: String, label: String, isStatus: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isStatus ? (event.status == "active" ? .green : ZholdasTheme.textSecondary) : ZholdasTheme.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(ZholdasTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ZholdasTheme.surface.opacity(0.68))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var joinActionButton: some View {
        VStack(spacing: 12) {
            // Chat Button (only visible to creator or joined participants, regardless of active status!)
            if isJoined || isCreator {
                NavigationLink {
                    ChatRoomView(session: sessionBinding)
                        .environmentObject(authViewModel)
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("ev_open_chat_btn".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ZholdasTheme.accent) // Purple/indigo
                    .cornerRadius(12)
                }
                .buttonStyle(SpringButtonStyle())
            }
            
            if (isJoined || isCreator) && event.status == "active" && Date() <= event.endTime {
                arrivalActionButton
                if let arrivalError {
                    Text(arrivalError)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }

            if Date() > event.endTime {
                Button {
                    isShowingRateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "star.leadinghalf.filled")
                        Text("ev_rate_participants".localized)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(SpringButtonStyle())
            } else if isCreator {
                Button {
                    isShowingEditSheet = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Редактировать встречу")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ZholdasTheme.accentGradient)
                    .cornerRadius(12)
                }
                .buttonStyle(SpringButtonStyle())

                // Organizer notification
                HStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                        .foregroundColor(ZholdasTheme.accent)
                    Text("ev_you_are_organizer".localized)
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.accent)
                    Spacer()
                }
                .padding()
                .background(ZholdasTheme.accent.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ZholdasTheme.accent.opacity(0.3), lineWidth: 1)
                )
            } else {
                Button {
                    handleAction()
                } label: {
                    HStack {
                        if isActionLoading {
                            ProgressView().tint(.white).padding(.trailing, 8)
                        }
                        Text(isJoined ? "ev_leave_btn".localized : "ev_join_btn".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isJoined ? Color.red.opacity(0.7) : ZholdasTheme.accent) // Purple/indigo join button
                    .cornerRadius(12)
                }
                .buttonStyle(SpringButtonStyle())
                .disabled(isActionLoading || (!isJoined && participantsCount >= event.maxParticipants))
            }
        }
    }

    private var preparationButton: some View {
        Button {
            isShowingPreparationSheet = true
            if preparationChecklist.isEmpty {
                loadPreparationChecklist()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "backpack.fill")
                Text("ev_prepare_btn".localized)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ZholdasTheme.accentGradient)
            .cornerRadius(12)
        }
        .buttonStyle(SpringButtonStyle())
    }

    private var arrivalActionButton: some View {
        Button {
            markArrived()
        } label: {
            HStack(spacing: 10) {
                if isArrivalLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isArrived ? "checkmark.seal.fill" : "location.fill")
                }
                Text(isArrived ? "Вы на месте" : (isArrivalLoading ? "Проверяем GPS..." : "Я на месте"))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isArrived ? Color.green.opacity(0.75) : ZholdasTheme.accent.opacity(0.9))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke((isArrived ? Color.green : ZholdasTheme.accent).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
        .disabled(isArrived || isArrivalLoading)
    }
    
    // MARK: - Helpers
    
    private func categoryInfo(for category: String) -> (icon: String, title: String) {
        switch category.lowercased() {
        case "hiking", "cat_mountains": return ("mountain.2.fill", "cat_mountains".localized)
        case "walk", "cat_walks": return ("tree.fill", "cat_walks".localized)
        case "sports", "cat_sports": return ("soccerball", "cat_sports".localized)
        case "theater", "cat_theater": return ("theatermasks.fill", "cat_theater".localized)
        case "restaurant", "cat_restaurant": return ("fork.knife", "cat_restaurant".localized)
        case "board_games", "cat_games": return ("dice.fill", "cat_games".localized)
        case "networking", "cat_networking": return ("person.2.wave.2.fill", "cat_networking".localized)
        default: return ("sparkles", "cat_other".localized)
        }
    }
    
    private func mapCategoryToIconAndColor(_ category: String) -> (String, String) {
        switch category.lowercased() {
        case "hiking", "cat_mountains": return ("mountain.2.fill", "#7C5CFF")
        case "walk", "cat_walks": return ("tree.fill", "#7C5CFF")
        case "sports", "cat_sports": return ("soccerball", "#7C5CFF")
        case "theater", "cat_theater": return ("theatermasks.fill", "#7C5CFF")
        case "restaurant", "cat_restaurant": return ("fork.knife", "#7C5CFF")
        case "board_games", "cat_games": return ("dice.fill", "#7C5CFF")
        case "networking", "cat_networking": return ("person.2.wave.2.fill", "#7C5CFF")
        default: return ("sparkles", "#7C5CFF")
        }
    }
    
    private func loadParticipants() async {
        isLoadingParticipants = true
        let list = await eventsViewModel.fetchParticipants(id: event.id)
        await MainActor.run {
            self.participants = list
            if let currentUserID = authViewModel.currentUserProfile?.id,
               let currentParticipant = list.first(where: { $0.id == currentUserID }) {
                self.isArrived = currentParticipant.arrivedAt != nil
            }
            self.isLoadingParticipants = false
        }
    }

    private func loadOrganizer() async {
        if let currentProfile = authViewModel.currentUserProfile, currentProfile.id == event.creatorID {
            await MainActor.run {
                self.organizerProfile = currentProfile
            }
            return
        }

        if let profile = await authViewModel.fetchUserProfile(by: event.creatorID) {
            await MainActor.run {
                self.organizerProfile = profile
            }
        }
    }

    private func setLiveLocationSharing(_ isEnabled: Bool) {
        liveLocationError = nil
        isSharingLiveLocation = isEnabled

        if isEnabled {
            liveLocationManager.requestLocation()
            Task {
                await sendLiveLocationIfPossible()
                await loadLiveLocations()
            }
        } else {
            Task {
                await eventsViewModel.stopLiveLocation(eventID: event.id)
                await loadLiveLocations()
            }
        }
    }

    private func sendLiveLocationIfPossible() async {
        guard isSharingLiveLocation, isLiveLocationAvailable else { return }
        guard let location = liveLocationManager.location else {
            await MainActor.run {
                if let message = liveLocationManager.errorMessage {
                    self.liveLocationError = message
                }
            }
            return
        }

        let success = await eventsViewModel.updateLiveLocation(eventID: event.id, location: location)
        await MainActor.run {
            if success {
                self.liveLocationError = nil
            } else {
                self.liveLocationError = eventsViewModel.errorMessage
                self.isSharingLiveLocation = false
            }
        }
    }

    private func loadLiveLocations() async {
        guard isLiveLocationAvailable else { return }
        let locations = await eventsViewModel.fetchLiveLocations(eventID: event.id)
        await MainActor.run {
            self.liveLocations = locations
            self.updateLiveMapPosition()
        }
    }

    private func updateLiveMapPosition() {
        let coordinates = [event.coordinate] + liveLocations.map { $0.coordinate }
        guard let first = coordinates.first else {
            liveMapPosition = .automatic
            return
        }

        let minLat = coordinates.map(\.latitude).min() ?? first.latitude
        let maxLat = coordinates.map(\.latitude).max() ?? first.latitude
        let minLon = coordinates.map(\.longitude).min() ?? first.longitude
        let maxLon = coordinates.map(\.longitude).max() ?? first.longitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.8),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.8)
        )
        liveMapPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
    
    private func handleAction() {
        guard !isActionLoading else { return }
        isActionLoading = true
        
        Task {
            let success: Bool
            if isJoined {
                success = await eventsViewModel.leaveEvent(id: event.id)
                if success {
                    await MainActor.run {
                        self.isJoined = false
                        self.participantsCount = max(0, self.participantsCount - 1)
                        self.isSharingLiveLocation = false
                    }
                    await eventsViewModel.stopLiveLocation(eventID: event.id)
                    await loadParticipants()
                }
            } else {
                success = await eventsViewModel.joinEvent(id: event.id)
                if success {
                    await MainActor.run {
                        self.isJoined = true
                        self.participantsCount += 1
                    }
                    await loadParticipants()
                }
            }
            
            await MainActor.run {
                self.isActionLoading = false
            }
        }
    }

    private func markArrived() {
        guard !isArrived, !isArrivalLoading else { return }
        isArrivalLoading = true
        arrivalError = nil
        liveLocationManager.requestLocation()

        Task {
            let location = await waitForCurrentLocation()
            guard let location else {
                await MainActor.run {
                    self.arrivalError = liveLocationManager.errorMessage ?? "Не удалось получить GPS. Проверьте доступ к геолокации."
                    self.isArrivalLoading = false
                }
                return
            }

            let success = await eventsViewModel.markArrived(id: event.id, location: location)
            if success {
                await MainActor.run {
                    self.isArrived = true
                    self.arrivalError = nil
                }
                await loadParticipants()
            } else {
                await MainActor.run {
                    self.arrivalError = eventsViewModel.errorMessage
                }
            }
            await MainActor.run {
                self.isArrivalLoading = false
            }
        }
    }

    private func waitForCurrentLocation() async -> CLLocation? {
        if let location = liveLocationManager.location {
            return location
        }

        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let location = await MainActor.run(body: { liveLocationManager.location }) {
                return location
            }
        }

        return nil
    }

    private func loadWeather() async {
        guard shouldShowWeather else { return }
        await MainActor.run {
            self.isLoadingWeather = true
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: "\(event.latitude)"),
            URLQueryItem(name: "longitude", value: "\(event.longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            await MainActor.run { self.isLoadingWeather = false }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let current = decoded.current
            let summary = EventWeatherSummary(
                temperature: current.temperature2m,
                apparentTemperature: current.apparentTemperature,
                precipitation: current.precipitation,
                windSpeed: current.windSpeed10m,
                code: current.weatherCode
            )
            await MainActor.run {
                self.weatherSummary = summary
                self.isLoadingWeather = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingWeather = false
            }
        }
    }

    private func loadPreparationChecklist() {
        guard !isLoadingPreparation else { return }
        isLoadingPreparation = true

        struct AIChatRequest: Codable {
            let message: String
        }

        struct AIChatResponse: Codable {
            let reply: String
        }

        let prompt = """
        Составь чеклист подготовки к событию в Жолдас.
        Название: \(event.title)
        Категория: \(categoryInfo(for: event.category).title) (\(event.category))
        Описание: \(event.description)
        Место: \(event.locationName)
        Дата и время: \(formatDate(event.startTime))
        Участников максимум: \(event.maxParticipants)
        Погода: \(weatherSummary?.checklistText ?? "нет данных")

        Ответь строго разделами: Еда, Одежда, Вещи, Игры и активности, План, Погода, Важно.
        Не используй Markdown-заголовки с ### и не выделяй жирным через **.
        Каждый раздел должен быть адаптирован под категорию, а не универсальным.
        Правила по категориям:
        - Нетворкинг: акцент на знакомство, визитки/LinkedIn/заметки, вопросы для разговора, мини-питчи; еду предлагай только как вода/кофе, без пива, чипсов и пикника.
        - Горы/поход: вода, перекус, обувь, слои одежды, аптечка, power bank, безопасность.
        - Прогулка: удобная обувь, вода, легкий маршрут, фото/разговорные игры.
        - Спорт: форма, обувь, вода, разминка, правила команды.
        - Ресторан/кафе: бронь, бюджет, аллергии, кто оплачивает, игры за столом; не предлагай приносить еду.
        - Игры: настолки/карты/роли, правила, тайминг, ведущий, но еду только легкую по желанию.
        Если есть дождь, ветер, холод или жара, подстрой одежду, воду, обувь и вещи.
        Давай конкретные варианты, коротко и по делу.
        """

        Task {
            do {
                let body = try JSONEncoder().encode(AIChatRequest(message: prompt))
                let response: AIChatResponse = try await APIClient.shared.request(
                    "/ai/chat",
                    method: "POST",
                    body: body,
                    requiresAuth: true
                )
                await MainActor.run {
                    self.preparationChecklist = cleanChecklist(response.reply)
                    self.isLoadingPreparation = false
                }
            } catch {
                await MainActor.run {
                    self.preparationChecklist = fallbackPreparationChecklist()
                    self.isLoadingPreparation = false
                }
            }
        }
    }

    private func fallbackPreparationChecklist() -> String {
        switch event.category.lowercased() {
        case "networking", "cat_networking":
            return """
            Еда
            - Вода или кофе по желанию.
            - Еду лучше не делать главным фокусом встречи.

            Одежда
            - Опрятный casual или smart casual.
            - Удобная обувь, если будет прогулка после знакомства.

            Вещи
            - Заряженный телефон.
            - Короткая заметка о себе: чем занимаешься и кого хочешь найти.
            - QR/ссылка на профиль или контакты.

            Игры и активности
            - Круг 30 секунд: имя, сфера, чем можешь быть полезен.
            - Поиск совпадений: каждый находит 2 общие темы с новым человеком.
            - Мини-пары на 5 минут, потом смена собеседника.

            План
            - Начать с короткого знакомства.
            - Разделиться на пары или мини-группы.
            - В конце обменяться контактами и написать итоги в чат.

            Важно
            - Не превращайте встречу в лекцию одного человека.
            - Дайте каждому сказать пару слов.
            """
        case "restaurant", "cat_restaurant":
            return """
            Еда
            - Проверьте бронь и примерный бюджет.
            - Уточните аллергии и предпочтения участников.

            Одежда
            - Одежда по формату места: casual или smart casual.

            Вещи
            - Заряженный телефон.
            - Деньги/карта и подтверждение брони.

            Игры и активности
            - Легкие вопросы для знакомства.
            - Игра “2 факта и 1 ложь”.

            План
            - Собраться у входа.
            - Дождаться основной группы 10 минут.
            - Обсудить оплату заранее.

            Важно
            - Не приносите свою еду, если это кафе или ресторан.
            """
        default:
            return """
        Еда
        - Вода для каждого участника.
        - Легкий перекус: фрукты, батончики, сэндвичи.

        Одежда
        - Удобная обувь.
        - Одежда по погоде, лучше слоями.
        \(weatherSummary.map { "- По прогнозу: \($0.checklistText)." } ?? "- Проверьте прогноз перед выходом.")

        Вещи
        - Заряженный телефон.
        - Салфетки, пакеты для мусора, небольшой power bank.

        Игры и активности
        - Быстрый круг знакомства.
        - Фото-челлендж по месту встречи.
        - Простая командная игра без реквизита.

        План
        - Собраться за 10-15 минут до начала.
        - Проверить участников в чате.
        - Договориться, кто что приносит.

        Важно
        - Проверьте прогноз перед выходом.
        - Напишите в чат, если опаздываете.
        """
        }
    }

    private func cleanChecklist(_ text: String) -> String {
        text
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "**", with: "")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let lang = langManager.currentLanguage
        formatter.locale = Locale(identifier: lang == "ru" ? "ru_RU" : (lang == "kk" ? "kk_KZ" : "en_US"))
        formatter.dateFormat = "EEEE, d MMMM"
        let dateStr = formatter.string(from: date).capitalized
        
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: date)
        
        return "\(dateStr)\n\(timeStr)"
    }

    private func getInitials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "Z"
    }
}

// MARK: - Participants List View

struct ParticipantsListView: View {
    let participants: [Participant]
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedUserForDetail: SelectedUserForDetail? = nil
    
    var body: some View {
        ZStack {
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            if participants.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.largeTitle)
                        .foregroundColor(ZholdasTheme.textSecondary)
                    Text("ev_participants_empty".localized)
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
            } else {
                List(participants) { participant in
                    Button {
                        selectedUserForDetail = SelectedUserForDetail(id: participant.id)
                    } label: {
                        HStack(spacing: 16) {
                            ZholdasAvatarView(avatarURL: participant.avatarURL, initials: getInitials(from: participant.fullName), size: 44)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(participant.fullName)
                                    .font(.headline)
                                    .foregroundColor(ZholdasTheme.textPrimary)
                                Text("@\(participant.username)")
                                    .font(.subheadline)
                                    .foregroundColor(ZholdasTheme.accent)
                            }
                            Spacer()
                            if participant.arrivedAt != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("На месте")
                                }
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(ZholdasTheme.textSecondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(ZholdasTheme.surface.opacity(0.4))
                    .buttonStyle(PlainButtonStyle())
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("ev_participants".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedUserForDetail) { selectedUser in
            UserDetailView(userID: selectedUser.id)
                .environmentObject(authViewModel)
        }
    }
    
    private func getInitials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "👤"
    }
}

struct PreparationChecklistView: View {
    let eventTitle: String
    let checklist: String
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ZholdasTheme.appBackground.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(ZholdasTheme.accent)
                            .scaleEffect(1.25)
                        Text("ev_prepare_loading".localized)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundColor(ZholdasTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(ZholdasTheme.accent.opacity(0.16)))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ev_prepare_title".localized)
                                        .font(.headline)
                                        .foregroundColor(ZholdasTheme.textPrimary)
                                    Text(eventTitle)
                                        .font(.subheadline)
                                        .foregroundColor(ZholdasTheme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding()
                            .glassBackground(cornerRadius: 8)

                            Text(checklist)
                                .font(.body)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .glassBackground(cornerRadius: 8)
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle("ev_prepare_btn".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundColor(ZholdasTheme.accent)
                }
            }
        }
    }
}

#Preview {
    EventDetailView(
        event: Event(
            id: 1,
            creatorID: "11111111-1111-1111-1111-111111111111",
            title: "Асы үстірті",
            description: "Описание события...",
            category: "hiking",
            locationName: "Райымбек 152",
            latitude: 43.2389,
            longitude: 76.8897,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            maxParticipants: 14,
            status: "active",
            imageURL: nil,
            distanceMeters: 8600,
            participantsCount: 1,
            isJoined: false,
            visibility: "public",
            genderFilter: "all",
            minAge: 18,
            maxAge: 30
        ),
        eventsViewModel: EventsViewModel()
    )
    .environmentObject(AuthViewModel())
}
