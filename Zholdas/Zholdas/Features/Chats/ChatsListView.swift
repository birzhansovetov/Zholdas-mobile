import SwiftUI

struct ChatsListView: View {
    @EnvironmentObject var langManager: LocalizationManager
    @State private var searchQuery: String = ""
    @State private var sessions: [ChatSession] = [
        ChatSession(
            id: 999,
            title: "Жорик (ИИ-помощник)",
            timeLabel: "Активен",
            lastMessage: "Привет! Я Жорик, твой ИИ-помощник. Задавай мне любые вопросы про Алматы!",
            lastMessageSender: "Жорик",
            lastMessageTime: Date(),
            isCompleted: false,
            categoryIcon: "sparkles",
            categoryColorHex: "#7C5CFF",
            messages: []
        )
    ]
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var filteredSessions: [ChatSession] {
        if searchQuery.isEmpty {
            return sessions
        }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("tab_chats".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textPrimary)
                        
                        Text(String(format: "chats_count".localized, filteredSessions.count))
                            .font(.subheadline)
                            .foregroundColor(ZholdasTheme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Search Bar
                    searchBarView
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    if let errorMessage = errorMessage {
                        VStack(spacing: 8) {
                            Text("⚠️ \(errorMessage)")
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                            Button("Повторить") {
                                Task {
                                    await fetchChatSessions()
                                }
                            }
                            .foregroundColor(ZholdasTheme.accent)
                            .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                    
                    // Chats List
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(0..<filteredSessions.count, id: \.self) { index in
                                let session = filteredSessions[index]
                                NavigationLink(destination: ChatRoomView(session: binding(for: session))) {
                                    chatRowView(for: session)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(24)
                    }
                }
                
                if isLoading && sessions.count <= 1 {
                    ProgressView()
                        .tint(ZholdasTheme.accent)
                        .scaleEffect(1.5)
                }
            }
            .task {
                await fetchChatSessions()
            }
            .refreshable {
                await fetchChatSessions()
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ZholdasTheme.textSecondary)
            TextField("chats_search_placeholder".localized, text: $searchQuery)
                .foregroundColor(ZholdasTheme.textPrimary)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ZholdasTheme.textSecondary)
                }
            }
        }
        .padding()
        .background(ZholdasTheme.surface.opacity(0.72))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func chatRowView(for session: ChatSession) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: session.categoryColorHex).opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: session.categoryIcon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: session.categoryColorHex))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    // Title
                    Text(session.id == 999 ? "chat_ai_assistant_name".localized : session.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(ZholdasTheme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Status Badge
                    if session.isCompleted {
                        Text("chat_completed_badge".localized)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundColor(ZholdasTheme.accent)
                            .background(ZholdasTheme.accent.opacity(0.12))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ZholdasTheme.accent.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                
                // Date Subtitle
                Text(session.timeLabel)
                    .font(.caption)
                    .foregroundColor(ZholdasTheme.textSecondary)
                
                // Message Preview
                Text(session.id == 999 ? "chat_ai_assistant_welcome".localized : (session.messages.isEmpty ? session.lastMessage : lastMessagePreview(for: session)))
                    .font(.subheadline)
                    .foregroundColor(session.messages.isEmpty ? ZholdasTheme.textSecondary : ZholdasTheme.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(ZholdasTheme.surface.opacity(0.62))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ZholdasTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func lastMessagePreview(for session: ChatSession) -> String {
        guard let last = session.messages.last else { return session.lastMessage }
        if last.isCurrentUser {
            return "chat_prefix_you".localized + last.text
        }
        return "\(last.senderName): \(last.text)"
    }
    
    private func binding(for session: ChatSession) -> Binding<ChatSession> {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            fatalError("Session not found")
        }
        return $sessions[index]
    }
    
    private func getChatsWord(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "чатов"
        }
        if mod10 == 1 {
            return "чат"
        }
        if mod10 >= 2 && mod10 <= 4 {
            return "чата"
        }
        return "чатов"
    }
    
    // MARK: - Networking and Mapping Helpers
    
    private func fetchChatSessions() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let response: [ChatSessionResponse] = try await APIClient.shared.request("/chats", method: "GET", requiresAuth: true)
            
            await MainActor.run {
                var updatedSessions: [ChatSession] = []
                if let aiSession = self.sessions.first(where: { $0.id == 999 }) {
                    updatedSessions.append(aiSession)
                } else {
                    updatedSessions.append(ChatSession(
                        id: 999,
                        title: "Жорик (ИИ-помощник)",
                        timeLabel: "Активен",
                        lastMessage: "Привет! Я Жорик, твой ИИ-помощник. Задавай мне любые вопросы про Алматы!",
                        lastMessageSender: "Жорик",
                        lastMessageTime: Date(),
                        isCompleted: false,
                        categoryIcon: "sparkles",
                        categoryColorHex: "#7C5CFF",
                        messages: []
                    ))
                }
                
                let mapped = response.map { res -> ChatSession in
                    let (icon, color) = mapCategoryToIconAndColor(res.category)
                    let existingMessages = self.sessions.first(where: { $0.id == res.id })?.messages ?? []
                    
                    let timeLabel = formatLastMessageTime(res.lastMessageTime)
                    
                    return ChatSession(
                        id: res.id,
                        title: res.title,
                        timeLabel: timeLabel,
                        lastMessage: res.lastMessage,
                        lastMessageSender: res.lastMessageSender,
                        lastMessageTime: res.lastMessageTime,
                        isCompleted: res.isCompleted,
                        categoryIcon: icon,
                        categoryColorHex: color,
                        messages: existingMessages
                    )
                }
                
                updatedSessions.append(contentsOf: mapped)
                self.sessions = updatedSessions
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func mapCategoryToIconAndColor(_ category: String) -> (String, String) {
        switch category.lowercased() {
        case "спорт", "sport", "бег", "running":
            return ("figure.run", "#48BB78")
        case "настолки", "игры", "boardgames":
            return ("gamecontroller.fill", "#9F7AEA")
        case "кино", "cinema", "movies":
            return ("film.fill", "#E53E3E")
        case "еда", "food", "ресторан":
            return ("fork.knife", "#DD6B20")
        case "образование", "учеба", "education":
            return ("book.fill", "#3182CE")
        case "прогулка", "walk", "горы":
            return ("figure.walk", "#319795")
        default:
            return ("sparkles", "#7C5CFF")
        }
    }
    
    private func formatLastMessageTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM"
            return formatter.string(from: date)
        }
    }
}

// MARK: - API Response Model

struct ChatSessionResponse: Codable {
    let id: Int32
    let title: String
    let category: String
    let lastMessage: String
    let lastMessageSender: String
    let lastMessageTime: Date
    let isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case lastMessage = "last_message"
        case lastMessageSender = "last_message_sender"
        case lastMessageTime = "last_message_time"
        case isCompleted = "is_completed"
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ChatsListView()
}
