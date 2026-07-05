import SwiftUI
import PhotosUI

struct ChatRoomView: View {
    @Binding var session: ChatSession
    @State private var messageText: String = ""
    @State private var isSimulatingReply = false
    @State private var isJorykMentionActive = false
    @FocusState private var isMessageFieldFocused: Bool
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @State private var isLoadingHistory = false
    @State private var errorString: String? = nil
    @State private var isShowingReportSheet = false
    @State private var selectedReportMessageID: Int32? = nil
    @State private var selectedReportSenderID: String? = nil
    
    @State private var webSocketManager: ChatWebSocketManager? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    // Simbot replies
    private let boardGameReplies = [
        "Супер! Я принесу с собой Монополию и Catan.",
        "А чай/печеньки там будут? 🍪",
        "Кто-то еще хочет присоединиться?",
        "Отличная идея, буду вовремя!",
        "Я за Манчкин проголосовал бы."
    ]
    
    private let runningReplies = [
        "Гав гав гав! 🐶",
        "Я готов пробежать 5 км в этот раз.",
        "Встречаемся на стадионе или в парке?",
        "Отличная тренировка намечается!",
        "Кто возьмет воду?"
    ]
    
    var body: some View {
        ZStack {
            // Sleek Dark Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let error = errorString {
                    HStack(spacing: 8) {
                        Image(systemName: error.contains("офлайн") ? "wifi.slash" : "exclamationmark.circle.fill")
                            .foregroundColor(.white)
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        
                        if !error.contains("офлайн") {
                            Spacer()
                            Button {
                                errorString = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(error.contains("офлайн") ? ZholdasTheme.accent : Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Messages List
                if session.messages.isEmpty {
                    emptyChatPlaceholder
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(session.messages) { message in
                                    messageBubble(for: message)
                                        .id(message.id)
                                }
                                
                                if isSimulatingReply {
                                    HStack {
                                        ProgressView()
                                            .tint(.gray)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(12)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .id("typing")
                                }
                            }
                            .padding(.vertical)
                        }
                        .onAppear {
                            if let lastMessage = session.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: session.messages) { _ in
                            if let lastMessage = session.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isSimulatingReply) { newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                // Input Area
                inputFieldView
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if isLoadingHistory && session.messages.isEmpty {
                    ProgressView()
                        .tint(ZholdasTheme.accent)
                        .scaleEffect(1.2)
                }
            }
        )
        .task {
            await fetchMessages()
            
            if session.id != 999 {
                let manager = ChatWebSocketManager(eventID: session.id)
                self.webSocketManager = manager
                manager.onMessageReceived = { response in
                    let currentUserID = authViewModel.currentUserProfile?.id ?? ""
                    let msgUUID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", response.id)) ?? UUID()
                    
                    if !session.messages.contains(where: { $0.dbID == response.id }) {
                        var newMsg = ChatMessage(
                            id: msgUUID,
                            senderName: response.senderName,
                            senderAvatarURL: response.senderAvatarURL.isEmpty ? nil : response.senderAvatarURL,
                            text: response.text,
                            timestamp: response.createdAt,
                            isCurrentUser: response.senderID == currentUserID
                        )
                        newMsg.dbID = response.id
                        newMsg.senderID = response.senderID
                        
                        withAnimation {
                            session.messages.append(newMsg)
                        }
                    }
                }
                manager.connect()
            }
        }
        .onDisappear {
            webSocketManager?.disconnect()
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportView(reportedUserID: selectedReportSenderID, eventID: nil, messageID: selectedReportMessageID)
                .environmentObject(authViewModel)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    sendPhotoMessage(data: data)
                }
                selectedPhotoItem = nil
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var emptyChatPlaceholder: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Здесь пока пусто")
                .font(.headline)
                .foregroundColor(.white)
            Text("Напишите первое сообщение, чтобы начать общение!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        Spacer()
    }
    
    @ViewBuilder
    private func photoMessageView(urlPath: String, isCurrentUser: Bool) -> some View {
        let cleanURL = urlPath.replacingOccurrences(of: "[photo] ", with: "").replacingOccurrences(of: "[photo]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fullURLString = AppConfig.backendAbsoluteURL(for: cleanURL)
        
        if let url = URL(string: fullURLString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 150)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 240, maxHeight: 180)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("Ошибка загрузки фото")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 200, height: 150)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Text("Некорректная ссылка на фото")
                .foregroundColor(.gray)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        let isPhoto = message.text.hasPrefix("[photo]")
        
        HStack {
            if message.isCurrentUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if isPhoto {
                        photoMessageView(urlPath: message.text, isCurrentUser: true)
                    } else {
                        Text(message.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                    }
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .padding(.trailing, 4)
                }
                .padding(.trailing, 16)
                .padding(.leading, 64)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.senderName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(ZholdasTheme.accent)
                        .padding(.leading, 4)
                    
                    HStack(alignment: .bottom) {
                        if isPhoto {
                            photoMessageView(urlPath: message.text, isCurrentUser: false)
                                .contextMenu {
                                    Button {
                                        selectedReportMessageID = message.dbID
                                        selectedReportSenderID = message.senderID
                                        isShowingReportSheet = true
                                    } label: {
                                        Label("Пожаловаться", systemImage: "exclamationmark.triangle")
                                    }
                                }
                        } else {
                            Text(message.text)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
                                .contextMenu {
                                    Button {
                                        selectedReportMessageID = message.dbID
                                        selectedReportSenderID = message.senderID
                                        isShowingReportSheet = true
                                    } label: {
                                        Label("Пожаловаться", systemImage: "exclamationmark.triangle")
                                    }
                                }
                        }
                        
                        Text(formatTime(message.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 64)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var inputFieldView: some View {
        if session.isCompleted {
            HStack(spacing: 8) {
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                Text("chat_readonly_completed".localized)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        } else {
            HStack(spacing: 12) {
                if session.id != 999 {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 18))
                            .padding(10)
                            .glassBackground(cornerRadius: 20)
                    }
                    .buttonStyle(SpringButtonStyle())

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            isJorykMentionActive.toggle()
                        }
                        isMessageFieldFocused = true
                    } label: {
                        Text("@")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(isJorykMentionActive ? .white : ZholdasTheme.accent)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(isJorykMentionActive ? ZholdasTheme.accent : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Circle()
                                    .stroke(ZholdasTheme.accent.opacity(isJorykMentionActive ? 0.45 : 0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(SpringButtonStyle())
                }
                
                TextField(isJorykMentionActive ? "Спросите Жорика..." : "chat_placeholder".localized, text: $messageText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassBackground(cornerRadius: 12)
                    .focused($isMessageFieldFocused)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(ZholdasTheme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringButtonStyle())
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Logic
    
    private func sendMessage() {
        let cleanText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        let outgoingText = normalizedEventChatText(cleanText)
        
        messageText = ""
        isJorykMentionActive = false
        
        if session.id == 999 {
            // Append user message locally first for AI assistant
            let newMsg = ChatMessage(
                id: UUID(),
                senderName: "Вы",
                senderAvatarURL: nil,
                text: cleanText,
                timestamp: Date(),
                isCurrentUser: true
            )
            session.messages.append(newMsg)
            
            isSimulatingReply = true
            Task {
                do {
                    // Map history from current messages (excluding the one we just sent)
                    let chatHistory = session.messages.dropLast().compactMap { msg -> AIChatMessage? in
                        let role = msg.isCurrentUser ? "user" : "model"
                        // Skip system messages or invalid sender roles
                        if msg.senderName == "Система" { return nil }
                        return AIChatMessage(role: role, text: msg.text)
                    }
                    
                    let req = AIChatRequest(message: cleanText, history: chatHistory)
                    let reqBody = try JSONEncoder().encode(req)
                    
                    let response: AIChatResponse = try await APIClient.shared.request("/ai/chat", method: "POST", body: reqBody, requiresAuth: true)
                    
                    await MainActor.run {
                        isSimulatingReply = false
                        let replyMsg = ChatMessage(
                            id: UUID(),
                            senderName: "Жорик",
                            senderAvatarURL: nil,
                            text: response.reply,
                            timestamp: Date(),
                            isCurrentUser: false
                        )
                        session.messages.append(replyMsg)
                    }
                } catch {
                    await MainActor.run {
                        isSimulatingReply = false
                        let errorMsg = ChatMessage(
                            id: UUID(),
                            senderName: "Система",
                            senderAvatarURL: nil,
                            text: "⚠️ Ошибка: \(error.localizedDescription)",
                            timestamp: Date(),
                            isCurrentUser: false
                        )
                        session.messages.append(errorMsg)
                    }
                }
            }
            return
        }
        
        // Real Chat message sending
        isSimulatingReply = true
        // Optimistic UI: Append message temporarily before sending
        let tempUUID = UUID()
        let tempMsg = ChatMessage(
            id: tempUUID,
            senderName: authViewModel.currentUserProfile?.fullName ?? "Вы",
            senderAvatarURL: authViewModel.currentUserProfile?.avatarURL,
            text: outgoingText,
            timestamp: Date(),
            isCurrentUser: true
        )
        session.messages.append(tempMsg)
        
        Task {
            do {
                let req = SendMessageDTO(text: outgoingText)
                let reqBody = try JSONEncoder().encode(req)
                
                let response: EventMessageResponse = try await APIClient.shared.request("/events/\(session.id)/messages", method: "POST", body: reqBody, requiresAuth: true)
                
                await MainActor.run {
                    isSimulatingReply = false
                    let currentUserID = authViewModel.currentUserProfile?.id ?? ""
                    let msgUUID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", response.id)) ?? UUID()
                    var newMsg = ChatMessage(
                        id: msgUUID,
                        senderName: response.senderName,
                        senderAvatarURL: response.senderAvatarURL.isEmpty ? nil : response.senderAvatarURL,
                        text: response.text,
                        timestamp: response.createdAt,
                        isCurrentUser: response.senderID == currentUserID
                    )
                    newMsg.dbID = response.id
                    newMsg.senderID = response.senderID
                    
                    // Replace the optimistic temp message with the actual message from server
                    if let index = session.messages.firstIndex(where: { $0.id == tempUUID }) {
                        session.messages[index] = newMsg
                    } else {
                        session.messages.append(newMsg)
                    }
                }
            } catch {
                await MainActor.run {
                    isSimulatingReply = false
                    // Remove optimistic temp message on error
                    session.messages.removeAll(where: { $0.id == tempUUID })
                    
                    let errorMsg = ChatMessage(
                        id: UUID(),
                        senderName: "Система",
                        senderAvatarURL: nil,
                        text: "⚠️ Ошибка отправки: \(error.localizedDescription)",
                        timestamp: Date(),
                        isCurrentUser: false
                    )
                    session.messages.append(errorMsg)
                }
            }
        }
    }

    private func normalizedEventChatText(_ text: String) -> String {
        guard session.id != 999 else { return text }
        if isJorykMention(text) {
            return text
        }
        return isJorykMentionActive ? "@Жорик \(text)" : text
    }

    private func isJorykMention(_ text: String) -> Bool {
        let lowercased = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased == "@ai"
            || lowercased.hasPrefix("@ai ")
            || lowercased == "@жорик"
            || lowercased.hasPrefix("@жорик ")
            || lowercased == "@joryk"
            || lowercased.hasPrefix("@joryk ")
            || lowercased == "@jorik"
            || lowercased.hasPrefix("@jorik ")
    }
    
    private func simulateReply() {
        isSimulatingReply = false
        
        let senderName = session.id == 2 ? "Yernur Superperson" : "Алексей (Модератор)"
        let replyPool = session.id == 2 ? runningReplies : boardGameReplies
        let text = replyPool.randomElement() ?? "Да, всё супер!"
        
        let replyMsg = ChatMessage(
            id: UUID(),
            senderName: senderName,
            senderAvatarURL: nil,
            text: text,
            timestamp: Date(),
            isCurrentUser: false
        )
        
        session.messages.append(replyMsg)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func fetchMessages(silent: Bool = false) async {
        guard session.id != 999 else { return }
        
        if !silent {
            await MainActor.run {
                self.isLoadingHistory = true
                self.errorString = nil
            }
        }
        
        do {
            let response: [EventMessageResponse] = try await APIClient.shared.request("/events/\(session.id)/messages", method: "GET", requiresAuth: true)
            
            await MainActor.run {
                let currentUserID = authViewModel.currentUserProfile?.id ?? ""
                let mapped = response.map { res -> ChatMessage in
                    let msgUUID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", res.id)) ?? UUID()
                    var msg = ChatMessage(
                        id: msgUUID,
                        senderName: res.senderName,
                        senderAvatarURL: res.senderAvatarURL.isEmpty ? nil : res.senderAvatarURL,
                        text: res.text,
                        timestamp: res.createdAt,
                        isCurrentUser: res.senderID == currentUserID
                    )
                    msg.dbID = res.id
                    msg.senderID = res.senderID
                    return msg
                }
                
                if self.session.messages != mapped {
                    self.session.messages = mapped
                }
                self.isLoadingHistory = false
                
                if let encoded = try? JSONEncoder().encode(mapped) {
                    UserDefaults.standard.set(encoded, forKey: "cached_messages_session_\(session.id)")
                }
            }
        } catch {
            if !silent {
                await MainActor.run {
                    self.errorString = error.localizedDescription
                    self.isLoadingHistory = false
                    
                    if let data = UserDefaults.standard.data(forKey: "cached_messages_session_\(session.id)"),
                       let cached = try? JSONDecoder().decode([ChatMessage].self, from: data) {
                        self.session.messages = cached
                        self.errorString = "Показываем сохраненные сообщения (офлайн-режим)"
                    }
                }
            }
        }
    }
    
    private func sendPhotoMessage(data: Data) {
        isSimulatingReply = true
        
        let tempUUID = UUID()
        let tempMsg = ChatMessage(
            id: tempUUID,
            senderName: authViewModel.currentUserProfile?.fullName ?? "Вы",
            senderAvatarURL: authViewModel.currentUserProfile?.avatarURL,
            text: "[photo] (загрузка...)",
            timestamp: Date(),
            isCurrentUser: true
        )
        session.messages.append(tempMsg)
        
        Task {
            do {
                guard let relativeURL = await authViewModel.uploadImage(data: data, fileName: "chat_photo_\(tempUUID).jpg") else {
                    throw APIError.noData
                }
                
                let photoText = "[photo] \(relativeURL)"
                let req = SendMessageDTO(text: photoText)
                let reqBody = try JSONEncoder().encode(req)
                
                let response: EventMessageResponse = try await APIClient.shared.request("/events/\(session.id)/messages", method: "POST", body: reqBody, requiresAuth: true)
                
                await MainActor.run {
                    isSimulatingReply = false
                    let currentUserID = authViewModel.currentUserProfile?.id ?? ""
                    let msgUUID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", response.id)) ?? UUID()
                    var newMsg = ChatMessage(
                        id: msgUUID,
                        senderName: response.senderName,
                        senderAvatarURL: response.senderAvatarURL.isEmpty ? nil : response.senderAvatarURL,
                        text: response.text,
                        timestamp: response.createdAt,
                        isCurrentUser: response.senderID == currentUserID
                    )
                    newMsg.dbID = response.id
                    newMsg.senderID = response.senderID
                    
                    if let index = session.messages.firstIndex(where: { $0.id == tempUUID }) {
                        session.messages[index] = newMsg
                    } else {
                        session.messages.append(newMsg)
                    }
                }
            } catch {
                await MainActor.run {
                    isSimulatingReply = false
                    session.messages.removeAll(where: { $0.id == tempUUID })
                    
                    let errorMsg = ChatMessage(
                        id: UUID(),
                        senderName: "Система",
                        senderAvatarURL: nil,
                        text: "⚠️ Ошибка отправки фото: \(error.localizedDescription)",
                        timestamp: Date(),
                        isCurrentUser: false
                    )
                    session.messages.append(errorMsg)
                }
            }
        }
    }
}

// MARK: - Rounded Corner Helper

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - AI Chat Request / Response Models

struct AIChatRequest: Codable {
    let message: String
    let history: [AIChatMessage]
}

struct AIChatMessage: Codable {
    let role: String // "user" or "model"
    let text: String
}

struct AIChatResponse: Codable {
    let reply: String
}

// MARK: - Event Chat Request / Response Models

struct SendMessageDTO: Codable {
    let text: String
}

struct EventMessageResponse: Codable {
    let id: Int32
    let eventID: Int32
    let senderID: String
    let senderName: String
    let senderUsername: String
    let senderAvatarURL: String
    let text: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case senderID = "sender_id"
        case senderName = "sender_name"
        case senderUsername = "sender_username"
        case senderAvatarURL = "sender_avatar_url"
        case text
        case createdAt = "created_at"
    }
}

#Preview {
    NavigationStack {
        ChatRoomView(session: .constant(ChatSession(
            id: 2,
            title: "Running",
            timeLabel: "Среда, 17 июня, 19:00",
            lastMessage: "Yernur Superperson: Гав гав гав",
            lastMessageSender: "Yernur Superperson",
            lastMessageTime: Date(),
            isCompleted: true,
            categoryIcon: "figure.run",
            categoryColorHex: "#48BB78",
            messages: []
        )))
    }
}
