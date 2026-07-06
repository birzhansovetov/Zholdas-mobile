import SwiftUI

private struct ActivitySelectedUser: Identifiable {
    let id: String
}

struct ActivityView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    
    @State private var selectedTab: String = "act_tab_all" // "act_tab_all" или "act_tab_friends"
    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = false
    @State private var errorString: String? = nil
    @State private var selectedUserForDetail: ActivitySelectedUser? = nil
    @State private var pendingFriendActionUserID: String? = nil
    
    var filteredNotifications: [NotificationItem] {
        if selectedTab == "act_tab_friends" {
            return []
        }
        return notifications
    }
    
    var body: some View {
        ZStack {
            // Sleek Dark Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("tab_activity".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.textPrimary)
                    
                    Text("act_all_community".localized)
                        .font(.subheadline)
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Custom Capsule/Pill Selector
                HStack {
                    Spacer()
                    customSelector
                        .padding(.top, 16)
                    Spacer()
                }
                
                if isLoading && notifications.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(ZholdasTheme.accent)
                            .scaleEffect(1.2)
                        Spacer()
                    }
                    Spacer()
                } else if filteredNotifications.isEmpty {
                    Spacer()
                    // Centered Empty State Box
                    emptyStateCard
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    // Notifications List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredNotifications) { item in
                                notificationRow(for: item)
                            }
                        }
                        .padding(24)
                    }
                    .refreshable {
                        await loadNotifications()
                    }
                }
            }
        }
        .task {
            await loadNotifications()
            await markAllAsRead()
        }
        .sheet(item: $selectedUserForDetail) { selectedUser in
            UserDetailView(userID: selectedUser.id)
                .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var customSelector: some View {
        HStack(spacing: 4) {
            ForEach(["act_tab_all", "act_tab_friends"], id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedTab == tab ? ZholdasTheme.accent : ZholdasTheme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? ZholdasTheme.accent.opacity(0.14) : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(ZholdasTheme.surface.opacity(0.72))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func notificationRow(for item: NotificationItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if let actorID = item.actorID, !actorID.isEmpty {
                    selectedUserForDetail = ActivitySelectedUser(id: actorID)
                }
            } label: {
                HStack(spacing: 16) {
                    // Actor Avatar or Icon
                    ZStack {
                        Circle()
                            .fill(ZholdasTheme.accent.opacity(0.12))
                            .frame(width: 46, height: 46)
                        
                        if !item.actorAvatarURL.isEmpty, let url = URL(string: item.actorAvatarURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                                    .frame(width: 46, height: 46)
                            } placeholder: {
                                ProgressView()
                                    .tint(ZholdasTheme.accent)
                            }
                        } else {
                            let initials = getInitials(from: item.actorName)
                            Text(initials)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ZholdasTheme.textPrimary)
                        }
                        
                        // Little type icon in corner
                        let (icon, color) = getIconAndColor(for: item.notificationType)
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 18, height: 18)
                            
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 14, y: 14)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(item.text)
                                .font(.subheadline)
                                .foregroundColor(ZholdasTheme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            if !item.isRead {
                                Circle()
                                    .fill(ZholdasTheme.accent)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Text(formatDate(item.createdAt))
                            .font(.caption2)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if item.notificationType == "friend_request", let actorID = item.actorID, !actorID.isEmpty {
                HStack(spacing: 10) {
                    friendRequestActionButton(title: "Принять", color: ZholdasTheme.accent, isPrimary: true) {
                        await handleFriendRequest(item: item, accept: true)
                    }
                    friendRequestActionButton(title: "Отклонить", color: ZholdasTheme.surface, isPrimary: false) {
                        await handleFriendRequest(item: item, accept: false)
                    }
                }
                .disabled(pendingFriendActionUserID == actorID)
            }
        }
        .padding()
        .background(item.isRead ? ZholdasTheme.surface.opacity(0.62) : ZholdasTheme.elevatedSurface.opacity(0.78))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.isRead ? ZholdasTheme.border : ZholdasTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func friendRequestActionButton(title: String, color: Color, isPrimary: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(isPrimary ? .white : ZholdasTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(color)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(ZholdasTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var emptyStateCard: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.15, blue: 0.32), Color(red: 0.12, green: 0.10, blue: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.35, green: 0.30, blue: 0.60).opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(Color(red: 0.60, green: 0.55, blue: 0.95))
            }
            
            VStack(spacing: 8) {
                Text(selectedTab == "act_tab_friends" ? "act_no_friends".localized : "act_no_notifications".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textPrimary)
                
                Text(selectedTab == "act_tab_friends" ? "act_no_friends_hint".localized : "act_no_notifications_hint".localized)
                    .font(.subheadline)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(ZholdasTheme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Logic
    
    private func loadNotifications() async {
        isLoading = true
        errorString = nil
        do {
            let response: [NotificationItem] = try await APIClient.shared.request(
                "/notifications",
                method: "GET",
                requiresAuth: true
            )
            notifications = response
        } catch {
            errorString = error.localizedDescription
        }
        isLoading = false
    }
    
    private func markAllAsRead() async {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                "/notifications/read",
                method: "POST",
                requiresAuth: true
            )
            
            await MainActor.run {
                authViewModel.unreadNotificationsCount = 0
            }
        } catch {
            print("Failed to mark notifications as read: \(error)")
        }
    }

    private func handleFriendRequest(item: NotificationItem, accept: Bool) async {
        guard let actorID = item.actorID, !actorID.isEmpty else { return }
        await MainActor.run {
            pendingFriendActionUserID = actorID
        }
        let success = accept
            ? await authViewModel.acceptFriendRequest(from: actorID)
            : await authViewModel.rejectFriendRequest(from: actorID)
        await MainActor.run {
            pendingFriendActionUserID = nil
            if success {
                notifications.removeAll { $0.id == item.id }
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
    
    private func getIconAndColor(for type: String) -> (String, Color) {
        switch type {
        case "join":
            return ("person.fill.badge.plus", .green)
        case "leave":
            return ("person.fill.badge.minus", .red)
        case "announcement":
            return ("megaphone.fill", ZholdasTheme.accent) // Indigo
        case "ban":
            return ("hand.raised.fill", .red)
        case "friend_request":
            return ("person.crop.circle.badge.plus", ZholdasTheme.accent)
        default:
            return ("bell.fill", ZholdasTheme.accent)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
}
