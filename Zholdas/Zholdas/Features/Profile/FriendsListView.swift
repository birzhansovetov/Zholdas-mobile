import SwiftUI

struct FriendsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    
    @State private var friends: [User] = []
    @State private var requests: [User] = []
    @State private var selectedTab = 0 // 0: Friends, 1: Requests
    @State private var isLoadingData = false
    @Namespace private var pickerNamespace
    
    var body: some View {
        ZStack {
            // Dark Sleek Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Tab Selection
                pickerView
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
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
        .navigationTitle("friends_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
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
                            .foregroundColor(.white)
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
        }
    }
    
    @ViewBuilder
    private func friendRow(for friend: User) -> some View {
        HStack(spacing: 16) {
            // Avatar
            avatarView(for: friend)
            
            // Text info
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
            
            // Delete Friend Button
            Button {
                Task {
                    let success = await authViewModel.rejectFriendRequest(from: friend.id)
                    if success {
                        withAnimation {
                            friends.removeAll { $0.id == friend.id }
                        }
                    }
                }
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
        }
    }
    
    @ViewBuilder
    private func requestRow(for request: User) -> some View {
        HStack(spacing: 16) {
            // Avatar
            avatarView(for: request)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fullName)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textPrimary)
                
                Text("@\(request.username)")
                    .font(.footnote)
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
            
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
                .frame(width: 50, height: 50)
            
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 50, height: 50)
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            } else {
                Text(getInitials(from: user.fullName))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
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
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(ZholdasTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 60)
        Spacer()
    }
    
    // MARK: - Helpers
    
    private func loadData() async {
        isLoadingData = true
        async let fetchedFriends = authViewModel.fetchFriends()
        async let fetchedRequests = authViewModel.fetchFriendRequests()
        
        let (f, r) = await (fetchedFriends, fetchedRequests)
        self.friends = f
        self.requests = r
        isLoadingData = false
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
