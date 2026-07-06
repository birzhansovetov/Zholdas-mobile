import SwiftUI

struct EditEventView: View {
    let event: Event
    @ObservedObject var eventsViewModel: EventsViewModel
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var category: String
    @State private var locationName: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var maxParticipants: Int
    @State private var visibility: String
    @State private var genderFilter: String
    @State private var minAge: Int
    @State private var maxAge: Int
    @State private var errorText: String?
    @State private var isSaving = false

    private let categories = ["cat_mountains", "cat_walks", "cat_sports", "cat_theater", "cat_restaurant", "cat_games", "cat_networking", "cat_other"]
    private let genderOptions = [("all", "Все"), ("men", "Мужчины"), ("women", "Женщины")]

    init(event: Event, eventsViewModel: EventsViewModel, onSaved: (() -> Void)? = nil) {
        self.event = event
        self.eventsViewModel = eventsViewModel
        self.onSaved = onSaved

        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _category = State(initialValue: event.category)
        _locationName = State(initialValue: event.locationName)
        _latitude = State(initialValue: String(format: "%.6f", event.latitude))
        _longitude = State(initialValue: String(format: "%.6f", event.longitude))
        _startTime = State(initialValue: event.startTime)
        _endTime = State(initialValue: event.endTime)
        _maxParticipants = State(initialValue: Int(event.maxParticipants))
        _visibility = State(initialValue: event.visibility ?? "public")
        _genderFilter = State(initialValue: event.genderFilter ?? "all")
        _minAge = State(initialValue: Int(event.minAge ?? 0))
        _maxAge = State(initialValue: Int(event.maxAge ?? 0))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZholdasTheme.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        inputField("Название", text: $title, placeholder: "Например: Поход на Кок-Жайляу")

                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("Описание")
                            TextEditor(text: $description)
                                .frame(minHeight: 110)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(ZholdasTheme.surface)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(ZholdasTheme.border, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("Категория")
                            Picker("Категория", selection: $category) {
                                ForEach(categories, id: \.self) { item in
                                    Text(item.localized).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(ZholdasTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(ZholdasTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        inputField("Место встречи", text: $locationName, placeholder: "Название места")

                        HStack(spacing: 12) {
                            inputField("Широта", text: $latitude, placeholder: "43.238900")
                                .keyboardType(.decimalPad)
                            inputField("Долгота", text: $longitude, placeholder: "76.889700")
                                .keyboardType(.decimalPad)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Дата и время")
                            DatePicker("Начало", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                            DatePicker("Окончание", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                        }
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .padding(14)
                        .background(ZholdasTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Stepper(value: $maxParticipants, in: 1...200) {
                            HStack {
                                Text("Лимит участников")
                                    .foregroundColor(ZholdasTheme.textPrimary)
                                Spacer()
                                Text("\(maxParticipants)")
                                    .fontWeight(.bold)
                                    .foregroundColor(ZholdasTheme.accent)
                            }
                        }
                        .tint(ZholdasTheme.accent)
                        .padding(14)
                        .background(ZholdasTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("Ограничения")
                            HStack(spacing: 8) {
                                ForEach(genderOptions, id: \.0) { value, title in
                                    Button {
                                        genderFilter = value
                                    } label: {
                                        Text(title)
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(genderFilter == value ? .white : ZholdasTheme.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(genderFilter == value ? ZholdasTheme.accent : ZholdasTheme.panel)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Stepper(value: $minAge, in: 0...80) {
                                Text("Возраст от: \(minAge == 0 ? "без лимита" : "\(minAge)")")
                                    .foregroundColor(ZholdasTheme.textPrimary)
                            }
                            Stepper(value: $maxAge, in: 0...80) {
                                Text("Возраст до: \(maxAge == 0 ? "без лимита" : "\(maxAge)")")
                                    .foregroundColor(ZholdasTheme.textPrimary)
                            }
                        }
                        .padding(14)
                        .background(ZholdasTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            save()
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                }
                                Text("Сохранить изменения")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ZholdasTheme.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(ZholdasTheme.accent)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(ZholdasTheme.textSecondary)
            .tracking(1.1)
    }

    private func inputField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            TextField(placeholder, text: text)
                .padding(14)
                .background(ZholdasTheme.surface)
                .foregroundColor(ZholdasTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ZholdasTheme.border, lineWidth: 1)
                )
        }
    }

    private func save() {
        errorText = nil

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Введите название"
            return
        }

        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Введите описание"
            return
        }

        guard !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Введите место встречи"
            return
        }

        guard let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")),
              let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")) else {
            errorText = "Проверьте координаты"
            return
        }

        guard endTime > startTime else {
            errorText = "Окончание должно быть позже начала"
            return
        }

        isSaving = true
        Task {
            let success = await eventsViewModel.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: lat,
                longitude: lon,
                startTime: startTime,
                endTime: endTime,
                maxParticipants: Int32(maxParticipants),
                imageURL: event.imageURL,
                visibility: visibility,
                genderFilter: genderFilter,
                minAge: minAge > 0 ? Int32(minAge) : nil,
                maxAge: maxAge > 0 ? Int32(maxAge) : nil
            )
            isSaving = false

            if success {
                onSaved?()
                dismiss()
            } else {
                errorText = eventsViewModel.errorMessage ?? "Не удалось сохранить событие"
            }
        }
    }
}
