import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName: String = ""
    @State private var bio: String = ""
    @State private var city: String = ""
    @State private var avatarURL: String = ""
    @State private var storedGender: String?
    @State private var storedBirthYear: Int?
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Avatar Preview
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            avatarPreviewSection
                        }
                        .padding(.top, 20)
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    if let relPath = await authViewModel.uploadImage(data: data, fileName: "avatar.jpg") {
                                        await MainActor.run {
                                            avatarURL = AppConfig.backendAbsoluteURL(for: relPath)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Input Fields
                        VStack(spacing: 20) {
                            inputField(title: "edit_prof_name_title".localized, text: $fullName, placeholder: "edit_prof_name_placeholder".localized)
                            
                            cityPickerField
                            
                            bioField
                        }
                        .padding(.horizontal, 24)
                        
                        if let error = authViewModel.errorMessage {
                            Text("⚠️ \(error)")
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        ProgressView("edit_prof_saving".localized)
                            .tint(ZholdasTheme.accent)
                            .foregroundColor(ZholdasTheme.textPrimary)
                            .scaleEffect(1.2)
                            .padding()
                            .background(Color(red: 0.15, green: 0.17, blue: 0.22))
                            .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("edit_prof_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("btn_cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("btn_done".localized) {
                        saveProfile()
                    }
                    .foregroundColor(ZholdasTheme.accent)
                    .fontWeight(.bold)
                    .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let profile = authViewModel.currentUserProfile {
                    let details = parsedProfileDetails(from: profile.bio)
                    fullName = profile.fullName
                    bio = details.bio
                    storedGender = profile.gender ?? details.gender
                    storedBirthYear = profile.birthYear ?? intValue(details.birthYear)
                    city = profile.city ?? "Алматы"
                    avatarURL = profile.avatarURL ?? ""
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var avatarPreviewSection: some View {
        VStack(spacing: 12) {
            ZholdasAvatarView(
                avatarURL: avatarURL.isEmpty ? nil : avatarURL,
                initials: getInitials(from: fullName),
                size: 90
            )
            .shadow(color: ZholdasTheme.accent.opacity(0.24), radius: 14, x: 0, y: 6)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(ZholdasTheme.accent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ZholdasTheme.background, lineWidth: 3))
            }

            Text("edit_prof_change_avatar".localized)
                .font(.caption)
                .foregroundColor(ZholdasTheme.textSecondary)
        }
    }
    
    @ViewBuilder
    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textSecondary)
                .tracking(1.5)
            
            TextField(placeholder, text: text)
                .foregroundColor(ZholdasTheme.textPrimary)
                .modernFieldSurface()
        }
    }
    
    @ViewBuilder
    private var cityPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("edit_prof_city_title".localized)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textSecondary)
                .tracking(1.5)
            
            Menu {
                Button("Алматы") { city = "Алматы" }
                Button("Астана") { city = "Астана" }
                Button("Шымкент") { city = "Шымкент" }
                Button("Караганда") { city = "Караганда" }
            } label: {
                HStack {
                    Text(city.isEmpty ? "edit_prof_city_placeholder".localized : city)
                        .foregroundColor(city.isEmpty ? ZholdasTheme.textTertiary : ZholdasTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .font(.caption)
                }
                .modernFieldSurface()
            }
        }
    }
    
    @ViewBuilder
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("reg_bio_label".localized)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textSecondary)
                .tracking(1.5)
            
            TextField("edit_prof_bio_placeholder".localized, text: $bio, axis: .vertical)
                .lineLimit(4...8)
                .foregroundColor(ZholdasTheme.textPrimary)
                .modernFieldSurface()
        }
    }
    
    // MARK: - Logic
    
    private func saveProfile() {
        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        Task {
            let success = await authViewModel.updateUserProfile(
                fullName: fullName,
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city,
                avatarURL: avatarURL,
                gender: storedGender,
                birthYear: storedBirthYear
            )
            
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
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

    private func parsedProfileDetails(from rawBio: String?) -> (bio: String, gender: String?, birthYear: String?) {
        let rawBio = rawBio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawBio.isEmpty else {
            return ("", nil, nil)
        }

        var cleanedBio = rawBio
        let gender = extractProfileMetadata("gender", from: rawBio)
        let birthYear = extractProfileMetadata("birth_year", from: rawBio)

        if let gender {
            cleanedBio = cleanedBio.replacingOccurrences(of: "[gender:\(gender)]", with: "")
        }

        if let birthYear {
            cleanedBio = cleanedBio.replacingOccurrences(of: "[birth_year:\(birthYear)]", with: "")
        }

        return (cleanedBio.trimmingCharacters(in: .whitespacesAndNewlines), gender, birthYear)
    }

    private func extractProfileMetadata(_ key: String, from text: String) -> String? {
        let prefix = "[\(key):"
        guard let startRange = text.range(of: prefix) else {
            return nil
        }

        let valueStart = startRange.upperBound
        guard let endIndex = text[valueStart...].firstIndex(of: "]") else {
            return nil
        }

        let value = String(text[valueStart..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func intValue(_ rawValue: String?) -> Int? {
        guard let rawValue else {
            return nil
        }
        return Int(rawValue)
    }
}
