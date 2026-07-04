import SwiftUI

struct UserDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    let userID: String
    
    @State private var user: User? = nil
    @State private var friendshipStatus: String = "none" // none, pending_sent, pending_received, accepted
    @State private var isLoading = true
    @State private var actionLoading = false
    @State private var isShowingReportSheet = false
    @State private var reviews: [UserReview] = []
    
    var body: some View {
        ZStack {
            // Sleek Dark Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack {
                // Header handles close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 16)
                            .padding(.trailing, 20)
                    }
                }
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(ZholdasTheme.accent)
                        .scaleEffect(1.5)
                    Text("Загрузка профиля...")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .padding(.top, 8)
                    Spacer()
                } else if let user = user {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Avatar Container
                            avatarView(for: user)
                                .padding(.top, 10)
                            
                            // User Info
                            VStack(spacing: 8) {
                                Text(user.fullName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("@\(user.username)")
                                    .font(.headline)
                                    .foregroundColor(ZholdasTheme.accent)
                                
                                if let city = user.city, !city.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.gray)
                                        Text(city)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            
                            profileMetaSection(for: user)
                                .padding(.horizontal, 24)
                            
                            // Bio Card
                            bioCard(for: user)
                                .padding(.horizontal, 24)
                            
                            // Statistics Card
                            statsCard(for: user)
                                .padding(.horizontal, 24)
                            
                            // User Reviews Section
                            if !reviews.isEmpty {
                                reviewsSection
                                    .padding(.horizontal, 24)
                                    .padding(.top, 8)
                            }
                            
                            Spacer(minLength: 40)
                            
                            // Friendship Status Action Buttons
                            actionButtonsSection
                                .padding(.horizontal, 24)
                            
                            if let currentUserID = authViewModel.currentUserProfile?.id, currentUserID != userID {
                                Button {
                                    isShowingReportSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                        Text("Пожаловаться на пользователя")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.red.opacity(0.8))
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                            } else {
                                Spacer().frame(height: 20)
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("Не удалось загрузить пользователя")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .task {
            await loadUserProfile()
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportView(reportedUserID: userID, eventID: nil, messageID: nil)
                .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func avatarView(for user: User) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.15, blue: 0.45), Color(red: 0.15, green: 0.08, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 100, height: 100)
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            } else {
                Text(getInitials(from: user.fullName))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func profileMetaSection(for user: User) -> some View {
        let details = parsedProfileDetails(from: user.bio)
        let age = formattedAge(user.age) ?? details.age
        let gender = nonEmpty(user.gender) ?? details.gender

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
    private func bioCard(for user: User) -> some View {
        let details = parsedProfileDetails(from: user.bio)

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
    private func statsCard(for user: User) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(user.eventsCount ?? 0)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Ивентов")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            
            VStack(spacing: 4) {
                // Decorate or read from user if back-end supports friend count
                Text("—")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Друзей")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            
            VStack(spacing: 4) {
                let ratingVal = user.rating ?? 5.0
                Text(String(format: "%.1f", ratingVal))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.accent)
                Text("Рейтинг")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        if let currentUserID = authViewModel.currentUserProfile?.id, currentUserID == userID {
            // Viewing self
            HStack {
                Image(systemName: "person.fill")
                Text("Это вы")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(14)
        } else {
            if actionLoading {
                ProgressView()
                    .tint(ZholdasTheme.accent)
                    .frame(height: 50)
            } else {
                switch friendshipStatus {
                case "none":
                    Button {
                        sendRequest()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Добавить в друзья")
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
                        .cornerRadius(14)
                    }
                    
                case "pending_sent":
                    Button {
                        cancelRequest()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.clock")
                            Text("Отменить запрос")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(ZholdasTheme.accent)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(ZholdasTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                case "pending_received":
                    VStack(spacing: 12) {
                        Text("Отправил вам запрос в друзья")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 16) {
                            Button {
                                rejectRequest()
                            } label: {
                                Text("Отклонить")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red)
                                    .cornerRadius(14)
                            }
                            
                            Button {
                                acceptRequest()
                            } label: {
                                Text("Принять")
                                    .fontWeight(.bold)
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
                                    .cornerRadius(14)
                            }
                        }
                    }
                    
                case "accepted":
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(ZholdasTheme.accent)
                            Text("Вы друзья")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Button {
                            unfriend()
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.minus")
                                Text("Удалить из друзей")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(14)
                        }
                    }
                    
                default:
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadUserProfile() async {
        isLoading = true
        async let fetchedUser = authViewModel.fetchUserProfile(by: userID)
        async let fetchedStatus = authViewModel.getFriendshipStatus(with: userID)
        async let fetchedReviews = authViewModel.fetchUserReviews(userID: userID)
        
        let (u, status, r) = await (fetchedUser, fetchedStatus, fetchedReviews)
        self.user = u
        self.friendshipStatus = status
        self.reviews = r
        isLoading = false
    }
    
    private func sendRequest() {
        actionLoading = true
        Task {
            let success = await authViewModel.sendFriendRequest(to: userID)
            if success {
                friendshipStatus = "pending_sent"
            }
            actionLoading = false
        }
    }
    
    private func cancelRequest() {
        actionLoading = true
        Task {
            let success = await authViewModel.rejectFriendRequest(from: userID)
            if success {
                friendshipStatus = "none"
            }
            actionLoading = false
        }
    }
    
    private func acceptRequest() {
        actionLoading = true
        Task {
            let success = await authViewModel.acceptFriendRequest(from: userID)
            if success {
                friendshipStatus = "accepted"
            }
            actionLoading = false
        }
    }
    
    private func rejectRequest() {
        actionLoading = true
        Task {
            let success = await authViewModel.rejectFriendRequest(from: userID)
            if success {
                friendshipStatus = "none"
            }
            actionLoading = false
        }
    }
    
    private func unfriend() {
        actionLoading = true
        Task {
            let success = await authViewModel.rejectFriendRequest(from: userID)
            if success {
                friendshipStatus = "none"
            }
            actionLoading = false
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
    
    // MARK: - Reviews Section
    
    @ViewBuilder
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Отзывы участников")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(reviews.count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
            
            VStack(spacing: 12) {
                ForEach(reviews) { r in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(r.evaluatorName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= r.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundColor(star <= r.rating ? Color(red: 1.0, green: 0.8, blue: 0.0) : .gray)
                                }
                            }
                        }
                        
                        if let comment = r.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(3)
                        }
                        
                        Text(formatReviewDate(r.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    private func formatReviewDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
