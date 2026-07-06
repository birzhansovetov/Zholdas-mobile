import SwiftUI

struct ModeratorDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var eventsViewModel = EventsViewModel()
    
    // Tabs: 0 = Модерация, 1 = Статистика, 2 = Юзеры, 3 = Ивенты, 4 = Логи, 5 = Инструменты
    @State private var selectedTab = 0
    
    // Core data lists
    @State private var reports: [Report] = []
    @State private var users: [ModerationUser] = []
    @State private var events: [ModerationEvent] = []
    @State private var auditLogs: [ModerationAuditLog] = []
    @State private var stats: ModerationStats? = nil
    
    // Loading states
    @State private var isLoading = false
    @State private var actionLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var selectedUserID: String? = nil
    @State private var selectedEvent: Event? = nil
    
    // Search queries
    @State private var userSearchQuery = ""
    @State private var eventSearchQuery = ""
    @State private var selectedEventFilter = "all"
    
    // Ban Sheet states
    @State private var isShowingBanSheet = false
    @State private var userToBanID: String? = nil
    @State private var userToBanName: String = ""
    @State private var banReason = ""
    @State private var reportToCloseOnBan: Int32? = nil
    
    // Broadcast states
    @State private var broadcastTitle = ""
    @State private var broadcastText = ""
    
    // System Settings mocks/states
    @State private var aiEnabled = true
    @State private var aiRateLimit = "8"
    @State private var defaultCity = "Almaty"
    
    var isAdmin: Bool {
        normalizedRole(authViewModel.currentUserProfile?.role) == "admin"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header title area
                    adminHeaderView
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    // Horizontal Tab Selector Grid
                    tabSelectorView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    
                    Divider().background(ZholdasTheme.border)
                    
                    // Alert banners
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                    }
                    if let msg = successMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .onAppear {
                                Task {
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    successMessage = nil
                                }
                            }
                    }
                    
                    // Tab content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch selectedTab {
                            case 0:
                                reportsTabContent
                            case 1:
                                statsTabContent
                            case 2:
                                usersTabContent
                            case 3:
                                eventsTabContent
                            case 4:
                                auditLogsTabContent
                            case 5:
                                toolsTabContent
                            default:
                                EmptyView()
                            }
                        }
                        .padding(20)
                    }
                    .refreshable {
                        await loadDataForCurrentTab()
                    }
                }
            }
            .navigationTitle("mod_nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("btn_close".localized) {
                        dismiss()
                    }
                    .foregroundColor(ZholdasTheme.textSecondary)
                }
            }
            .task {
                await loadDataForCurrentTab()
            }
            .sheet(isPresented: $isShowingBanSheet) {
                banReasonInputSheet
            }
            .sheet(isPresented: Binding(
                get: { selectedUserID != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedUserID = nil
                    }
                }
            )) {
                if let selectedUserID {
                    UserDetailView(userID: selectedUserID)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, eventsViewModel: eventsViewModel)
            }
        }
    }
    
    // MARK: - Header & Tab Views
    
    private var adminHeaderView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isAdmin ? "mod_role_admin".localized : "mod_role_moderator".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(isAdmin ? "mod_announcement".localized : "mod_moderation".localized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ZholdasTheme.accent.opacity(0.15))
                    .foregroundColor(ZholdasTheme.accent)
                    .cornerRadius(6)
            }
            
            Text("mod_subtitle".localized)
                .font(.caption)
                .foregroundColor(ZholdasTheme.textSecondary)
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }
    
    private var tabSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                tabButton(title: "mod_tab_moderation".localized, icon: "exclamationmark.bubble.fill", index: 0)
                
                if isAdmin {
                    tabButton(title: "mod_tab_stats".localized, icon: "chart.bar.xaxis", index: 1)
                    tabButton(title: "mod_tab_users".localized, icon: "person.3.fill", index: 2)
                    tabButton(title: "mod_tab_events".localized, icon: "calendar", index: 3)
                    tabButton(title: "mod_tab_audit".localized, icon: "list.bullet.clipboard.fill", index: 4)
                    tabButton(title: "mod_tab_tools".localized, icon: "slider.horizontal.3", index: 5)
                }
            }
        }
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                selectedTab = index
                errorMessage = nil
            }
            Task {
                await loadDataForCurrentTab()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selectedTab == index ? ZholdasTheme.accent : ZholdasTheme.surface.opacity(0.72))
            .foregroundColor(selectedTab == index ? .white : ZholdasTheme.textSecondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedTab == index ? Color.clear : ZholdasTheme.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Tab Contents
    
    // 0. Reports Tab
    @ViewBuilder
    private var reportsTabContent: some View {
        if isLoading {
            ProgressView().tint(ZholdasTheme.accent).padding(.top, 40)
        } else if reports.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "shield.checkmark.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text("mod_reports_empty_title".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("mod_reports_empty_desc".localized)
                    .font(.subheadline)
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
            .padding(.top, 40)
        } else {
            VStack(spacing: 12) {
                ForEach(reports) { report in
                    reportCard(for: report)
                }
            }
        }
    }
    
    @ViewBuilder
    private func reportCard(for report: Report) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(report.reason.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                
                Spacer()
                
                Text(formatDate(report.createdAt))
                    .font(.caption2)
                    .foregroundColor(ZholdasTheme.textSecondary)
            }
            
            if !report.description.isEmpty {
                Text(report.description)
                    .font(.subheadline)
                    .foregroundColor(ZholdasTheme.textPrimary)
            }
            
            Divider().background(ZholdasTheme.border)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("mod_reporter_label".localized)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                    Text(report.reporterName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.textPrimary)
                }
                
                if let target = report.reportedUserName {
                    HStack {
                        Text("mod_reported_label".localized)
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.textSecondary)
                        Text(target)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.accent)
                    }
                }
                
                if let evTitle = report.eventTitle {
                    HStack {
                        Text("mod_event_label".localized)
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.textSecondary)
                        Text(evTitle)
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.textPrimary)
                    }
                }
                
                if let msg = report.messageText {
                    Text("\("tab_chats".localized.prefix(4)): \"\(msg)\"")
                        .font(.caption)
                        .italic()
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .padding(6)
                        .background(ZholdasTheme.surface.opacity(0.58))
                        .cornerRadius(6)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    closeReport(id: report.id)
                } label: {
                    Text("mod_btn_dismiss".localized)
                        .font(.footnote)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ZholdasTheme.surface.opacity(0.74))
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .cornerRadius(8)
                }
                
                if let targetID = report.reportedUserID, let targetName = report.reportedUserName {
                    Button {
                        userToBanID = targetID
                        userToBanName = targetName
                        reportToCloseOnBan = report.id
                        isShowingBanSheet = true
                    } label: {
                        Text("mod_btn_ban".localized)
                            .font(.footnote)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }
    
    // 1. Stats Tab (MVP Analytics)
    @ViewBuilder
    private var statsTabContent: some View {
        if let st = stats {
            VStack(alignment: .leading, spacing: 20) {
                Text("mod_stats_title".localized)
                    .font(.headline)
                    .foregroundColor(ZholdasTheme.textPrimary)
                
                // Grid counters
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricCard(title: "\(st.users)", label: "mod_stats_users".localized, color: .blue)
                    metricCard(title: "\(st.events)", label: "mod_stats_events".localized, color: ZholdasTheme.accent)
                    metricCard(title: "\(st.activeEvents)", label: "mod_stats_active".localized, color: .green)
                    metricCard(title: "\(st.messages)", label: "mod_stats_messages".localized, color: .purple)
                    metricCard(title: "\(st.reports)", label: "mod_stats_reports".localized, color: .red)
                    metricCard(title: "\(st.bans)", label: "mod_stats_bans".localized, color: .yellow)
                }
                
                Text("mod_analytics_title".localized)
                    .font(.headline)
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    analyticRow(label: "mod_anal_reg_today".localized, value: "\(st.regToday)")
                    analyticRow(label: "mod_anal_reg_7d".localized, value: "\(st.reg7Days)")
                    analyticRow(label: "mod_anal_reg_30d".localized, value: "\(st.reg30Days)")
                    analyticRow(label: "mod_anal_ev_7d".localized, value: "\(st.events7Days)")
                    analyticRow(label: "mod_anal_ev_30d".localized, value: "\(st.events30Days)")
                    analyticRow(label: "mod_anal_joins_7d".localized, value: "\(st.joins7Days)")
                }
                .padding()
                .glassBackground(cornerRadius: 16)
            }
        } else {
            ProgressView().tint(ZholdasTheme.accent)
        }
    }
    
    private func metricCard(title: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(ZholdasTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassBackground(cornerRadius: 12)
    }
    
    private func analyticRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(ZholdasTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textPrimary)
        }
    }
    
    // 2. Users Tab
    var filteredUsers: [ModerationUser] {
        if userSearchQuery.isEmpty { return users }
        return users.filter {
            $0.fullName.localizedCaseInsensitiveContains(userSearchQuery) ||
            $0.username.localizedCaseInsensitiveContains(userSearchQuery) ||
            $0.email.localizedCaseInsensitiveContains(userSearchQuery) ||
            $0.userID.localizedCaseInsensitiveContains(userSearchQuery)
        }
    }
    
    @ViewBuilder
    private var usersTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("mod_users_title".localized)
                .font(.headline)
                .foregroundColor(ZholdasTheme.textPrimary)
            
            TextField("mod_users_search_placeholder".localized, text: $userSearchQuery)
                .padding()
                .background(ZholdasTheme.surface.opacity(0.72))
                .cornerRadius(12)
                .foregroundColor(ZholdasTheme.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
            
            if isLoading {
                ProgressView().tint(ZholdasTheme.accent).padding(.top, 20)
            } else {
                ForEach(filteredUsers) { usr in
                    userAdminCard(for: usr)
                }
            }
        }
    }
    
    @ViewBuilder
    private func userAdminCard(for usr: ModerationUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedUserID = usr.userID
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZholdasAvatarView(
                        avatarURL: usr.avatarURL.isEmpty ? nil : usr.avatarURL,
                        initials: initials(from: usr.fullName),
                        size: 46
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(usr.fullName)
                            .font(.headline)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        Text("@\(usr.username)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ZholdasTheme.accent)
                        Text(usr.email)
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.textSecondary)
                        Text("ID: \(shortID(usr.userID))")
                            .font(.caption2.monospaced())
                            .foregroundColor(ZholdasTheme.textTertiary)
                        Text(userMetaLine(usr))
                            .font(.caption2)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(ZholdasTheme.textTertiary)

                    if usr.isBanned {
                        Text("mod_user_banned_label".localized)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    }
                }
            }
            .buttonStyle(.plain)

            if !usr.bio.isEmpty {
                Text(usr.bio)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .lineLimit(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ZholdasTheme.surface.opacity(0.58))
                    .cornerRadius(10)
            }

            HStack(spacing: 8) {
                adminStatusPill(
                    title: usr.emailConfirmed ? "Email подтвержден" : "Email не подтвержден",
                    icon: usr.emailConfirmed ? "checkmark.seal.fill" : "envelope.badge.fill",
                    color: usr.emailConfirmed ? .green : .yellow
                )

                if let lastSignIn = usr.lastSignInAt {
                    adminStatusPill(
                        title: "Вход: \(formatDate(lastSignIn))",
                        icon: "clock.arrow.circlepath",
                        color: ZholdasTheme.accent
                    )
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                adminMiniMetric(value: "\(usr.eventsCount)", label: "Ивенты")
                adminMiniMetric(value: "\(usr.reportsReceived)", label: "Жалобы")
                adminMiniMetric(value: "\(usr.reportsSent)", label: "Репорты")
            }

            if usr.isBanned && !usr.banReason.isEmpty {
                Text("Причина: \(usr.banReason)")
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.9))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
            }

            HStack(spacing: 8) {
                Text("mod_user_roles_label".localized)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
                roleButton(title: "user", active: normalizedRole(usr.role) == "user", user: usr)
                roleButton(title: "moderator", active: normalizedRole(usr.role) == "moderator", user: usr)
                roleButton(title: "admin", active: normalizedRole(usr.role) == "admin", user: usr)
            }

            Divider().background(ZholdasTheme.border)

            HStack(spacing: 12) {
                if usr.isBanned {
                    Button {
                        unbanUser(id: usr.userID)
                    } label: {
                        Text("mod_btn_unban".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                } else {
                    Button {
                        userToBanID = usr.userID
                        userToBanName = usr.fullName
                        reportToCloseOnBan = nil
                        isShowingBanSheet = true
                    } label: {
                        Text("mod_btn_ban".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                }

                Button {
                    deleteUserPermanently(id: usr.userID)
                } label: {
                    Text("mod_btn_delete_perm".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func adminMiniMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(ZholdasTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(ZholdasTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(ZholdasTheme.surface.opacity(0.58))
        .cornerRadius(10)
    }

    private func adminStatusPill(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(8)
    }
    
    private func roleButton(title: String, active: Bool, user: ModerationUser) -> some View {
        Button {
            updateUserRole(id: user.userID, newRole: title)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(active ? ZholdasTheme.accent : ZholdasTheme.surface.opacity(0.68))
                .foregroundColor(active ? .white : ZholdasTheme.textPrimary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(actionLoading)
    }
    
    // 3. Events Tab
    var filteredEvents: [ModerationEvent] {
        var list = events
        if selectedEventFilter == "active" {
            list = events.filter { $0.status == "active" }
        } else if selectedEventFilter == "closed" {
            list = events.filter { $0.status == "closed" || $0.status == "finished" }
        } else if selectedEventFilter == "cancelled" {
            list = events.filter { $0.status == "cancelled" }
        }
        
        if eventSearchQuery.isEmpty { return list }
        return list.filter { $0.title.localizedCaseInsensitiveContains(eventSearchQuery) }
    }
    
    @ViewBuilder
    private var eventsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("mod_events_title".localized)
                .font(.headline)
                .foregroundColor(ZholdasTheme.textPrimary)
            
            TextField("mod_events_search_placeholder".localized, text: $eventSearchQuery)
                .padding()
                .background(ZholdasTheme.surface.opacity(0.72))
                .cornerRadius(12)
                .foregroundColor(ZholdasTheme.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
            
            // Event type filters
            HStack(spacing: 8) {
                eventFilterPill("mod_events_filter_all", value: "all")
                eventFilterPill("mod_events_filter_active", value: "active")
                eventFilterPill("mod_events_filter_closed", value: "closed")
                eventFilterPill("mod_events_filter_cancelled", value: "cancelled")
            }
            .padding(.vertical, 4)
            
            if isLoading {
                ProgressView().tint(ZholdasTheme.accent).padding(.top, 20)
            } else {
                ForEach(filteredEvents) { ev in
                    eventAdminCard(for: ev)
                }
            }
        }
    }
    
    private func eventFilterPill(_ titleKey: String, value: String) -> some View {
        Button {
            selectedEventFilter = value
        } label: {
            Text(titleKey.localized)
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedEventFilter == value ? ZholdasTheme.accent : ZholdasTheme.surface.opacity(0.68))
                .foregroundColor(selectedEventFilter == value ? .white : ZholdasTheme.textPrimary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func eventAdminCard(for ev: ModerationEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedEvent = eventFromModerationEvent(ev)
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ev.title)
                            .font(.headline)
                            .foregroundColor(ZholdasTheme.textPrimary)

                        Text("\("mod_creator_label".localized): \(ev.creatorName) (@\(ev.creatorUsername))")
                            .font(.caption)
                            .foregroundColor(ZholdasTheme.textSecondary)

                        Text("\("create_ev_start".localized): \(formatDate(ev.startTime)) - \(formatDate(ev.endTime))")
                            .font(.caption2)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }

                    Spacer()

                    Text(ev.status.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ev.status == "active" ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(ev.status == "active" ? .green : .gray)
                        .cornerRadius(6)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(ZholdasTheme.textTertiary)
                        .padding(.top, 2)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                if !ev.locationName.isEmpty {
                    Label(ev.locationName, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textPrimary)
                }

                HStack(spacing: 8) {
                    eventInfoPill("\(ev.participantCount)/\(ev.maxParticipants)", icon: "person.2.fill")
                    eventInfoPill(categoryTitle(for: ev.category), icon: categoryIcon(for: ev.category))
                    eventInfoPill(ev.visibility, icon: ev.visibility == "friends" ? "person.2.circle" : "globe")
                }

                HStack(spacing: 8) {
                    if ev.minAge > 0 || ev.maxAge > 0 {
                        eventInfoPill(ageFilterText(for: ev), icon: "calendar")
                    }
                    if !ev.genderFilter.isEmpty {
                        eventInfoPill(ev.genderFilter, icon: "person.crop.circle")
                    }
                }

                if !ev.description.isEmpty {
                    Text(ev.description)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Divider().background(ZholdasTheme.border)

            HStack(spacing: 10) {
                if ev.status == "active" {
                    Button {
                        updateEventStatus(id: ev.id, status: "closed")
                    } label: {
                        Text("btn_close".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(ZholdasTheme.textPrimary)
                            .cornerRadius(8)
                    }

                    Button {
                        updateEventStatus(id: ev.id, status: "cancelled")
                    } label: {
                        Text("mod_btn_cancel".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(ZholdasTheme.accent.opacity(0.2))
                            .foregroundColor(ZholdasTheme.accent)
                            .cornerRadius(8)
                    }
                } else {
                    Button {
                        updateEventStatus(id: ev.id, status: "active")
                    } label: {
                        Text("mod_btn_activate".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                }

                Button {
                    updateEventStatus(id: ev.id, status: "deleted")
                } label: {
                    Text("mod_btn_delete".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func eventInfoPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(ZholdasTheme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ZholdasTheme.surface.opacity(0.62))
            .cornerRadius(8)
    }

    private func eventFromModerationEvent(_ ev: ModerationEvent) -> Event {
        Event(
            id: ev.id,
            creatorID: ev.creatorID,
            title: ev.title,
            description: ev.description,
            category: ev.category,
            locationName: ev.locationName,
            latitude: ev.latitude,
            longitude: ev.longitude,
            startTime: ev.startTime,
            endTime: ev.endTime,
            maxParticipants: ev.maxParticipants,
            status: ev.status,
            imageURL: ev.imageURL.isEmpty ? nil : ev.imageURL,
            distanceMeters: nil,
            participantsCount: Int32(ev.participantCount),
            isJoined: nil,
            visibility: ev.visibility,
            genderFilter: ev.genderFilter,
            minAge: ev.minAge > 0 ? Int32(ev.minAge) : nil,
            maxAge: ev.maxAge > 0 ? Int32(ev.maxAge) : nil
        )
    }
    
    // 4. Tools Tab
    @ViewBuilder
    private var auditLogsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("mod_audit_title".localized)
                .font(.headline)
                .foregroundColor(ZholdasTheme.textPrimary)

            if isLoading {
                ProgressView().tint(ZholdasTheme.accent).padding(.top, 20)
            } else if auditLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 42))
                        .foregroundColor(ZholdasTheme.accent)
                    Text("mod_audit_empty".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
            } else {
                ForEach(auditLogs) { item in
                    auditLogCard(for: item)
                }
            }
        }
    }

    private func auditLogCard(for item: ModerationAuditLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: auditIcon(for: item.actionType))
                    .font(.headline)
                    .foregroundColor(auditColor(for: item.actionType))
                    .frame(width: 34, height: 34)
                    .background(auditColor(for: item.actionType).opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(auditTitle(for: item.actionType))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(ZholdasTheme.textPrimary)
                    Text("\(item.moderatorName) · \(formatDate(item.createdAt))")
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.textSecondary)
                    Text("\(item.targetType) #\(shortID(item.targetID))")
                        .font(.caption2.monospaced())
                        .foregroundColor(ZholdasTheme.accent)
                }

                Spacer()
            }

            if !item.details.isEmpty {
                Text(item.details)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ZholdasTheme.surface.opacity(0.58))
                    .cornerRadius(10)
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    // 5. Tools Tab
    @ViewBuilder
    private var toolsTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Broadcast Announcements Section
            VStack(alignment: .leading, spacing: 12) {
                Text("mod_tools_broadcast_header".localized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .tracking(1.0)
                
                TextField("mod_tools_broadcast_title_placeholder".localized, text: $broadcastTitle)
                    .padding()
                    .background(ZholdasTheme.surface.opacity(0.72))
                    .cornerRadius(12)
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                
                TextEditor(text: $broadcastText)
                    .frame(height: 100)
                    .padding(8)
                    .background(ZholdasTheme.surface.opacity(0.72))
                    .cornerRadius(12)
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                
                Button {
                    sendBroadcast()
                } label: {
                    HStack {
                        if actionLoading {
                            ProgressView().tint(.white).padding(.trailing, 8)
                        }
                        Text("mod_tools_broadcast_submit".localized)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ZholdasTheme.accent)
                    .cornerRadius(12)
                }
                .disabled(broadcastTitle.isEmpty || broadcastText.isEmpty || actionLoading)
            }
            .padding()
            .glassBackground(cornerRadius: 16)
            
            // System Settings Section
            VStack(alignment: .leading, spacing: 14) {
                Text("mod_tools_settings_header".localized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textSecondary)
                    .tracking(1.0)
                
                Toggle("AI помощник", isOn: $aiEnabled)
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .padding(.vertical, 4)
                
                Divider().background(ZholdasTheme.border)
                
                HStack {
                    Text("Город по умолчанию")
                        .foregroundColor(ZholdasTheme.textPrimary)
                    Spacer()
                    TextField("Almaty", text: $defaultCity)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(ZholdasTheme.accent)
                }
                
                Divider().background(ZholdasTheme.border)
                
                HStack {
                    Text("Лимит ИИ / 10 мин")
                        .foregroundColor(ZholdasTheme.textPrimary)
                    Spacer()
                    TextField("8", text: $aiRateLimit)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(ZholdasTheme.accent)
                }
                
                Button {
                    saveSystemSettings()
                } label: {
                    HStack {
                        if actionLoading {
                            ProgressView().tint(.white)
                        }
                        Text("mod_tools_settings_save".localized)
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ZholdasTheme.surface.opacity(0.74))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                }
                .disabled(actionLoading)
            }
            .padding()
            .glassBackground(cornerRadius: 16)
        }
    }
    
    // MARK: - Actions Sheet
    
    private var banReasonInputSheet: some View {
        ZStack {
            ZholdasTheme.appBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("mod_ban_sheet_title".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ZholdasTheme.textPrimary)
                
                Text("\("mod_ban_sheet_reason_placeholder".localized) (\(userToBanName)):")
                    .font(.subheadline)
                    .foregroundColor(ZholdasTheme.textSecondary)
                
                TextField("mod_ban_sheet_reason_placeholder".localized, text: $banReason)
                    .padding()
                    .background(ZholdasTheme.surface.opacity(0.72))
                    .cornerRadius(12)
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ZholdasTheme.border, lineWidth: 1))
                
                HStack(spacing: 12) {
                    Button("btn_cancel".localized) {
                        isShowingBanSheet = false
                        banReason = ""
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ZholdasTheme.surface.opacity(0.74))
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .cornerRadius(12)
                    
                    Button("mod_btn_ban".localized) {
                        if let uid = userToBanID {
                            banUser(id: uid, reason: banReason, reportID: reportToCloseOnBan)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(banReason.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .presentationDetents([.height(280)])
    }
    
    // MARK: - Logic & API Requests
    
    private func loadDataForCurrentTab() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            if selectedTab == 0 {
                // Fetch reports
                let list: [Report] = try await APIClient.shared.request("/moderation/reports", method: "GET", requiresAuth: true)
                await MainActor.run {
                    self.reports = list
                    self.isLoading = false
                }
            } else if selectedTab == 1 {
                // Fetch stats
                let statsRes: ModerationStats = try await APIClient.shared.request("/moderation/stats", method: "GET", requiresAuth: true)
                await MainActor.run {
                    self.stats = statsRes
                    self.isLoading = false
                }
            } else if selectedTab == 2 {
                // Fetch users
                let usersRes: [ModerationUser] = try await APIClient.shared.request("/moderation/users", method: "GET", requiresAuth: true)
                await MainActor.run {
                    self.users = usersRes
                    self.isLoading = false
                }
            } else if selectedTab == 3 {
                // Fetch events
                let eventsRes: [ModerationEvent] = try await APIClient.shared.request("/moderation/events", method: "GET", requiresAuth: true)
                await MainActor.run {
                    self.events = eventsRes
                    self.isLoading = false
                }
            } else if selectedTab == 4 {
                let logsRes: [ModerationAuditLog] = try await APIClient.shared.request("/moderation/audit-logs", method: "GET", requiresAuth: true)
                await MainActor.run {
                    self.auditLogs = logsRes
                    self.isLoading = false
                }
            } else if selectedTab == 5 {
                let settingsRes: ModerationSettings = try await APIClient.shared.request("/moderation/settings", method: "GET", requiresAuth: true)
                await MainActor.run {
                    self.aiEnabled = settingsRes.aiEnabled
                    self.aiRateLimit = "\(settingsRes.aiRateLimitPer10m)"
                    self.defaultCity = settingsRes.defaultCity
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func closeReport(id: Int32) {
        Task {
            do {
                let _: [String: String] = try await APIClient.shared.request("/moderation/reports/\(id)/close", method: "POST", requiresAuth: true)
                await MainActor.run {
                    self.reports.removeAll(where: { $0.id == id })
                    self.successMessage = "Жалоба успешно отклонена/закрыта"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func banUser(id: String, reason: String, reportID: Int32?) {
        isShowingBanSheet = false
        Task {
            do {
                let body = try JSONSerialization.data(withJSONObject: ["reason": reason], options: [])
                let _: [String: String] = try await APIClient.shared.request("/moderation/users/\(id)/ban", method: "POST", body: body, requiresAuth: true)
                
                // If this ban resolved a specific report, close it
                if let repID = reportID {
                    let _: [String: String] = try await APIClient.shared.request("/moderation/reports/\(repID)/close", method: "POST", requiresAuth: true)
                }
                
                await MainActor.run {
                    self.successMessage = "Пользователь заблокирован"
                    self.banReason = ""
                }
                
                await loadDataForCurrentTab()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func unbanUser(id: String) {
        Task {
            do {
                let _: [String: String] = try await APIClient.shared.request("/moderation/users/\(id)/unban", method: "POST", requiresAuth: true)
                await MainActor.run {
                    self.successMessage = "Пользователь успешно разблокирован"
                }
                await loadDataForCurrentTab()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func deleteUserPermanently(id: String) {
        Task {
            do {
                let _: [String: String] = try await APIClient.shared.request("/moderation/users/\(id)/delete", method: "POST", requiresAuth: true)
                await MainActor.run {
                    self.successMessage = "Пользователь удален навсегда"
                }
                await loadDataForCurrentTab()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateUserRole(id: String, newRole: String) {
        actionLoading = true
        Task {
            do {
                let body = try JSONSerialization.data(withJSONObject: ["role": newRole], options: [])
                let _: [String: String] = try await APIClient.shared.request("/moderation/users/\(id)/role", method: "POST", body: body, requiresAuth: true)
                await MainActor.run {
                    self.successMessage = "Роль пользователя обновлена на \(newRole)"
                    self.actionLoading = false
                }
                await loadDataForCurrentTab()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.actionLoading = false
                }
            }
        }
    }
    
    private func updateEventStatus(id: Int32, status: String) {
        Task {
            do {
                let body = try JSONSerialization.data(withJSONObject: ["status": status], options: [])
                let _: [String: String] = try await APIClient.shared.request("/moderation/events/\(id)/status", method: "POST", body: body, requiresAuth: true)
                await MainActor.run {
                    self.successMessage = status == "deleted" ? "Событие удалено" : "Статус события обновлен на \(status)"
                }
                await loadDataForCurrentTab()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendBroadcast() {
        actionLoading = true
        Task {
            do {
                let body = try JSONSerialization.data(withJSONObject: ["title": broadcastTitle, "text": broadcastText], options: [])
                let _: [String: String] = try await APIClient.shared.request("/moderation/broadcast", method: "POST", body: body, requiresAuth: true)
                await MainActor.run {
                    self.successMessage = "Объявление успешно отправлено всем пользователям!"
                    self.broadcastTitle = ""
                    self.broadcastText = ""
                    self.actionLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.actionLoading = false
                }
            }
        }
    }

    private func saveSystemSettings() {
        guard let limit = Int(aiRateLimit), limit > 0 else {
            errorMessage = "Лимит ИИ должен быть положительным числом"
            return
        }

        let city = defaultCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else {
            errorMessage = "Город по умолчанию не должен быть пустым"
            return
        }

        actionLoading = true
        Task {
            do {
                let body = try JSONSerialization.data(withJSONObject: [
                    "ai_enabled": aiEnabled,
                    "ai_rate_limit_per_10m": limit,
                    "default_city": city
                ], options: [])

                let saved: ModerationSettings = try await APIClient.shared.request(
                    "/moderation/settings",
                    method: "PUT",
                    body: body,
                    requiresAuth: true
                )

                await MainActor.run {
                    self.aiEnabled = saved.aiEnabled
                    self.aiRateLimit = "\(saved.aiRateLimitPer10m)"
                    self.defaultCity = saved.defaultCity
                    self.successMessage = "mod_tools_settings_saved_msg".localized
                    self.actionLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.actionLoading = false
                }
            }
        }
    }
    
    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "Z" : result
    }

    private func userMetaLine(_ user: ModerationUser) -> String {
        var parts = ["\("mod_user_roles_label".localized) \(user.role)"]

        if !user.city.isEmpty {
            parts.append(user.city)
        }
        if user.age > 0 {
            parts.append("\(user.age) лет")
        }
        if !user.gender.isEmpty {
            parts.append(user.gender)
        }

        parts.append("\("tab_activity".localized): \(formatDate(user.createdAt))")
        return parts.joined(separator: " · ")
    }

    private func ageFilterText(for event: ModerationEvent) -> String {
        if event.minAge > 0 && event.maxAge > 0 {
            return "\(event.minAge)-\(event.maxAge)"
        }
        if event.minAge > 0 {
            return "\(event.minAge)+"
        }
        return "до \(event.maxAge)"
    }

    private func categoryIcon(for category: String) -> String {
        switch normalizedCategory(category) {
        case "cat_mountains", "hiking", "mountains", "горы", "тау":
            return "mountain.2.fill"
        case "cat_walks", "walk", "прогулки":
            return "tree.fill"
        case "cat_sports", "sports", "спорт":
            return "soccerball"
        case "cat_theater", "theater", "театр":
            return "theatermasks.fill"
        case "cat_restaurant", "restaurant", "рестораны", "кафе":
            return "fork.knife"
        case "cat_games", "board_games", "games", "игры":
            return "dice.fill"
        case "cat_networking", "networking", "нетворкинг":
            return "cup.and.saucer.fill"
        default:
            return "sparkles"
        }
    }

    private func categoryTitle(for category: String) -> String {
        let normalized = normalizedCategory(category)
        switch normalized {
        case "hiking", "mountains": return "cat_mountains".localized
        case "walk": return "cat_walks".localized
        case "sports": return "cat_sports".localized
        case "theater": return "cat_theater".localized
        case "restaurant": return "cat_restaurant".localized
        case "board_games", "games": return "cat_games".localized
        case "networking": return "cat_networking".localized
        default: return normalized.hasPrefix("cat_") ? normalized.localized : category
        }
    }

    private func normalizedCategory(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedRole(_ role: String?) -> String {
        role?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "user"
    }

    private func shortID(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return trimmed }
        return "\(trimmed.prefix(8))..."
    }

    private func auditIcon(for action: String) -> String {
        switch action.lowercased() {
        case "ban": return "hand.raised.fill"
        case "unban": return "checkmark.shield.fill"
        case "update_role": return "person.badge.key.fill"
        case "close_report": return "checkmark.bubble.fill"
        case "delete_event", "delete_profile": return "trash.fill"
        case "update_event_status": return "calendar.badge.clock"
        default: return "shield.lefthalf.filled"
        }
    }

    private func auditColor(for action: String) -> Color {
        switch action.lowercased() {
        case "ban", "delete_event", "delete_profile": return .red
        case "unban": return .green
        case "update_role": return ZholdasTheme.accent
        case "close_report": return .blue
        default: return .purple
        }
    }

    private func auditTitle(for action: String) -> String {
        switch action.lowercased() {
        case "ban": return "Блокировка пользователя"
        case "unban": return "Разблокировка пользователя"
        case "update_role": return "Изменение роли"
        case "close_report": return "Жалоба закрыта"
        case "delete_event": return "Ивент удален"
        case "delete_profile": return "Профиль удален"
        case "update_event_status": return "Статус ивента изменен"
        default: return action
        }
    }
    
    private func getReasonLabel(_ reason: String) -> String {
        switch reason.lowercased() {
        case "spam": return "СПАМ"
        case "abuse": return "ОСКОРБЛЕНИЯ"
        case "inappropriate": return "НЕПРИЕМЛЕМЫЙ КОНТЕНТ"
        default: return "ЖАЛОБА"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - DTO Models for Admin View

struct ModerationUser: Codable, Identifiable {
    var id: String { userID }
    let userID: String
    let username: String
    let fullName: String
    let avatarURL: String
    let bio: String
    let city: String
    let gender: String
    let birthYear: Int
    let age: Int
    var role: String
    var isBanned: Bool
    let banReason: String
    let createdAt: Date
    let email: String
    let emailConfirmed: Bool
    let lastSignInAt: Date?
    let eventsCount: Int
    let reportsReceived: Int
    let reportsSent: Int
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case bio
        case city
        case gender
        case birthYear = "birth_year"
        case age
        case role
        case isBanned = "is_banned"
        case banReason = "ban_reason"
        case createdAt = "created_at"
        case email
        case emailConfirmed = "email_confirmed"
        case lastSignInAt = "last_sign_in_at"
        case eventsCount = "events_count"
        case reportsReceived = "reports_received"
        case reportsSent = "reports_sent"
    }
}

struct ModerationAuditLog: Codable, Identifiable {
    let id: Int32
    let moderatorID: String
    let moderatorName: String
    let actionType: String
    let targetType: String
    let targetID: String
    let details: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case moderatorID = "moderator_id"
        case moderatorName = "moderator_name"
        case actionType = "action_type"
        case targetType = "target_type"
        case targetID = "target_id"
        case details
        case createdAt = "created_at"
    }
}

struct ModerationSettings: Codable {
    let aiEnabled: Bool
    let aiRateLimitPer10m: Int
    let defaultCity: String

    enum CodingKeys: String, CodingKey {
        case aiEnabled = "ai_enabled"
        case aiRateLimitPer10m = "ai_rate_limit_per_10m"
        case defaultCity = "default_city"
    }
}

struct ModerationEvent: Codable, Identifiable {
    let id: Int32
    let creatorID: String
    let title: String
    let description: String
    let category: String
    var status: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date
    let maxParticipants: Int32
    let imageURL: String
    let visibility: String
    let genderFilter: String
    let minAge: Int
    let maxAge: Int
    let createdAt: Date
    let creatorUsername: String
    let creatorName: String
    let participantCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case title
        case description
        case category
        case status
        case locationName = "location_name"
        case latitude
        case longitude
        case startTime = "start_time"
        case endTime = "end_time"
        case maxParticipants = "max_participants"
        case imageURL = "image_url"
        case visibility
        case genderFilter = "gender_filter"
        case minAge = "min_age"
        case maxAge = "max_age"
        case createdAt = "created_at"
        case creatorUsername = "creator_username"
        case creatorName = "creator_name"
        case participantCount = "participant_count"
    }
}

struct ModerationStats: Codable {
    let users: Int
    let events: Int
    let activeEvents: Int
    let messages: Int
    let reports: Int
    let bans: Int
    
    let regToday: Int
    let reg7Days: Int
    let reg30Days: Int
    let events7Days: Int
    let events30Days: Int
    let messages7Days: Int
    let joins7Days: Int
    let actives7Days: Int
    
    enum CodingKeys: String, CodingKey {
        case users, events, messages, reports, bans
        case activeEvents = "active_events"
        case regToday = "reg_today"
        case reg7Days = "reg_7_days"
        case reg30Days = "reg_30_days"
        case events7Days = "events_7_days"
        case events30Days = "events_30_days"
        case messages7Days = "messages_7_days"
        case joins7Days = "joins_7_days"
        case actives7Days = "actives_7_days"
    }
}
