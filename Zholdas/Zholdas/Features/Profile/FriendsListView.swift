import SwiftUI

struct UserSearchResult: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let fullName: String
    let avatarURL: String?
    let city: String?
    var friendshipStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case city
        case friendshipStatus = "friendship_status"
    }
}

private struct FriendDetailSheetItem: Identifiable {
    let id: String
}

struct FriendsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    
    @State private var friends: [User] = []
    @State private var requests: [User] = []
    @State private var selectedTab = 0 // 0: Friends, 1: Requests
    @State private var isLoadingData = false
    @State private var selectedProfileForSheet: FriendDetailSheetItem? = nil
    @State private var friendToRemove: User? = nil
    @State private var isShowingDeleteConfirmation = false
    @State private var errorMessage: String? = nil
    @State private var isShowingErrorAlert = false
    @Namespace private var pickerNamespace
    
    // Search state
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    private var isSearchActive: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    var body: some View {
        ZStack {
            // Dark Sleek Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Search Bar at the top
                searchBarView
                    .padding(.top, 10)
                
                if isSearchActive {
                    // Search Content
                    if isSearching && searchResults.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(ZholdasTheme.accent)
                            .scaleEffect(1.3)
                        Spacer()
                    } else if let error = searchError, !error.isEmpty {
                        VStack(spacing: 8) {
                            Text("⚠️ \(error)")
                                .font(.subheadline)
                                .foregroundColor(ZholdasTheme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        Spacer()
                    } else if searchResults.isEmpty {
                        emptyStateView(
                            systemImage: "magnifyingglass",
                            title: "friends_search_empty".localized,
                            subtitle: ""
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { result in
                                    searchResultRow(for: result)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                    }
                } else {
                    // Tab Selection
                    pickerView
                        .padding(.horizontal, 20)
                    
                    if isLoadingData {
                        Spacer()
                        ProgressView()
                            .tint(ZholdasTheme.accent)
                            .scaleEffect(1.3)
                        Text("prof_loading".localized)
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .font(.subheadline)
                        Spacer()
                    } else {
                        if selectedTab == 0 {
                            friendsList
                        } else {
                            requestsList
                        }
                    }
                }
            }
        }
        .navigationTitle("friends_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            if !isSearchActive {
                await loadData()
            }
        }
        .onChange(of: searchText) { newText in
            searchTask?.cancel()
            let query = newText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.count < 2 {
                searchResults = []
                searchError = nil
                isSearching = false
                return
            }
            isSearching = true
            searchError = nil
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await performSearch(query: query)
            }
        }
        .sheet(item: $selectedProfileForSheet) { item in
            UserDetailView(userID: item.id)
                .environmentObject(authViewModel)
                .environmentObject(langManager)
        }
        .alert("friends_unfriend_confirm_title".localized, isPresented: $isShowingDeleteConfirmation) {
            Button("friends_unfriend_btn".localized, role: .destructive) {
                if let friend = friendToRemove {
                    deleteFriend(friend)
                }
            }
            Button("btn_cancel".localized, role: .cancel) {}
        } message: {
            if let friend = friendToRemove {
                Text(String(format: "friends_unfriend_confirm_message".localized, friend.fullName))
            } else {
                Text("friends_unfriend_confirm_generic".localized)
            }
        }
        .alert("alert_error_title".localized, isPresented: $isShowingErrorAlert) {
            Button("btn_ok".localized, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "error_generic".localized)
        }
    }
    
    // MARK: - Search Bar View
    
    @ViewBuilder
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ZholdasTheme.textSecondary)
            TextField("friends_search_placeholder".localized, text: $searchText)
                .foregroundColor(ZholdasTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchTask?.cancel()
                    searchResults = []
                    searchError = nil
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ZholdasTheme.surface.opacity(0.76))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Search Result Row
    
    @ViewBuilder
    private func searchResultRow(for result: UserSearchResult) -> some View {
        HStack(spacing: 14) {
            Button {
                selectedProfileForSheet = FriendDetailSheetItem(id: result.id)
            } label: {
                HStack(spacing: 14) {
                    userAvatarView(avatarURL: result.avatarURL, fullName: result.fullName, username: result.username)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.fullName)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                            .lineLimit(1)

                        Text("@\(result.username)")
                            .font(.footnote)
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Action button or status on right
            searchResultActionView(for: result)
        }
        .padding()
        .background(ZholdasTheme.surface.opacity(0.76))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func searchResultActionView(for result: UserSearchResult) -> some View {
        switch result.friendshipStatus {
        case "none":
            Button {
                Task {
                    let success = await authViewModel.sendFriendRequest(to: result.id)
                    if success {
                        await MainActor.run {
                            if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                                searchResults[idx].friendshipStatus = "pending_sent"
                            }
                        }
                    }
                }
            } label: {
                Text("friends_add".localized)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        case "pending_sent":
            Text("friends_request_sent".localized)
                .font(.caption.weight(.medium))
                .foregroundColor(ZholdasTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        case "pending_received":
            Button {
                Task {
                    let success = await authViewModel.acceptFriendRequest(from: result.id)
                    if success {
                        await MainActor.run {
                            if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                                searchResults[idx].friendshipStatus = "accepted"
                            }
                        }
                    }
                }
            } label: {
                Text("user_detail_accept".localized)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        case "accepted":
            Text("friends_already".localized)
                .font(.caption.weight(.medium))
                .foregroundColor(ZholdasTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Picker View
    
    private var pickerView: some View {
        HStack(spacing: 0) {
            ForEach(0...1, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = index
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(index == 0 ? "friends_my_friends".localized : "friends_requests".localized)
                            .fontWeight(.bold)
                        
                        let count = index == 0 ? friends.count : requests.count
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(index == 1 && count > 0 ? Color.red : (selectedTab == index ? ZholdasTheme.accentDeep : ZholdasTheme.elevatedSurface))
                            .clipShape(Capsule())
                            .foregroundColor(index == 1 && count > 0 || selectedTab == index ? .white : ZholdasTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .foregroundColor(selectedTab == index ? .white : ZholdasTheme.textSecondary)
                    .background(
                        ZStack {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ZholdasTheme.accent)
                                    .matchedGeometryEffect(id: "activeTabBackground", in: pickerNamespace)
                            }
                        }
                    )
                }
            }
        }
        .padding(4)
        .background(ZholdasTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Friends Tab List
    
    @ViewBuilder
    private var friendsList: some View {
        if friends.isEmpty {
            emptyStateView(
                systemImage: "person.2.slash.fill",
                title: "friends_empty_title".localized,
                subtitle: "friends_empty_subtitle".localized
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(friends) { friend in
                        friendRow(for: friend)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    @ViewBuilder
    private func friendRow(for friend: User) -> some View {
        HStack(spacing: 16) {
            Button {
                selectedProfileForSheet = FriendDetailSheetItem(id: friend.id)
            } label: {
                HStack(spacing: 16) {
                    userAvatarView(avatarURL: friend.avatarURL, fullName: friend.fullName, username: friend.username)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.fullName)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)

                        Text("@\(friend.username)")
                            .font(.footnote)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete Friend Button
            Button {
                friendToRemove = friend
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "person.badge.minus")
                    .foregroundColor(.red.opacity(0.8))
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(ZholdasTheme.surface.opacity(0.76))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Requests Tab List
    
    @ViewBuilder
    private var requestsList: some View {
        if requests.isEmpty {
            emptyStateView(
                systemImage: "bell.slash.fill",
                title: "friends_empty_requests_title".localized,
                subtitle: "friends_empty_requests_subtitle".localized
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(requests) { request in
                        requestRow(for: request)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    @ViewBuilder
    private func requestRow(for request: User) -> some View {
        HStack(spacing: 16) {
            Button {
                selectedProfileForSheet = FriendDetailSheetItem(id: request.id)
            } label: {
                HStack(spacing: 16) {
                    userAvatarView(avatarURL: request.avatarURL, fullName: request.fullName, username: request.username)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.fullName)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)

                        Text("@\(request.username)")
                            .font(.footnote)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Reject Button
                Button {
                    Task {
                        let success = await authViewModel.rejectFriendRequest(from: request.id)
                        if success {
                            withAnimation {
                                requests.removeAll { $0.id == request.id }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .padding(8)
                        .background(ZholdasTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                
                // Accept Button
                Button {
                    Task {
                        let success = await authViewModel.acceptFriendRequest(from: request.id)
                        if success {
                            withAnimation {
                                if let acceptedUser = requests.first(where: { $0.id == request.id }) {
                                    friends.append(acceptedUser)
                                    requests.removeAll { $0.id == request.id }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(ZholdasTheme.surface.opacity(0.76))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Shared Views
    
    @ViewBuilder
    private func userAvatarView(avatarURL: String?, fullName: String, username: String) -> some View {
        if let avatarURL = avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .frame(width: 50, height: 50)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(ZholdasTheme.accent.opacity(0.2))
                        .frame(width: 50, height: 50)
                    ProgressView()
                        .tint(ZholdasTheme.accentDeep)
                }
            }
        } else {
            ZStack {
                Circle()
                    .fill(ZholdasTheme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Text(getInitials(fullName: fullName, username: username))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ZholdasTheme.accentDeep)
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateView(systemImage: String, title: String, subtitle: String) -> some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(ZholdasTheme.accent.opacity(0.7))
            
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textPrimary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 60)
        Spacer()
    }
    
    // MARK: - Helpers

    private func deleteFriend(_ friend: User) {
        Task {
            let success = await authViewModel.rejectFriendRequest(from: friend.id)
            await MainActor.run {
                if success {
                    withAnimation {
                        friends.removeAll { $0.id == friend.id }
                    }
                } else {
                    errorMessage = authViewModel.errorMessage ?? "error_generic".localized
                    isShowingErrorAlert = true
                }
            }
        }
    }
    
    private func loadData() async {
        isLoadingData = true
        async let fetchedFriends = authViewModel.fetchFriends()
        async let fetchedRequests = authViewModel.fetchFriendRequests()
        
        let (f, r) = await (fetchedFriends, fetchedRequests)
        self.friends = f
        self.requests = r
        isLoadingData = false
    }
    
    private func performSearch(query: String) async {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            await MainActor.run {
                searchError = "error_generic".localized
                isSearching = false
            }
            return
        }
        do {
            let results: [UserSearchResult] = try await APIClient.shared.request(
                "/friends/search?q=\(encoded)",
                method: "GET",
                requiresAuth: true
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchResults = results
                searchError = nil
                isSearching = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchError = error.localizedDescription
                searchResults = []
                isSearching = false
            }
        }
    }
    
    private func getInitials(fullName: String, username: String) -> String {
        let parts = fullName.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first, !first.isEmpty {
            let str = String(first)
            return String(str.prefix(min(2, str.count))).uppercased()
        } else if !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        }
        return "👤"
    }
}
