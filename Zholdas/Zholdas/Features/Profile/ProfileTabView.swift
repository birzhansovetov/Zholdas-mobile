import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @State private var isShowingEditProfile = false
    @State private var friendsCount = 0
    @State private var pendingRequestsCount = 0
    @State private var isShowingModeratorDashboard = false
    @AppStorage("app_language") private var selectedLanguage = "ru"
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZholdasTheme.appBackground.ignoresSafeArea()
                
                VStack(spacing: 18) {
                    if authViewModel.isLoading && authViewModel.currentUserProfile == nil {
                        Spacer()
                        ProgressView()
                            .tint(ZholdasTheme.accent)
                            .scaleEffect(1.5)
                        Text("prof_loading".localized)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        Spacer()
                    } else if let profile = authViewModel.currentUserProfile {
                        ScrollView {
                            VStack(spacing: 18) {
                                // Avatar Container
                                avatarView(for: profile)
                                    .padding(.top, 12)
                                
                                // User Info
                                VStack(spacing: 8) {
                                    Text(profile.fullName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(ZholdasTheme.textPrimary)
                                    
                                    Text("@\(profile.username)")
                                        .font(.headline)
                                        .foregroundColor(ZholdasTheme.accent)
                                    
                                    if let city = profile.city, !city.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(ZholdasTheme.textSecondary)
                                            Text(city)
                                                .font(.subheadline)
                                                .foregroundColor(ZholdasTheme.textSecondary)
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                
                                profileMetaSection(for: profile)
                                    .padding(.horizontal, 24)

                                emailStatusCard(for: profile)
                                    .padding(.horizontal, 24)

                                // Bio Card
                                bioCard(for: profile)
                                    .padding(.horizontal, 24)
                                
                                // Statistics Cards
                                statsSection(for: profile)
                                    .padding(.horizontal, 24)
                                
                                // Menu & Settings
                                settingsSection
                                    .padding(.horizontal, 24)
                                
                                // Moderator Dashboard Button
                                if isStaffRole(profile.role) {
                                    moderatorDashboardButton
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 8)
                                }

                                // Sign Out Button
                                signOutButton
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 16)
                            }
                        }
                        .scrollIndicators(.hidden)
                        .safeAreaPadding(.bottom, 88)
                    } else {
                        // Fallback/Error state
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(ZholdasTheme.accent)
                        Text(authViewModel.errorMessage ?? "Не удалось загрузить профиль")
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button("btn_retry".localized) {
                                Task {
                                    await authViewModel.fetchUserProfile()
                                }
                            }
                            .foregroundColor(ZholdasTheme.accent)
                            .tint(ZholdasTheme.accent)
                            .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("tab_profile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingEditProfile = true
                    } label: {
                        Text("prof_edit_btn".localized)
                            .foregroundColor(ZholdasTheme.accent)
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $isShowingEditProfile) {
                EditProfileView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $isShowingModeratorDashboard) {
                ModeratorDashboardView()
                    .environmentObject(authViewModel)
            }
            .task {
                if authViewModel.currentUserProfile == nil {
                    await authViewModel.fetchUserProfile()
                }
                await loadFriendsStats()
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func avatarView(for profile: UserProfile) -> some View {
        let initials = getInitials(from: profile.fullName)
        ZholdasAvatarView(avatarURL: profile.avatarURL, initials: initials, size: 88)
            .padding(4)
            .background(Circle().fill(ZholdasTheme.elevatedSurface))
            .overlay(Circle().stroke(ZholdasTheme.accent.opacity(0.48), lineWidth: 2))
            .shadow(color: ZholdasTheme.accent.opacity(0.16), radius: 18, x: 0, y: 8)
    }
    
    @ViewBuilder
    private func emailStatusCard(for profile: UserProfile) -> some View {
        let isConfirmed = profile.emailConfirmed ?? false

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isConfirmed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(isConfirmed ? .green : .yellow)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill((isConfirmed ? Color.green : Color.yellow).opacity(0.14)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isConfirmed ? "Email подтвержден" : "Подтвердите email")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(ZholdasTheme.textPrimary)

                    Text(profile.email)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                }

                Spacer()
            }

            if !isConfirmed {
                Button {
                    Task {
                        await authViewModel.resendEmailConfirmation(email: profile.email)
                    }
                } label: {
                    Text("Отправить письмо еще раз")
                        .font(.caption.weight(.bold))
                        .foregroundColor(ZholdasTheme.accent)
                }
                .disabled(authViewModel.isLoading)
            }

            if let info = authViewModel.infoMessage, !isConfirmed {
                Text(info)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .modernCard()
    }

    @ViewBuilder
    private func profileMetaSection(for profile: UserProfile) -> some View {
        let details = parsedProfileDetails(from: profile.bio)
        let age = formattedAge(profile.age) ?? details.age
        let gender = nonEmpty(profile.gender) ?? details.gender

        if gender != nil || age != nil {
            HStack(spacing: 10) {
                if let age {
                    profileMetaPill(icon: "calendar", title: "prof_age".localized, value: age)
                }

                if let gender {
                    profileMetaPill(icon: "person.fill", title: "prof_gender".localized, value: gender)
                }
            }
        }
    }

    @ViewBuilder
    private func profileMetaPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(ZholdasTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(ZholdasTheme.textTertiary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ZholdasTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func bioCard(for profile: UserProfile) -> some View {
        let details = parsedProfileDetails(from: profile.bio)

        VStack(alignment: .leading, spacing: 8) {
            Text("prof_about_me".localized)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textSecondary)
                .tracking(1.5)

            Text(details.bio)
                .font(.body)
                .foregroundColor(ZholdasTheme.textPrimary.opacity(0.9))
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modernCard()
    }
    
    @ViewBuilder
    private func statsSection(for profile: UserProfile) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(profile.eventsCount ?? 0)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textPrimary)
                Text("prof_events_count".localized)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .modernCard()
            
            NavigationLink {
                FriendsListView()
                    .environmentObject(authViewModel)
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(friendsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        
                        if pendingRequestsCount > 0 {
                            Text("+\(pendingRequestsCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text("prof_friends_count".localized)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .modernCard()
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 4) {
                let ratingVal = authViewModel.currentUserProfile?.rating ?? 5.0
                Text(String(format: "%.1f", ratingVal))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.accent)
                Text("prof_rating_count".localized)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .modernCard(strokeColor: ZholdasTheme.accent.opacity(0.22))
        }
    }
    
    @ViewBuilder
    private var signOutButton: some View {
        Button {
            authViewModel.signOut()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("prof_signout".localized)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ZholdasTheme.danger.opacity(0.12))
            .foregroundColor(ZholdasTheme.danger)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ZholdasTheme.danger.opacity(0.28), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helpers
    
    private func getInitials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "👤"
    }

    private func parsedProfileDetails(from rawBio: String?) -> (bio: String, gender: String?, age: String?) {
        let rawBio = rawBio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawBio.isEmpty else {
            return ("prof_default_bio".localized, nil, nil)
        }

        var cleanedBio = rawBio
        var genderValue: String?
        var ageValue: String?

        if let gender = extractProfileMetadata("gender", from: rawBio) {
            genderValue = gender
            cleanedBio = cleanedBio.replacingOccurrences(of: "[gender:\(gender)]", with: "")
        }

        if let birthYear = extractProfileMetadata("birth_year", from: rawBio) {
            ageValue = ageBadge(from: birthYear)
            cleanedBio = cleanedBio.replacingOccurrences(of: "[birth_year:\(birthYear)]", with: "")
        }

        cleanedBio = cleanedBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedBio.isEmpty {
            cleanedBio = "prof_default_bio".localized
        }

        return (cleanedBio, genderValue, ageValue)
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

    private func ageBadge(from birthYear: String) -> String {
        guard let year = Int(birthYear), year > 1900 else {
            return birthYear
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let age = max(0, currentYear - year)
        return "\(age) \("reg_age_suffix".localized)"
    }

    private func formattedAge(_ age: Int?) -> String? {
        guard let age, age > 0 else {
            return nil
        }
        return "\(age) \("reg_age_suffix".localized)"
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func loadFriendsStats() async {
        let friends = await authViewModel.fetchFriends()
        self.friendsCount = friends.count
        
        let requests = await authViewModel.fetchFriendRequests()
        self.pendingRequestsCount = requests.count
    }
    
    // MARK: - Moderator View
    
    private var moderatorDashboardButton: some View {
        Button {
            isShowingModeratorDashboard = true
        } label: {
            HStack {
                Image(systemName: "shield.fill")
                Text(normalizedRole(authViewModel.currentUserProfile?.role) == "admin" ? "prof_admin_panel".localized : "prof_moderator_panel".localized)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .primaryActionSurface()
        }
    }
    
    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("prof_menu_and_settings".localized)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textSecondary)
                .tracking(1.5)
                .padding(.top, 8)
            
            VStack(spacing: 0) {
                // 1. Language Toggle
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(ZholdasTheme.accent)
                        .frame(width: 24)
                    Text("prof_lang".localized)
                        .foregroundColor(ZholdasTheme.textPrimary)
                    Spacer()
                    Picker("Язык", selection: $selectedLanguage) {
                        Text("Русский").tag("ru")
                        Text("Қазақша").tag("kk")
                        Text("English").tag("en")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .tint(ZholdasTheme.accent)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                
                Divider().background(ZholdasTheme.border)
                
                // 2. Notifications & Activity Link
                NavigationLink {
                    ActivityView()
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(ZholdasTheme.accent)
                            .frame(width: 24)
                        Text("prof_notifications".localized)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        Spacer()
                        if authViewModel.unreadNotificationsCount > 0 {
                            Text("\(authViewModel.unreadNotificationsCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .foregroundColor(.white)
                                .padding(.trailing, 4)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                
                Divider().background(ZholdasTheme.border)
                
                // 3. User Joined & Created Events Link
                NavigationLink {
                    MyEventsListView()
                        .environmentObject(authViewModel)
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(ZholdasTheme.accent)
                            .frame(width: 24)
                        Text("prof_my_events".localized)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                
                Divider().background(ZholdasTheme.border)
                
                // 4. Friends List Link
                NavigationLink {
                    FriendsListView()
                        .environmentObject(authViewModel)
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(ZholdasTheme.accent)
                            .frame(width: 24)
                        Text("prof_friends_list".localized)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        Spacer()
                        if pendingRequestsCount > 0 {
                            Text("+\(pendingRequestsCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .foregroundColor(.white)
                                .padding(.trailing, 4)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
            }
            .glassBackground(cornerRadius: 8)
        }
    }

    private func normalizedRole(_ role: String?) -> String {
        role?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "user"
    }

    private func isStaffRole(_ role: String?) -> Bool {
        let role = normalizedRole(role)
        return role == "moderator" || role == "admin"
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthViewModel())
}
