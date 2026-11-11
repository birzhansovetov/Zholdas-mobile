import Foundation

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
    
    init(eventID: Int32) {
        self.eventID = eventID
        super.init()
    }
    
    deinit {
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
            print("ChatWebSocketManager: Access token missing, cannot connect.")
            isReconnecting = false
            return
        }
        
        var components = URLComponents(
            url: AppConfig.webSocketBaseURL.appendingPathComponent("events/\(eventID)/ws"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else { return }
        
        webSocketTask?.cancel()
        let session = getOrCreateSession()
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        
        startReceiveLoop()
        print("ChatWebSocketManager: Connected to event \(eventID)")
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
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        _session?.invalidateAndCancel()
        _session = nil
        print("ChatWebSocketManager: Disconnected from event \(eventID)")
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
                    print("ChatWebSocketManager Error receiving: \(error)")
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
            print("ChatWebSocketManager: Access token missing, cannot reconnect.")
            isReconnecting = false
            return
        }
        
        isReconnecting = true
        reconnectAttempts += 1
        
        let delay = reconnectDelay
        // 3 -> 6 -> 12 -> 24 -> 48 -> 60 с
        reconnectDelay = min(reconnectDelay * 2, 60.0)
        print("ChatWebSocketManager: Reconnecting in \(delay)s (attempt \(reconnectAttempts))...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isClosed else { return }
            
            guard TokenStorage.shared.getAccessToken() != nil else {
                print("ChatWebSocketManager: Access token missing, stopping reconnect.")
                self.isReconnecting = false
                return
            }
            
            if self.reconnectAttempts >= 5 {
                print("ChatWebSocketManager: 5 consecutive failed attempts, refreshing token via /auth/me before next attempt...")
                self.reconnectTask?.cancel()
                self.reconnectTask = Task {
                    let profile: UserProfile? = try? await APIClient.shared.request("/auth/me")
                    guard !Task.isCancelled else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.isClosed else { return }
                        self.reconnectTask = nil
                        if profile != nil, TokenStorage.shared.getAccessToken() != nil {
                            print("ChatWebSocketManager: Token refreshed via /auth/me, reconnecting...")
                            self.reconnectAttempts = 0
                            self.isReconnecting = false
                            self.connect()
                        } else {
                            print("ChatWebSocketManager: Token refresh failed after 5 attempts, stopping reconnect.")
                            self.isReconnecting = false
                        }
                    }
                }
            } else {
                self.isReconnecting = false
                print("ChatWebSocketManager: Reconnecting with fresh token...")
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
            print("ChatWebSocketManager: Failed to decode message: \(error)")
        }
    }
}

extension ChatWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard webSocketTask === self.webSocketTask else { return }
            print("ChatWebSocketManager: Socket opened")
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
            print("ChatWebSocketManager: Socket closed with code: \(closeCode)")
            self.handleDisconnect()
        }
    }
}
