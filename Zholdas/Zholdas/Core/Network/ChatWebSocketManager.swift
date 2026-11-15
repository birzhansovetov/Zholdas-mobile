import Foundation
import os

private let logger = Logger(subsystem: "app.zholdas.Zholdas", category: "ChatWebSocketManager")

class ChatWebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let eventID: Int32
    private var isClosed = false
    private var _session: URLSession?
    
    var onMessageReceived: ((EventMessageResponse) -> Void)?
    var onReconnected: (() -> Void)?
    
    private var reconnectDelay: TimeInterval = 3.0
    private var isFirstConnection = true
    private var isReconnecting = false
    private var reconnectAttempts = 0
    private var reconnectTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    
    private struct WSTicketResponse: Decodable, Sendable {
        let ticket: String
    }
    
    init(eventID: Int32) {
        self.eventID = eventID
        super.init()
    }
    
    deinit {
        connectTask?.cancel()
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        _session?.invalidateAndCancel()
        _session = nil
    }
    
    private func getOrCreateSession() -> URLSession {
        if let session = _session {
            return session
        }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        _session = session
        return session
    }
    
    func connect() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.connect()
            }
            return
        }
        
        guard !isClosed else { return }
        
        guard let token = TokenStorage.shared.getAccessToken() else {
            logger.debug("Access token missing, cannot connect.")
            isReconnecting = false
            return
        }
        
        connectTask?.cancel()
        connectTask = Task { @MainActor [weak self] in
            guard let self = self, !self.isClosed else { return }
            
            let queryItem: URLQueryItem
            do {
                let response: WSTicketResponse = try await APIClient.shared.request(
                    "/events/\(self.eventID)/ws-ticket",
                    method: "POST",
                    requiresAuth: true
                )
                guard !self.isClosed else { return }
                queryItem = URLQueryItem(name: "ticket", value: response.ticket)
            } catch {
                guard !Task.isCancelled, !self.isClosed else { return }
                if case .serverError(let statusCode, _) = error as? APIError, statusCode == 404 {
                    // fallback for old backend, remove later
                    let currentToken = TokenStorage.shared.getAccessToken() ?? token
                    queryItem = URLQueryItem(name: "token", value: currentToken)
                } else {
                    logger.error("Failed to obtain ws ticket: \(error.localizedDescription)")
                    self.handleDisconnect()
                    return
                }
            }
            
            guard !Task.isCancelled, !self.isClosed else { return }
            
            var components = URLComponents(
                url: AppConfig.webSocketBaseURL.appendingPathComponent("events/\(self.eventID)/ws"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [queryItem]
            guard let url = components?.url else { return }
            
            self.webSocketTask?.cancel()
            let session = self.getOrCreateSession()
            let task = session.webSocketTask(with: url)
            self.webSocketTask = task
            task.resume()
            
            self.startReceiveLoop()
            logger.debug("Connected to event \(self.eventID)")
        }
    }
    
    func disconnect() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.disconnect()
            }
            return
        }
        isClosed = true
        isReconnecting = false
        connectTask?.cancel()
        connectTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        _session?.invalidateAndCancel()
        _session = nil
        logger.debug("Disconnected from event \(self.eventID)")
    }
    
    private func startReceiveLoop() {
        guard let currentTask = self.webSocketTask else { return }
        currentTask.receive { [weak self, weak currentTask] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let webSocketTask = currentTask, webSocketTask === self.webSocketTask else { return }
                guard !self.isClosed else { return }
                
                switch result {
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        return
                    }
                    logger.error("Error receiving: \(error.localizedDescription)")
                    self.handleDisconnect()
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.parseMessage(text)
                    case .data(let data):
                        self.parseMessageData(data)
                    @unknown default:
                        break
                    }
                    self.startReceiveLoop()
                }
            }
        }
    }
    
    private func handleDisconnect() {
        guard !isClosed, !isReconnecting else { return }
        
        guard TokenStorage.shared.getAccessToken() != nil else {
            logger.debug("Access token missing, cannot reconnect.")
            isReconnecting = false
            return
        }
        
        isReconnecting = true
        reconnectAttempts += 1
        
        let delay = reconnectDelay
        // 3 -> 6 -> 12 -> 24 -> 48 -> 60 с
        reconnectDelay = min(reconnectDelay * 2, 60.0)
        logger.debug("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts))...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isClosed else { return }
            
            guard TokenStorage.shared.getAccessToken() != nil else {
                logger.debug("Access token missing, stopping reconnect.")
                self.isReconnecting = false
                return
            }
            
            if self.reconnectAttempts >= 5 {
                logger.debug("5 consecutive failed attempts, refreshing token via /auth/me before next attempt...")
                self.reconnectTask?.cancel()
                self.reconnectTask = Task {
                    let profile: UserProfile? = try? await APIClient.shared.request("/auth/me")
                    guard !Task.isCancelled else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.isClosed else { return }
                        self.reconnectTask = nil
                        if profile != nil, TokenStorage.shared.getAccessToken() != nil {
                            logger.debug("Token refreshed via /auth/me, reconnecting...")
                            self.reconnectAttempts = 0
                            self.isReconnecting = false
                            self.connect()
                        } else {
                            logger.error("Token refresh failed after 5 attempts, stopping reconnect.")
                            self.isReconnecting = false
                        }
                    }
                }
            } else {
                self.isReconnecting = false
                logger.debug("Reconnecting with fresh token...")
                self.connect()
            }
        }
    }
    
    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        parseMessageData(data)
    }
    
    private func parseMessageData(_ data: Data) {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateStr) {
                return date
            }
            
            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: dateStr) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
        }
        
        do {
            let messageRes = try decoder.decode(EventMessageResponse.self, from: data)
            self.onMessageReceived?(messageRes)
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }
}

extension ChatWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard webSocketTask === self.webSocketTask else { return }
            logger.debug("Socket opened")
            self.reconnectDelay = 3.0
            self.reconnectAttempts = 0
            self.isReconnecting = false
            
            if self.isFirstConnection {
                self.isFirstConnection = false
            } else {
                self.onReconnected?()
            }
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard webSocketTask === self.webSocketTask else { return }
            logger.debug("Socket closed with code: \(closeCode.rawValue)")
            self.handleDisconnect()
        }
    }
}
