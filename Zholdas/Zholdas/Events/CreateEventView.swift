import SwiftUI
import CoreLocation
import MapKit
import PhotosUI

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var langManager: LocalizationManager
    @StateObject private var eventsViewModel = EventsViewModel()
    @StateObject private var locationManager = LocationManager()
    
    var onCreateSuccess: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var category = "hiking" // По умолчанию
    @State private var locationName = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var maxParticipants = 10
    @State private var startTime = Date().addingTimeInterval(3600) // Через час
    @State private var endTime = Date().addingTimeInterval(7200) // Через два часа
    
    @State private var selectedCoverItem: PhotosPickerItem? = nil
    @State private var imageURL = ""
    @State private var isUploadingCover = false
    
    @State private var visibility = "public"
    @State private var genderFilter = "all"
    @State private var minAge = ""
    @State private var maxAge = ""
    @State private var animateBackground = false
    
    let categories = [
        ("hiking", "cat_mountains", "mountain.2.fill"),
        ("walk", "cat_walks", "tree.fill"),
        ("sports", "cat_sports", "soccerball"),
        ("board_games", "cat_games", "dice.fill"),
        ("networking", "cat_networking", "cup.and.saucer.fill")
    ]
    
    enum Field {
        case title, description, locationName, minAge, maxAge
    }
    @FocusState private var focusedField: Field?
    
    private var defaultCoordinate: CLLocationCoordinate2D {
        guard let location = locationManager.location else {
            return CLLocationCoordinate2D(latitude: 43.2389, longitude: 76.8897)
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        if abs(latitude - 37.33) < 0.5 && abs(longitude - (-122.03)) < 0.5 {
            return CLLocationCoordinate2D(latitude: 43.2389, longitude: 76.8897)
        }
        return location.coordinate
    }

    private var eventDateBinding: Binding<Date> {
        Binding(
            get: { startTime },
            set: { newDate in
                startTime = dateByKeepingTime(from: startTime, on: newDate)
                endTime = dateByKeepingTime(from: endTime, on: newDate)
                if endTime <= startTime {
                    endTime = startTime.addingTimeInterval(3600)
                }
            }
        )
    }

    private func dateByKeepingTime(from time: Date, on date: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute

        return calendar.date(from: merged) ?? date
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Поля ввода формы
                        VStack(alignment: .leading, spacing: 18) {
                            // Обложка события
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_cover".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(height: 140)
                                            .frame(maxWidth: .infinity)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                        
                                        if !imageURL.isEmpty, let url = URL(string: imageURL) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 140)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            } placeholder: {
                                                ProgressView().tint(.white)
                                            }
                                        } else {
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.on.rectangle.angled")
                                                    .font(.title)
                                                    .foregroundColor(ZholdasTheme.accent)
                                                Text("create_ev_select_photo".localized)
                                                    .font(.footnote)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        if isUploadingCover {
                                            Color.black.opacity(0.4)
                                                .cornerRadius(12)
                                            ProgressView()
                                                .tint(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .onChange(of: selectedCoverItem) { newItem in
                                    guard let newItem else { return }
                                    isUploadingCover = true
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                                            do {
                                                let relPath = try await APIClient.shared.upload(
                                                    fileData: data,
                                                    fileName: "cover.jpg",
                                                    mimeType: "image/jpeg",
                                                    to: "/upload"
                                                )
                                                await MainActor.run {
                                                    imageURL = AppConfig.backendAbsoluteURL(for: relPath)
                                                    isUploadingCover = false
                                                }
                                            } catch {
                                                print("Failed to upload cover: \(error)")
                                                await MainActor.run {
                                                    isUploadingCover = false
                                                }
                                            }
                                        } else {
                                            isUploadingCover = false
                                        }
                                    }
                                }
                            }

                            // Название
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_title_label".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                TextField("create_ev_title_placeholder".localized, text: $title)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .title)
                                    .modernFieldSurface(isFocused: focusedField == .title)
                                    .animation(.easeOut(duration: 0.2), value: focusedField)
                            }
                            
                            // Категория
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_category".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                Picker("create_ev_category".localized, selection: $category) {
                                    ForEach(categories, id: \.0) { cat in
                                        Label(cat.1.localized, systemImage: cat.2).tag(cat.0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ZholdasTheme.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(ZholdasTheme.border, lineWidth: 1)
                                )
                            }
                            
                            // Описание
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_desc".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                TextEditor(text: $description)
                                    .foregroundColor(.white)
                                    .frame(minHeight: 100)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .scrollContentBackground(.hidden)
                                    .focused($focusedField, equals: .description)
                                    .modernFieldSurface(isFocused: focusedField == .description)
                                    .animation(.easeOut(duration: 0.2), value: focusedField)
                            }
                            
                            // Локация
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_location_label".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                TextField("create_ev_location_placeholder".localized, text: $locationName)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .locationName)
                                    .modernFieldSurface(isFocused: focusedField == .locationName)
                                    .animation(.easeOut(duration: 0.2), value: focusedField)
                                
                                Button {
                                    focusedField = nil
                                    showLocationPicker = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "mappin.and.ellipse")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(ZholdasTheme.accent)
                                                .frame(width: 28, height: 28)
                                                .background(ZholdasTheme.accent.opacity(0.14))
                                                .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(selectedCoordinate == nil ? "create_ev_pick_location".localized : "create_ev_location_selected".localized)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                
                                                if let coordinate = selectedCoordinate {
                                                    Text(locationName.isEmpty ? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude) : locationName)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .lineLimit(1)
                                                } else {
                                                    Text("create_ev_pick_location_hint".localized)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        if let coordinate = selectedCoordinate {
                                            selectedLocationCard(coordinate: coordinate)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedCoordinate == nil ? Color.white.opacity(0.1) : ZholdasTheme.accent.opacity(0.55), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Максимум участников
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_participants_label".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                Stepper("\(maxParticipants) " + "create_ev_people_count".localized, value: $maxParticipants, in: 2...100)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            
                            // Временной интервал
                            VStack(alignment: .leading, spacing: 16) {
                                Text("create_ev_date".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)

                                DatePicker(
                                    "create_ev_date".localized,
                                    selection: eventDateBinding,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(ZholdasTheme.accent)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(ZholdasTheme.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(ZholdasTheme.border, lineWidth: 1)
                                )

                                VStack(spacing: 12) {
                                    timePickerCard(
                                        title: "create_ev_start".localized,
                                        selection: $startTime,
                                        range: Date()...
                                    )

                                    timePickerCard(
                                        title: "create_ev_end".localized,
                                        selection: $endTime,
                                        range: startTime...
                                    )
                                }
                            }
                            .modernCard()
                            .onChange(of: startTime) { newValue in
                                if endTime <= newValue {
                                    endTime = newValue.addingTimeInterval(3600)
                                }
                            }
                            
                            // КТО МОЖЕТ ВИДЕТЬ ИВЕНТ
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_ev_visibility_header".localized)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                    HStack(spacing: 12) {
                                        Button {
                                            visibility = "public"
                                        } label: {
                                            HStack {
                                                optionIcon(systemName: "globe.europe.africa.fill", isSelected: visibility == "public")
                                                Text("create_ev_visibility_all".localized)
                                                    .font(.footnote)
                                                    .fontWeight(.bold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(visibility == "public" ? ZholdasTheme.accent.opacity(0.2) : Color.white.opacity(0.04))
                                            .foregroundColor(visibility == "public" ? .white : .gray)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(visibility == "public" ? ZholdasTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            visibility = "friends"
                                        } label: {
                                            HStack {
                                                optionIcon(systemName: "person.2.fill", isSelected: visibility == "friends")
                                                Text("create_ev_visibility_friends".localized)
                                                    .font(.footnote)
                                                    .fontWeight(.bold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(visibility == "friends" ? ZholdasTheme.accent.opacity(0.2) : Color.white.opacity(0.04))
                                            .foregroundColor(visibility == "friends" ? .white : .gray)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(visibility == "friends" ? ZholdasTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                            }
                            
                            // АУДИТОРИЯ
                            VStack(alignment: .leading, spacing: 12) {
                                Text("create_ev_audience_header".localized)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1.0)
                                
                                Text("create_ev_gender_label".localized)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 8) {
                                    genderFilterButton(title: "create_ev_gender_all".localized, assetName: "gender_other", value: "all")
                                    genderFilterButton(title: "create_ev_gender_men".localized, assetName: "gender_male", value: "men")
                                    genderFilterButton(title: "create_ev_gender_women".localized, assetName: "gender_female", value: "women")
                                }
                                
                                Text("create_ev_age_range_label".localized)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                                
                                HStack(spacing: 12) {
                                    TextField("create_ev_age_from".localized, text: $minAge)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .focused($focusedField, equals: .minAge)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focusedField == .minAge ? ZholdasTheme.accent : Color.white.opacity(0.1), lineWidth: 1))
                                        .foregroundColor(.white)
                                        .animation(.easeOut(duration: 0.2), value: focusedField)
                                    
                                    Text("—")
                                        .foregroundColor(.gray)
                                    
                                    TextField("create_ev_age_to".localized, text: $maxAge)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .focused($focusedField, equals: .maxAge)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focusedField == .maxAge ? ZholdasTheme.accent : Color.white.opacity(0.1), lineWidth: 1))
                                        .foregroundColor(.white)
                                        .animation(.easeOut(duration: 0.2), value: focusedField)
                                    
                                    Text("create_ev_years".localized)
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Вывод ошибки
                        if let error = eventsViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Кнопка создания
                        Button {
                            createEvent()
                        } label: {
                            HStack {
                                if eventsViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("create_ev_btn".localized)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .primaryActionSurface()
                        }
                        .disabled(title.isEmpty || description.isEmpty || locationName.isEmpty || selectedCoordinate == nil || eventsViewModel.isLoading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("create_ev_nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("create_ev_cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ZholdasTheme.accent)
                }
            }
            .task {
                locationManager.requestLocation()
            }
            .sheet(isPresented: $showLocationPicker) {
                EventLocationPickerView(
                    initialCoordinate: selectedCoordinate ?? defaultCoordinate,
                    selectedCoordinate: $selectedCoordinate,
                    locationName: $locationName
                )
                .presentationDetents([.large])
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animateBackground = true
                }
            }
        }
    }
    
    private func createEvent() {
        guard let coordinate = selectedCoordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        let minAgeVal = Int32(minAge)
        let maxAgeVal = Int32(maxAge)
        
        Task {
            let success = await eventsViewModel.createEvent(
                title: title,
                description: description,
                category: category,
                locationName: locationName,
                latitude: latitude,
                longitude: longitude,
                startTime: startTime,
                endTime: endTime,
                maxParticipants: Int32(maxParticipants),
                imageURL: imageURL.isEmpty ? nil : imageURL,
                visibility: visibility,
                genderFilter: genderFilter,
                minAge: minAgeVal,
                maxAge: maxAgeVal
            )
            if success {
                onCreateSuccess()
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private func selectedLocationCard(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            selectedLocationPreview(coordinate: coordinate)
                .frame(height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption.weight(.bold))
                    .foregroundColor(ZholdasTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName.isEmpty ? "create_ev_selected_point_name".localized : locationName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.black.opacity(0.18))
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func selectedLocationPreview(coordinate: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))) {
            Annotation("create_ev_location_selected".localized, coordinate: coordinate) {
                ZStack {
                    Circle()
                        .fill(ZholdasTheme.accent.opacity(0.22))
                        .frame(width: 48, height: 48)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(ZholdasTheme.accent)
                        .shadow(color: .black.opacity(0.35), radius: 6)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func timePickerCard(title: String, selection: Binding<Date>, range: PartialRangeFrom<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textSecondary)

            DatePicker(
                title,
                selection: selection,
                in: range,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .tint(ZholdasTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 112)
            .clipped()
        }
        .padding(12)
        .background(ZholdasTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func optionIcon(systemName: String, isSelected: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isSelected ? ZholdasTheme.accent : .gray)
            .frame(width: 24, height: 24)
    }
    
    @ViewBuilder
    private func genderSticker(assetName: String, isSelected: Bool) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? ZholdasTheme.accent : Color.white.opacity(0.12), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func genderFilterButton(title: String, assetName: String, value: String) -> some View {
        Button {
            genderFilter = value
        } label: {
            HStack(spacing: 4) {
                genderSticker(assetName: assetName, isSelected: genderFilter == value)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(genderFilter == value ? ZholdasTheme.accent.opacity(0.2) : Color.white.opacity(0.04))
            .foregroundColor(genderFilter == value ? .white : .gray)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(genderFilter == value ? ZholdasTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EventLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let initialCoordinate: CLLocationCoordinate2D
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var draftCoordinate: CLLocationCoordinate2D
    @State private var draftLocationName: String
    @State private var isResolvingLocation = false
    @State private var position: MapCameraPosition
    private let geocoder = CLGeocoder()
    
    init(
        initialCoordinate: CLLocationCoordinate2D,
        selectedCoordinate: Binding<CLLocationCoordinate2D?>,
        locationName: Binding<String>
    ) {
        self.initialCoordinate = initialCoordinate
        self._selectedCoordinate = selectedCoordinate
        self._locationName = locationName
        let current = selectedCoordinate.wrappedValue ?? initialCoordinate
        self._draftCoordinate = State(initialValue: current)
        self._draftLocationName = State(initialValue: locationName.wrappedValue)
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: current,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $position) {
                        Annotation("create_ev_location_selected".localized, coordinate: draftCoordinate) {
                            ZStack {
                                Circle()
                                    .fill(ZholdasTheme.accent.opacity(0.22))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(ZholdasTheme.accent)
                                    .shadow(color: .black.opacity(0.35), radius: 6)
                            }
                        }
                    }
                    .ignoresSafeArea()
	                    .onTapGesture(coordinateSpace: .local) { point in
	                        if let coordinate = proxy.convert(point, from: .local) {
	                            draftCoordinate = coordinate
                                resolveLocationName(for: coordinate)
	                        }
	                    }
                }
                
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3)
                                .foregroundColor(ZholdasTheme.accent)
                                .frame(width: 36, height: 36)
                                .background(ZholdasTheme.accent.opacity(0.14))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("create_ev_pick_location".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("create_ev_map_tap_hint".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: isResolvingLocation ? "location.magnifyingglass" : "scope")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ZholdasTheme.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(draftLocationName.isEmpty ? "create_ev_selected_point_name".localized : draftLocationName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(String(format: "%.5f, %.5f", draftCoordinate.latitude, draftCoordinate.longitude))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(ZholdasTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        Button {
                            selectedCoordinate = draftCoordinate
                            locationName = draftLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "create_ev_selected_point_name".localized
                                : draftLocationName
                            dismiss()
                        } label: {
                            Text("create_ev_confirm_location".localized)
                                .font(.headline)
                                .fontWeight(.bold)
                                .primaryActionSurface()
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                    .modernCard()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding()
                }
            }
            .navigationTitle("create_ev_pick_location".localized)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if draftLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resolveLocationName(for: draftCoordinate)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("create_ev_cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ZholdasTheme.accent)
                }
            }
        }
    }

    private func resolveLocationName(for coordinate: CLLocationCoordinate2D) {
        isResolvingLocation = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ru_KZ")) { placemarks, _ in
            Task { @MainActor in
                isResolvingLocation = false
                guard let placemark = placemarks?.first else { return }
                let parts = [
                    placemark.name,
                    placemark.thoroughfare,
                    placemark.subLocality,
                    placemark.locality
                ]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                if let first = parts.first {
                    draftLocationName = first
                }
            }
        }
    }
}

#Preview {
    CreateEventView {}
        .environmentObject(LocalizationManager.shared)
}
